import 'package:digital_twin_core/domain/entity.dart';

/// Abstract interface for intelligent generators
abstract class IGenerator<T> {
  /// Unique identifier for this generator
  String get id;
  
  /// Human-readable name
  String get name;
  
  /// Generate a new entity/configuration based on constraints
  Future<GenerationResult<T>> generate(GenerationConstraints constraints);
  
  /// Generate multiple variants
  Future<List<GenerationResult<T>>> generateVariants(
    GenerationConstraints constraints, {
    int count = 5,
  });
  
  /// Optimize an existing configuration
  Future<GenerationResult<T>> optimize(
    T initial,
    OptimizationGoals goals, {
    int maxIterations = 100,
  });
}

/// Constraints for generation
class GenerationConstraints {
  final Map<String, dynamic> parameters;
  final List<ConstraintRule> rules;
  final Map<String, double> bounds;
  final Set<String> requiredFeatures;
  final Set<String> excludedFeatures;

  GenerationConstraints({
    Map<String, dynamic>? parameters,
    List<ConstraintRule>? rules,
    Map<String, double>? bounds,
    Set<String>? requiredFeatures,
    Set<String>? excludedFeatures,
  })  : parameters = parameters ?? {},
        rules = rules ?? [],
        bounds = bounds ?? {},
        requiredFeatures = requiredFeatures ?? {},
        excludedFeatures = excludedFeatures ?? {};

  bool validate(Map<String, dynamic> candidate) {
    // Check all constraint rules
    for (final rule in rules) {
      if (!rule.evaluate(candidate)) {
        return false;
      }
    }
    
    // Check bounds
    for (final entry in bounds.entries) {
      if (candidate.containsKey(entry.key)) {
        final value = candidate[entry.key] as num;
        if (value < 0 || value > entry.value) {
          return false;
        }
      }
    }
    
    // Check required features
    for (final feature in requiredFeatures) {
      if (!candidate.containsKey(feature) || candidate[feature] == null) {
        return false;
      }
    }
    
    // Check excluded features
    for (final feature in excludedFeatures) {
      if (candidate.containsKey(feature)) {
        return false;
      }
    }
    
    return true;
  }
}

/// A constraint rule
class ConstraintRule {
  final String id;
  final String description;
  final bool Function(Map<String, dynamic>) evaluator;

  ConstraintRule({
    required this.id,
    required this.description,
    required this.evaluator,
  });

  bool evaluate(Map<String, dynamic> data) => evaluator(data);
}

/// Optimization goals
class OptimizationGoals {
  final List<String> objectives;
  final Map<String, double> weights;
  final Map<String, GoalType> goalTypes; // minimize, maximize, target

  OptimizationGoals({
    List<String>? objectives,
    Map<String, double>? weights,
    Map<String, GoalType>? goalTypes,
  })  : objectives = objectives ?? [],
        weights = weights ?? {},
        goalTypes = goalTypes ?? {};

  double calculateScore(Map<String, dynamic> metrics) {
    double totalScore = 0.0;
    double totalWeight = 0.0;
    
    for (final objective in objectives) {
      if (metrics.containsKey(objective)) {
        final weight = weights[objective] ?? 1.0;
        final goalType = goalTypes[objective] ?? GoalType.maximize;
        final value = metrics[objective] as num;
        
        double normalizedValue;
        switch (goalType) {
          case GoalType.maximize:
            normalizedValue = value;
            break;
          case GoalType.minimize:
            normalizedValue = -value;
            break;
          case GoalType.target:
            final target = weights['${objective}_target'] ?? 0.0;
            normalizedValue = -(value - target).abs();
            break;
        }
        
        totalScore += normalizedValue * weight;
        totalWeight += weight;
      }
    }
    
    return totalWeight > 0 ? totalScore / totalWeight : 0.0;
  }
}

enum GoalType { minimize, maximize, target }

/// Result of a generation operation
class GenerationResult<T> {
  final T generated;
  final double quality;
  final Map<String, dynamic> metadata;
  final List<String> appliedConstraints;
  final DateTime generationTime;

  GenerationResult({
    required this.generated,
    required this.quality,
    Map<String, dynamic>? metadata,
    List<String>? appliedConstraints,
  })  : generationTime = DateTime.now(),
        metadata = metadata ?? {},
        appliedConstraints = appliedConstraints ?? [];

  @override
  String toString() {
    return 'GenerationResult(quality: $quality, time: $generationTime)';
  }
}
