import 'package:digital_twin_core/domain/intelligence/prediction_request.dart';
import 'package:digital_twin_core/domain/intelligence/prediction_result.dart';
import 'package:digital_twin_core/application/intelligence/predictor_registry.dart';
import 'package:digital_twin_core/domains/warehouse/storage.dart';
import 'package:digital_twin_core/domains/warehouse/item.dart';

/// Identifies future picking/packing congestion points.
class WarehouseBottleneckPredictor implements IPredictor {
  @override
  String get domain => 'warehouse';

  @override
  String get predictionType => 'bottleneck';

  @override
  bool supportsRequest(PredictionRequest request) {
    return request.domain == 'warehouse' && 
           request.predictionType == 'bottleneck' &&
           request.currentState != null;
  }

  @override
  Future<PredictionResult> predict(PredictionRequest request) async {
    final state = request.currentState;
    if (state == null) {
      throw ArgumentError('Current state is required for warehouse bottleneck prediction');
    }

    // Extract storage units and items from state
    final storageUnits = state.entities.whereType<StorageUnit>().toList();
    final items = state.entities.whereType<WarehouseItem>().toList();

    if (storageUnits.isEmpty) {
      return PredictionResult.lowRisk(
        requestId: request.id,
        predictionType: predictionType,
        forecastedState: {'bottleneck_severity': 0.0},
        horizon: request.horizon,
        factors: ['No storage units found in state'],
        actions: ['Add storage unit entities to the digital twin'],
      );
    }

    // Calculate utilization per storage unit
    final utilizationByUnit = <String, double>{};
    for (final unit in storageUnits) {
      final utilization = unit.capacity > 0 ? unit.currentLoad / unit.capacity : 0.0;
      utilizationByUnit[unit.id] = utilization;
    }

    // Identify high-utilization zones
    final highUtilUnits = storageUnits.where((u) => utilizationByUnit[u.id]! > 0.85).toList();
    final avgUtilization = utilizationByUnit.values.isEmpty 
        ? 0.0 
        : utilizationByUnit.values.reduce((a, b) => a + b) / utilizationByUnit.length;

    // Get order rate from context
    final orderRate = request.context['order_rate'] ?? 10.0; // orders per hour
    final pickRate = request.context['pick_rate'] ?? 12.0; // picks per hour per worker
    final workerCount = request.context['worker_count'] ?? 3;

    // Calculate throughput capacity
    final totalPickRate = pickRate * workerCount;
    final netBacklogRate = orderRate - totalPickRate;

    // Project future state
    final hoursAhead = request.horizon.inHours + (request.horizon.inMinutes % 60) / 60.0;
    final projectedBacklog = (netBacklogRate * hoursAhead).clamp(0, double.infinity);
    
    // Estimate congestion severity (0-1 scale)
    double congestionSeverity = 0.0;
    if (highUtilUnits.isNotEmpty) {
      congestionSeverity = highUtilUnits.length / storageUnits.length;
    }
    congestionSeverity = (congestionSeverity + (projectedBacklog / (totalPickRate * hoursAhead + 1))).clamp(0.0, 1.0);

    // Identify specific bottlenecks
    List<String> bottleneckZones = [];
    for (final unit in highUtilUnits) {
      bottleneckZones.add('${unit.name} (${(utilizationByUnit[unit.id]! * 100).toInt()}% full)');
    }

    // Determine risk level
    RiskLevel riskLevel;
    List<String> factors = [];
    List<String> actions = [];

    if (congestionSeverity > 0.85 || projectedBacklog > totalPickRate * 2) {
      riskLevel = RiskLevel.critical;
      factors.add('Critical bottleneck detected');
      factors.add('${highUtilUnits.length} storage units at >85% capacity');
      factors.add('Projected backlog: ${projectedBacklog.round()} orders');
      factors.add('Order rate ($orderRate/hr) exceeds pick capacity ($totalPickRate/hr)');
      actions.add('Immediately allocate additional workers to picking');
      actions.add('Implement batch picking strategy');
      actions.add('Prioritize high-value orders');
      actions.add('Consider temporary storage expansion');
    } else if (congestionSeverity > 0.70 || projectedBacklog > totalPickRate) {
      riskLevel = RiskLevel.high;
      factors.add('High congestion risk identified');
      factors.add('Multiple storage zones approaching capacity');
      actions.add('Rebalance inventory across zones');
      actions.add('Optimize pick paths');
      actions.add('Schedule additional staff for peak hours');
    } else if (congestionSeverity > 0.50 || projectedBacklog > 0) {
      riskLevel = RiskLevel.medium;
      factors.add('Moderate congestion developing');
      factors.add('Some zones showing high utilization');
      actions.add('Monitor order queue closely');
      actions.add('Prepare contingency staffing plan');
    } else {
      riskLevel = RiskLevel.low;
      factors.add('Normal operations expected');
      factors.add('Adequate capacity across all zones');
      factors.add('Pick rate exceeds order rate');
    }

    return PredictionResult(
      requestId: request.id,
      predictionType: predictionType,
      forecastedState: {
        'avg_utilization': avgUtilization,
        'high_util_zones': highUtilUnits.length,
        'total_zones': storageUnits.length,
        'congestion_severity': congestionSeverity,
        'projected_backlog': projectedBacklog.round(),
        'order_rate': orderRate,
        'pick_capacity': totalPickRate,
        'bottleneck_zones': bottleneckZones,
        'risk_level': riskLevel.name,
      },
      confidence: 0.84,
      riskLevel: riskLevel,
      horizon: request.horizon,
      contributingFactors: factors,
      recommendations: actions,
      confidenceByMetric: {
        'utilization_forecast': 0.88,
        'backlog_estimate': 0.80,
      },
    );
  }
}
