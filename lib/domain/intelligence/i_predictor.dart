import 'package:digital_twin_core/domain/entity.dart';

/// Abstract interface for prediction models
abstract class IPredictor<T> {
  /// Unique identifier for this predictor
  String get id;
  
  /// Human-readable name
  String get name;
  
  /// The type of data this predictor works with
  Type get targetType;
  
  /// Initialize the predictor with training data
  Future<void> train(List<Map<String, dynamic>> trainingData);
  
  /// Make a prediction based on current state
  Future<PredictionResult<T>> predict(Map<String, dynamic> inputData);
  
  /// Make predictions for multiple entities
  Future<List<PredictionResult<T>>> predictBatch(List<Map<String, dynamic>> inputDataList);
  
  /// Get confidence score for the last prediction
  double get lastConfidenceScore;
  
  /// Update model with new data (online learning)
  Future<void> update(Map<String, dynamic> newData, T actualOutcome);
}

/// Result of a prediction operation
class PredictionResult<T> {
  final T predictedValue;
  final double confidence;
  final DateTime predictionTime;
  final DateTime? predictedForTime;
  final Map<String, dynamic> metadata;
  final List<String> contributingFactors;

  PredictionResult({
    required this.predictedValue,
    required this.confidence,
    this.predictedForTime,
    Map<String, dynamic>? metadata,
    List<String>? contributingFactors,
  })  : predictionTime = DateTime.now(),
        metadata = metadata ?? {},
        contributingFactors = contributingFactors ?? [];

  @override
  String toString() {
    return 'PredictionResult(value: $predictedValue, confidence: $confidence, for: $predictedForTime)';
  }
}

/// Time-series prediction result
class TimeSeriesPrediction<T> {
  final List<PredictionResult<T>> predictions;
  final Duration timeStep;
  final int horizon;

  TimeSeriesPrediction({
    required this.predictions,
    required this.timeStep,
    required this.horizon,
  });

  List<T> get values => predictions.map((p) => p.predictedValue).toList();
  List<double> get confidences => predictions.map((p) => p.confidence).toList();
  List<DateTime> get timestamps => predictions.map((p) => p.predictionTime).toList();
}
