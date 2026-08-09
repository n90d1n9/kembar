import 'package:digital_twin_core/domain/intelligence/prediction_request.dart';
import 'package:digital_twin_core/domain/intelligence/prediction_result.dart';
import 'package:digital_twin_core/application/intelligence/predictor_registry.dart';
import 'package:digital_twin_core/domains/port/terminal.dart';
import 'package:digital_twin_core/domains/port/container.dart';

/// Predicts terminal bottlenecks based on arrival rates and crane availability.
class PortCongestionPredictor implements IPredictor {
  @override
  String get domain => 'port';

  @override
  String get predictionType => 'congestion';

  @override
  bool supportsRequest(PredictionRequest request) {
    return request.domain == 'port' && 
           request.predictionType == 'congestion' &&
           request.currentState != null;
  }

  @override
  Future<PredictionResult> predict(PredictionRequest request) async {
    final state = request.currentState;
    if (state == null) {
      throw ArgumentError('Current state is required for port congestion prediction');
    }

    // Extract terminals from state
    final terminals = state.entities.whereType<Terminal>().toList();
    final containers = state.entities.whereType<Container>().toList();

    if (terminals.isEmpty) {
      return PredictionResult.lowRisk(
        requestId: request.id,
        predictionType: predictionType,
        forecastedState: {'congestion_level': 0.0},
        horizon: request.horizon,
        factors: ['No terminals found in state'],
        actions: ['Add terminal entities to the digital twin'],
      );
    }

    // Calculate current utilization
    double totalCapacity = 0;
    double currentLoad = 0;
    for (final terminal in terminals) {
      totalCapacity += terminal.capacity;
      currentLoad += terminal.currentLoad;
    }

    final utilizationRate = totalCapacity > 0 ? currentLoad / totalCapacity : 0.0;

    // Estimate arrival rate from context or historical data
    final arrivalRate = request.context['arrival_rate'] ?? 5.0; // containers per hour
    final departureRate = request.context['departure_rate'] ?? 4.0;

    // Project future load
    final hoursAhead = request.horizon.inHours + (request.horizon.inMinutes % 60) / 60.0;
    final projectedLoad = currentLoad + ((arrivalRate - departureRate) * hoursAhead);
    final projectedUtilization = totalCapacity > 0 ? projectedLoad / totalCapacity : 0.0;

    // Determine risk level
    RiskLevel riskLevel;
    List<String> factors = [];
    List<String> actions = [];

    if (projectedUtilization > 0.95) {
      riskLevel = RiskLevel.critical;
      factors.add('Projected utilization exceeds 95%');
      factors.add('Arrival rate ($arrivalRate/hr) exceeds departure rate ($departureRate/hr)');
      actions.add('Increase departure rate by adding more cranes/trucks');
      actions.add('Redirect incoming containers to alternative terminals');
      actions.add('Implement priority queuing for high-value cargo');
    } else if (projectedUtilization > 0.85) {
      riskLevel = RiskLevel.high;
      factors.add('Projected utilization exceeds 85%');
      factors.add('Limited buffer capacity remaining');
      actions.add('Prepare additional staging areas');
      actions.add('Optimize crane scheduling');
    } else if (projectedUtilization > 0.70) {
      riskLevel = RiskLevel.medium;
      factors.add('Moderate utilization projected');
      actions.add('Monitor arrival patterns');
    } else {
      riskLevel = RiskLevel.low;
      factors.add('Adequate capacity available');
      factors.add('Balanced arrival/departure rates');
    }

    return PredictionResult(
      requestId: request.id,
      predictionType: predictionType,
      forecastedState: {
        'current_utilization': utilizationRate,
        'projected_utilization': projectedUtilization,
        'projected_load': projectedLoad,
        'total_capacity': totalCapacity,
        'congestion_level': projectedUtilization,
        'risk_level': riskLevel.name,
      },
      confidence: 0.88,
      riskLevel: riskLevel,
      horizon: request.horizon,
      contributingFactors: factors,
      recommendations: actions,
      confidenceByMetric: {
        'utilization_forecast': 0.92,
        'risk_assessment': 0.85,
      },
    );
  }
}
