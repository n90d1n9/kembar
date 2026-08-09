import 'package:digital_twin_core/domain/intelligence/prediction_request.dart';
import 'package:digital_twin_core/domain/intelligence/prediction_result.dart';
import 'package:digital_twin_core/application/intelligence/predictor_registry.dart';
import 'package:digital_twin_core/domains/restaurant/table.dart';
import 'package:digital_twin_core/domains/restaurant/customer.dart';

/// Estimates table turnover and customer wait times.
class RestaurantWaitTimePredictor implements IPredictor {
  @override
  String get domain => 'restaurant';

  @override
  String get predictionType => 'wait_time';

  @override
  bool supportsRequest(PredictionRequest request) {
    return request.domain == 'restaurant' && 
           request.predictionType == 'wait_time' &&
           request.currentState != null;
  }

  @override
  Future<PredictionResult> predict(PredictionRequest request) async {
    final state = request.currentState;
    if (state == null) {
      throw ArgumentError('Current state is required for restaurant wait time prediction');
    }

    // Extract tables and customers from state
    final tables = state.entities.whereType<RestaurantTable>().toList();
    final customers = state.entities.whereType<Customer>().toList();

    if (tables.isEmpty) {
      return PredictionResult.lowRisk(
        requestId: request.id,
        predictionType: predictionType,
        forecastedState: {'avg_wait_time_minutes': 0},
        horizon: request.horizon,
        factors: ['No tables found in state'],
        actions: ['Add table entities to the digital twin'],
      );
    }

    // Calculate current statistics
    final totalTables = tables.length;
    final occupiedTables = tables.where((t) => t.isOccupied).length;
    final availableTables = totalTables - occupiedTables;
    final occupancyRate = occupiedTables / totalTables;

    // Count waiting customers
    final waitingCustomers = customers.where((c) => c.status == CustomerStatus.waiting).toList();
    final seatedCustomers = customers.where((c) => c.status == CustomerStatus.seated || c.status == CustomerStatus.eating).toList();

    // Estimate average dining duration (could be learned from historical data)
    final avgDiningDuration = request.context['avg_dining_duration_minutes'] ?? 45; // minutes
    final avgTurnoverTime = request.context['avg_turnover_time_minutes'] ?? 15; // cleaning + seating

    // Calculate estimated wait times for waiting parties
    final estimatedWaitTimes = <int>[];
    
    for (final customer in waitingCustomers) {
      final partySize = customer.partySize;
      
      // Find suitable tables for this party
      final suitableTables = tables.where((t) => !t.isOccupied && t.capacity >= partySize).toList();
      
      if (suitableTables.isNotEmpty) {
        estimatedWaitTimes.add(0); // Immediate seating possible
      } else {
        // Need to wait for a table to free up
        // Estimate based on number of parties ahead and average turnover
        final partiesAhead = waitingCustomers.indexOf(customer);
        final estimatedWait = (partiesAhead + 1) * (avgDiningDuration + avgTurnoverTime) ~/ tables.length;
        estimatedWaitTimes.add(estimatedWait);
      }
    }

    final avgWaitTime = estimatedWaitTimes.isEmpty ? 0 : estimatedWaitTimes.reduce((a, b) => a + b) / estimatedWaitTimes.length;
    final maxWaitTime = estimatedWaitTimes.isEmpty ? 0 : estimatedWaitTimes.reduce((a, b) => a > b ? a : b);

    // Project future state based on horizon
    final hoursAhead = request.horizon.inMinutes / 60.0;
    final projectedTurnovers = (hoursAhead * 60 / (avgDiningDuration + avgTurnoverTime)).round();
    final projectedCapacity = projectedTurnovers * totalTables;
    final projectedDemand = waitingCustomers.length + (seatedCustomers.length ~/ projectedTurnovers);

    // Determine risk level
    RiskLevel riskLevel;
    List<String> factors = [];
    List<String> actions = [];

    if (avgWaitTime > 60 || (occupancyRate > 0.95 && waitingCustomers.length > 5)) {
      riskLevel = RiskLevel.critical;
      factors.add('Critical wait times detected (${avgWaitTime.toInt()} min average)');
      factors.add('High occupancy rate (${(occupancyRate * 100).toInt()}%)');
      factors.add('${waitingCustomers.length} parties waiting');
      actions.add('Offer bar seating or takeaway options');
      actions.add('Implement express menu for waiting parties');
      actions.add('Call in additional staff to speed up turnover');
      actions.add('Consider reservation-only policy temporarily');
    } else if (avgWaitTime > 30 || occupancyRate > 0.85) {
      riskLevel = RiskLevel.high;
      factors.add('Elevated wait times (${avgWaitTime.toInt()} min average)');
      factors.add('High table occupancy');
      actions.add('Optimize table cleaning process');
      actions.add('Offer complimentary drinks to waiting guests');
      actions.add('Prepare tables in advance');
    } else if (avgWaitTime > 15 || occupancyRate > 0.70) {
      riskLevel = RiskLevel.medium;
      factors.add('Moderate wait times expected');
      actions.add('Monitor incoming reservations');
    } else {
      riskLevel = RiskLevel.low;
      factors.add('Normal wait times expected');
      factors.add('Adequate table availability');
    }

    return PredictionResult(
      requestId: request.id,
      predictionType: predictionType,
      forecastedState: {
        'current_occupancy_rate': occupancyRate,
        'occupied_tables': occupiedTables,
        'available_tables': availableTables,
        'waiting_parties': waitingCustomers.length,
        'avg_wait_time_minutes': avgWaitTime.round(),
        'max_wait_time_minutes': maxWaitTime,
        'projected_capacity': projectedCapacity,
        'avg_dining_duration': avgDiningDuration,
        'risk_level': riskLevel.name,
      },
      confidence: 0.79,
      riskLevel: riskLevel,
      horizon: request.horizon,
      contributingFactors: factors,
      recommendations: actions,
      confidenceByMetric: {
        'wait_time_estimate': 0.75,
        'occupancy_forecast': 0.82,
      },
    );
  }
}
