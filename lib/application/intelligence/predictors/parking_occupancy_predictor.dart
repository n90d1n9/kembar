import 'package:digital_twin_core/domain/intelligence/prediction_request.dart';
import 'package:digital_twin_core/domain/intelligence/prediction_result.dart';
import 'package:digital_twin_core/application/intelligence/predictor_registry.dart';
import 'package:digital_twin_core/domains/parking/space.dart';
import 'package:digital_twin_core/domains/parking/vehicle.dart';

/// Forecasts lot fullness using historical patterns and event schedules.
class ParkingOccupancyPredictor implements IPredictor {
  @override
  String get domain => 'parking';

  @override
  String get predictionType => 'occupancy';

  @override
  bool supportsRequest(PredictionRequest request) {
    return request.domain == 'parking' && 
           request.predictionType == 'occupancy' &&
           request.currentState != null;
  }

  @override
  Future<PredictionResult> predict(PredictionRequest request) async {
    final state = request.currentState;
    if (state == null) {
      throw ArgumentError('Current state is required for parking occupancy prediction');
    }

    // Extract parking spaces from state
    final spaces = state.entities.whereType<ParkingSpace>().toList();

    if (spaces.isEmpty) {
      return PredictionResult.lowRisk(
        requestId: request.id,
        predictionType: predictionType,
        forecastedState: {'occupancy_rate': 0.0},
        horizon: request.horizon,
        factors: ['No parking spaces found in state'],
        actions: ['Add parking space entities to the digital twin'],
      );
    }

    // Calculate current occupancy
    final totalSpaces = spaces.length;
    final occupiedSpaces = spaces.where((s) => s.isOccupied).length;
    final currentOccupancyRate = occupiedSpaces / totalSpaces;

    // Get time-based factors
    final hourOfDay = DateTime.now().hour;
    final dayOfWeek = DateTime.now().weekday;
    
    // Apply typical patterns (could be replaced with ML model)
    double patternMultiplier = 1.0;
    
    // Rush hours: 8-9 AM and 5-6 PM
    if ((hourOfDay >= 8 && hourOfDay <= 9) || (hourOfDay >= 17 && hourOfDay <= 18)) {
      patternMultiplier = 1.3;
    }
    // Lunch rush: 12-1 PM
    else if (hourOfDay >= 12 && hourOfDay <= 13) {
      patternMultiplier = 1.15;
    }
    // Night: low occupancy
    else if (hourOfDay >= 22 || hourOfDay <= 5) {
      patternMultiplier = 0.4;
    }

    // Weekend adjustment
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      patternMultiplier *= 0.7; // Generally lower on weekends unless special events
    }

    // Check for special events in context
    final hasEvent = request.context['has_event'] ?? false;
    final eventSize = request.context['event_size'] ?? 'medium'; // small, medium, large
    
    if (hasEvent) {
      switch (eventSize) {
        case 'large':
          patternMultiplier *= 2.0;
          break;
        case 'medium':
          patternMultiplier *= 1.5;
          break;
        case 'small':
          patternMultiplier *= 1.2;
          break;
      }
    }

    // Project future occupancy
    final projectedOccupancyRate = (currentOccupancyRate * patternMultiplier).clamp(0.0, 1.0);
    final projectedOccupiedSpaces = (projectedOccupancyRate * totalSpaces).round();

    // Determine risk level
    RiskLevel riskLevel;
    List<String> factors = [];
    List<String> actions = [];

    if (projectedOccupancyRate > 0.95) {
      riskLevel = RiskLevel.critical;
      factors.add('Lot projected to be nearly full (>95%)');
      factors.add('Pattern multiplier: ${patternMultiplier.toStringAsFixed(2)}x');
      actions.add('Activate overflow parking areas');
      actions.add('Display "FULL" signs at entrances');
      actions.add('Redirect traffic to nearby facilities');
    } else if (projectedOccupancyRate > 0.85) {
      riskLevel = RiskLevel.high;
      factors.add('High occupancy projected (>85%)');
      actions.add('Prepare overflow signage');
      actions.add('Deploy staff to direct traffic');
    } else if (projectedOccupancyRate > 0.70) {
      riskLevel = RiskLevel.medium;
      factors.add('Moderate to high occupancy projected');
      actions.add('Monitor entry rates');
    } else {
      riskLevel = RiskLevel.low;
      factors.add('Adequate capacity available');
      factors.add('Normal traffic patterns expected');
    }

    return PredictionResult(
      requestId: request.id,
      predictionType: predictionType,
      forecastedState: {
        'current_occupancy_rate': currentOccupancyRate,
        'projected_occupancy_rate': projectedOccupancyRate,
        'current_occupied_spaces': occupiedSpaces,
        'projected_occupied_spaces': projectedOccupiedSpaces,
        'total_spaces': totalSpaces,
        'available_spaces': totalSpaces - projectedOccupiedSpaces,
        'pattern_multiplier': patternMultiplier,
        'risk_level': riskLevel.name,
      },
      confidence: 0.82,
      riskLevel: riskLevel,
      horizon: request.horizon,
      contributingFactors: factors,
      recommendations: actions,
      confidenceByMetric: {
        'occupancy_forecast': 0.85,
        'pattern_analysis': 0.78,
      },
    );
  }
}
