import 'package:digital_twin_core/domain/intelligence/i_predictor.dart';
import 'package:digital_twin_core/domain/entity.dart';

/// Manager for coordinating multiple predictors
class PredictionManager {
  final Map<String, IPredictor> _predictors = {};
  
  void registerPredictor(IPredictor predictor) {
    _predictors[predictor.id] = predictor;
  }
  
  void unregisterPredictor(String predictorId) {
    _predictors.remove(predictorId);
  }
  
  IPredictor? getPredictor(String predictorId) {
    return _predictors[predictorId];
  }
  
  List<IPredictor> getAllPredictors() {
    return _predictors.values.toList();
  }
  
  Future<PredictionResult<T>> predict<T>(
    String predictorId,
    Map<String, dynamic> inputData
  ) async {
    final predictor = _predictors[predictorId];
    if (predictor == null) {
      throw Exception('Predictor $predictorId not found');
    }
    
    return await predictor.predict(inputData) as PredictionResult<T>;
  }
  
  Future<Map<String, PredictionResult>> predictAll(
    Map<String, dynamic> inputData
  ) async {
    final results = <String, PredictionResult>{};
    
    for (final predictor in _predictors.values) {
      try {
        final result = await predictor.predict(inputData);
        results[predictor.id] = result;
      } catch (e) {
        // Log error but continue with other predictors
        print('Error in predictor ${predictor.id}: $e');
      }
    }
    
    return results;
  }
  
  Future<void> trainAll(List<Map<String, dynamic>> trainingData) async {
    await Future.wait(
      _predictors.values.map((p) => p.train(trainingData))
    );
  }
}
