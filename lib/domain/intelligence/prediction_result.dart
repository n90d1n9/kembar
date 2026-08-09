import 'package:digital_twin_core/domain/twin/twin_state.dart';

/// Risk level assessment for predictions
enum RiskLevel { low, medium, high, critical }

/// Standardized output with forecasted states, confidence scores, and risk factors.
class PredictionResult {
  final String requestId;
  final String predictionType;
  final Map<String, dynamic> forecastedState;
  final double confidence;
  final RiskLevel riskLevel;
  final List<String> contributingFactors;
  final List<String> recommendations;
  final DateTime predictedAt;
  final Duration horizon;
  final Map<String, double>? confidenceByMetric;

  PredictionResult({
    required this.requestId,
    required this.predictionType,
    required this.forecastedState,
    required this.confidence,
    required this.riskLevel,
    List<String>? contributingFactors,
    List<String>? recommendations,
    DateTime? predictedAt,
    required this.horizon,
    this.confidenceByMetric,
  })  : contributingFactors = contributingFactors ?? [],
        recommendations = recommendations ?? [],
        predictedAt = predictedAt ?? DateTime.now();

  /// Create a result indicating high risk/congestion
  factory PredictionResult.highRisk({
    required String requestId,
    required String predictionType,
    required Map<String, dynamic> forecastedState,
    required Duration horizon,
    List<String>? factors,
    List<String>? actions,
  }) {
    return PredictionResult(
      requestId: requestId,
      predictionType: predictionType,
      forecastedState: forecastedState,
      confidence: 0.85,
      riskLevel: RiskLevel.high,
      horizon: horizon,
      contributingFactors: factors,
      recommendations: actions,
    );
  }

  /// Create a result indicating low risk/normal operations
  factory PredictionResult.lowRisk({
    required String requestId,
    required String predictionType,
    required Map<String, dynamic> forecastedState,
    required Duration horizon,
    List<String>? factors,
    List<String>? actions,
  }) {
    return PredictionResult(
      requestId: requestId,
      predictionType: predictionType,
      forecastedState: forecastedState,
      confidence: 0.92,
      riskLevel: RiskLevel.low,
      horizon: horizon,
      contributingFactors: factors,
      recommendations: actions,
    );
  }

  /// Check if prediction exceeds minimum confidence threshold
  bool meetsConfidenceThreshold(double threshold) {
    return confidence >= threshold;
  }

  /// Get human-readable summary
  String get summary {
    final riskStr = riskLevel.name.toUpperCase();
    return 'Prediction [$predictionType]: $riskStr risk (${(confidence * 100).toInt()}% confidence) over ${horizon.inMinutes}min';
  }

  @override
  String toString() => summary;
}
