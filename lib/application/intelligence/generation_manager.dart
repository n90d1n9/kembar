import 'package:digital_twin_core/domain/intelligence/i_generator.dart';

/// Manager for coordinating multiple generators
class GenerationManager {
  final Map<String, IGenerator> _generators = {};
  
  void registerGenerator(IGenerator generator) {
    _generators[generator.id] = generator;
  }
  
  void unregisterGenerator(String generatorId) {
    _generators.remove(generatorId);
  }
  
  IGenerator? getGenerator(String generatorId) {
    return _generators[generatorId];
  }
  
  List<IGenerator> getAllGenerators() {
    return _generators.values.toList();
  }
  
  Future<GenerationResult<T>> generate<T>(
    String generatorId,
    GenerationConstraints constraints
  ) async {
    final generator = _generators[generatorId];
    if (generator == null) {
      throw Exception('Generator $generatorId not found');
    }
    
    return await generator.generate(constraints) as GenerationResult<T>;
  }
  
  Future<List<GenerationResult<T>>> generateVariants<T>(
    String generatorId,
    GenerationConstraints constraints, {
    int count = 5,
  }) async {
    final generator = _generators[generatorId];
    if (generator == null) {
      throw Exception('Generator $generatorId not found');
    }
    
    return await generator.generateVariants(constraints, count: count) 
        as List<GenerationResult<T>>;
  }
  
  Future<GenerationResult<T>> optimize<T>(
    String generatorId,
    T initial,
    OptimizationGoals goals, {
    int maxIterations = 100,
  }) async {
    final generator = _generators[generatorId];
    if (generator == null) {
      throw Exception('Generator $generatorId not found');
    }
    
    return await generator.optimize(initial, goals, maxIterations: maxIterations)
        as GenerationResult<T>;
  }
}
