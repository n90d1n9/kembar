import 'package:digital_twin_core/domain/intelligence/i_predictor.dart';
import 'package:digital_twin_core/domain/entity.dart';

/// Simple statistical predictor using moving averages and linear regression
class StatisticalPredictor implements IPredictor<num> {
  @override
  final String id;
  @override
  final String name = 'Statistical Predictor';
  @override
  final Type targetType = num;

  List<num> _historicalData = [];
  List<Map<String, dynamic>> _trainingData = [];
  double _lastConfidence = 0.0;
  
  // Model parameters for linear regression
  double? _slope;
  double? _intercept;

  StatisticalPredictor({String? id}) : id = id ?? 'stat_predictor_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<void> train(List<Map<String, dynamic>> trainingData) async {
    _trainingData = trainingData;
    _historicalData = trainingData
        .where((d) => d.containsKey('value'))
        .map((d) => d['value'] as num)
        .toList();
    
    // Perform simple linear regression if we have enough data
    if (_historicalData.length >= 2) {
      _performLinearRegression();
    }
  }

  void _performLinearRegression() {
    if (_historicalData.length < 2) return;

    final n = _historicalData.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += _historicalData[i];
      sumXY += i * _historicalData[i];
      sumX2 += i * i;
    }

    _slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    _intercept = (sumY - _slope! * sumX) / n;
  }

  @override
  Future<PredictionResult<num>> predict(Map<String, dynamic> inputData) async {
    if (_slope == null || _intercept == null) {
      // Fall back to moving average
      final prediction = _calculateMovingAverage(inputData);
      _lastConfidence = 0.5; // Lower confidence for simple average
      
      return PredictionResult(
        predictedValue: prediction,
        confidence: _lastConfidence,
        metadata: {'method': 'moving_average'},
      );
    }

    // Use linear regression
    final steps = inputData['steps'] ?? 1;
    final lastValue = inputData['current_value'] ?? _historicalData.last;
    final currentIndex = _historicalData.length;
    
    final predictedValue = _slope! * (currentIndex + steps) + _intercept!;
    
    // Calculate confidence based on R-squared (simplified)
    _lastConfidence = _calculateConfidence();
    
    return PredictionResult(
      predictedValue: predictedValue,
      confidence: _lastConfidence,
      predictedForTime: DateTime.now().add(Duration(seconds: steps)),
      metadata: {
        'method': 'linear_regression',
        'slope': _slope,
        'intercept': _intercept,
        'steps_ahead': steps,
      },
      contributingFactors: ['historical_trend', 'linear_pattern'],
    );
  }

  num _calculateMovingAverage(Map<String, dynamic> inputData) {
    final windowSize = inputData['window_size'] ?? 5;
    final effectiveSize = windowSize > _historicalData.length 
        ? _historicalData.length 
        : windowSize;
    
    if (effectiveSize == 0) return 0;
    
    final recentData = _historicalData.sublist(
      _historicalData.length - effectiveSize
    );
    
    return recentData.reduce((a, b) => a + b) / effectiveSize;
  }

  double _calculateConfidence() {
    if (_historicalData.length < 3) return 0.3;
    if (_historicalData.length < 10) return 0.6;
    if (_historicalData.length < 50) return 0.8;
    return 0.9;
  }

  @override
  Future<List<PredictionResult<num>>> predictBatch(
    List<Map<String, dynamic>> inputDataList
  ) async {
    return Future.wait(
      inputDataList.map((input) => predict(input))
    );
  }

  @override
  double get lastConfidenceScore => _lastConfidence;

  @override
  Future<void> update(Map<String, dynamic> newData, num actualOutcome) async {
    _historicalData.add(actualOutcome);
    _trainingData.add({...newData, 'value': actualOutcome});
    
    // Retrain model with new data
    _performLinearRegression();
    _lastConfidence = _calculateConfidence();
  }
}
