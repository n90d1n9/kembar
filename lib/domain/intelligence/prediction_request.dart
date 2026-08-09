import 'package:digital_twin_core/domain/twin/twin_state.dart';

/// Defines the intent, horizon, and confidence requirements for predictions.
class PredictionRequest {
  final String id;
  final String domain;
  final String predictionType;
  final Duration horizon;
  final double? minConfidence;
  final Map<String, dynamic> context;
  final TwinState? currentState;
  final DateTime requestedAt;

  PredictionRequest({
    String? id,
    required this.domain,
    required this.predictionType,
    required this.horizon,
    this.minConfidence,
    Map<String, dynamic>? context,
    this.currentState,
    DateTime? requestedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        context = context ?? {},
        requestedAt = requestedAt ?? DateTime.now();

  /// Create a prediction request for congestion/bottleneck analysis
  factory PredictionRequest.forCongestion({
    required String domain,
    required Duration horizon,
    required TwinState state,
  }) {
    return PredictionRequest(
      domain: domain,
      predictionType: 'congestion',
      horizon: horizon,
      currentState: state,
      context: {'analysis_type': 'bottleneck'},
    );
  }

  /// Create a prediction request for occupancy/utilization forecasting
  factory PredictionRequest.forOccupancy({
    required String domain,
    required Duration horizon,
    required TwinState state,
    Map<String, dynamic>? additionalContext,
  }) {
    return PredictionRequest(
      domain: domain,
      predictionType: 'occupancy',
      horizon: horizon,
      currentState: state,
      context: {
        'analysis_type': 'utilization',
        if (additionalContext != null) ...additionalContext,
      },
    );
  }

  /// Create a prediction request for wait time estimation
  factory PredictionRequest.forWaitTime({
    required String domain,
    required Duration horizon,
    required TwinState state,
  }) {
    return PredictionRequest(
      domain: domain,
      predictionType: 'wait_time',
      horizon: horizon,
      currentState: state,
      context: {'analysis_type': 'queue'},
    );
  }

  @override
  String toString() => 'PredictionRequest(id: $id, domain: $domain, type: $predictionType, horizon: $horizon)';
}
