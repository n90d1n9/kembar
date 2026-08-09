/// Abstract base for defining optimization goals.
enum OptimizationObjectiveType {
  maximizeThroughput,
  minimizeCost,
  minimizeWaitTime,
  maximizeUtilization,
  minimizeDistance,
  maximizeEfficiency,
}

/// Represents a single optimization objective with optional weight.
class ObjectiveFunction {
  final OptimizationObjectiveType type;
  final String? customMetric;
  final double weight;
  final double? targetValue;
  final bool isMinimization;

  const ObjectiveFunction({
    required this.type,
    this.customMetric,
    this.weight = 1.0,
    this.targetValue,
  }) : isMinimization = _isMinimizationType(type);

  static bool _isMinimizationType(OptimizationObjectiveType type) {
    switch (type) {
      case OptimizationObjectiveType.minimizeCost:
      case OptimizationObjectiveType.minimizeWaitTime:
      case OptimizationObjectiveType.minimizeDistance:
        return true;
      case OptimizationObjectiveType.maximizeThroughput:
      case OptimizationObjectiveType.maximizeUtilization:
      case OptimizationObjectiveType.maximizeEfficiency:
        return false;
    }
  }

  /// Create objective to maximize throughput
  factory ObjectiveFunction.maximizeThroughput({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.maximizeThroughput,
      weight: weight,
    );
  }

  /// Create objective to minimize cost
  factory ObjectiveFunction.minimizeCost({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.minimizeCost,
      weight: weight,
    );
  }

  /// Create objective to minimize wait time
  factory ObjectiveFunction.minimizeWaitTime({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.minimizeWaitTime,
      weight: weight,
    );
  }

  /// Create objective to maximize utilization
  factory ObjectiveFunction.maximizeUtilization({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.maximizeUtilization,
      weight: weight,
    );
  }

  /// Create objective to minimize travel distance
  factory ObjectiveFunction.minimizeDistance({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.minimizeDistance,
      weight: weight,
    );
  }

  /// Create objective to maximize overall efficiency
  factory ObjectiveFunction.maximizeEfficiency({double weight = 1.0}) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.maximizeEfficiency,
      weight: weight,
    );
  }

  /// Create custom objective
  factory ObjectiveFunction.custom({
    required String metric,
    required bool isMinimization,
    double weight = 1.0,
    double? targetValue,
  }) {
    return ObjectiveFunction(
      type: OptimizationObjectiveType.maximizeEfficiency, // placeholder
      customMetric: metric,
      weight: weight,
      targetValue: targetValue,
    );
  }

  @override
  String toString() => 'ObjectiveFunction($type, weight: $weight)';
}
