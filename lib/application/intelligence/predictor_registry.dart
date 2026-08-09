import 'package:digital_twin_core/domain/intelligence/prediction_request.dart';
import 'package:digital_twin_core/domain/intelligence/prediction_result.dart';

/// Abstract interface for domain-specific predictors
abstract class IPredictor {
  String get domain;
  String get predictionType;
  
  Future<PredictionResult> predict(PredictionRequest request);
  bool supportsRequest(PredictionRequest request);
}

/// Central registry to discover and route requests to domain-specific predictors.
class PredictorRegistry {
  final Map<String, List<IPredictor>> _predictors = {};

  /// Register a predictor for a specific domain and type
  void register(IPredictor predictor) {
    final key = '${predictor.domain}:${predictor.predictionType}';
    _predictors.putIfAbsent(key, () => []);
    _predictors[key]!.add(predictor);
  }

  /// Unregister a predictor
  void unregister(IPredictor predictor) {
    final key = '${predictor.domain}:${predictor.predictionType}';
    _predictors[key]?.removeWhere((p) => p == predictor);
  }

  /// Find all predictors that can handle the request
  List<IPredictor> findPredictors(PredictionRequest request) {
    final key = '${request.domain}:${request.predictionType}';
    return _predictors[key] ?? [];
  }

  /// Execute prediction using the best available predictor
  Future<PredictionResult?> predict(PredictionRequest request) async {
    final predictors = findPredictors(request);
    if (predictors.isEmpty) {
      return null;
    }

    // Use the first predictor (could be enhanced with selection logic)
    final predictor = predictors.first;
    if (!predictor.supportsRequest(request)) {
      return null;
    }

    return await predictor.predict(request);
  }

  /// Execute predictions using all available predictors and aggregate results
  Future<List<PredictionResult>> predictAll(PredictionRequest request) async {
    final predictors = findPredictors(request);
    final results = <PredictionResult>[];

    for (final predictor in predictors) {
      if (predictor.supportsRequest(request)) {
        final result = await predictor.predict(request);
        results.add(result);
      }
    }

    return results;
  }

  /// Get all registered prediction types for a domain
  List<String> getSupportedTypes(String domain) {
    final types = <String>{};
    for (final key in _predictors.keys) {
      if (key.startsWith('$domain:')) {
        final type = key.split(':').last;
        types.add(type);
      }
    }
    return types.toList();
  }

  /// Get all registered domains
  List<String> getRegisteredDomains() {
    final domains = <String>{};
    for (final key in _predictors.keys) {
      final domain = key.split(':').first;
      domains.add(domain);
    }
    return domains.toList();
  }
}
