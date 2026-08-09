import 'dart:math';
import 'package:digital_twin_core/domain/intelligence/i_generator.dart';

/// Template-based generator for creating domain-specific configurations
class TemplateGenerator<T> implements IGenerator<Map<String, dynamic>> {
  @override
  final String id;
  @override
  final String name;
  
  final List<Template<T>> _templates = [];
  final Random _random = Random();

  TemplateGenerator({String? id, required this.name}) 
      : id = id ?? 'template_gen_${DateTime.now().millisecondsSinceEpoch}';

  void addTemplate(Template<T> template) {
    _templates.add(template);
  }

  void removeTemplate(String templateId) {
    _templates.removeWhere((t) => t.id == templateId);
  }

  @override
  Future<GenerationResult<Map<String, dynamic>>> generate(
    GenerationConstraints constraints
  ) async {
    // Find matching templates
    final matchingTemplates = _templates.where((t) => 
      constraints.requiredFeatures.isEmpty || 
      t.tags.any((tag) => constraints.requiredFeatures.contains(tag))
    ).toList();

    if (matchingTemplates.isEmpty) {
      throw Exception('No matching templates found for given constraints');
    }

    // Select best template based on constraints
    final selectedTemplate = matchingTemplates.first;
    
    // Generate configuration from template
    final config = selectedTemplate.instantiate(constraints.parameters);
    
    // Validate against constraints
    if (!constraints.validate(config)) {
      throw Exception('Generated configuration does not satisfy constraints');
    }

    final quality = _calculateQuality(config, constraints);

    return GenerationResult(
      generated: config,
      quality: quality,
      metadata: {
        'template_id': selectedTemplate.id,
        'template_name': selectedTemplate.name,
      },
      appliedConstraints: [
        ...constraints.requiredFeatures,
        ...constraints.rules.map((r) => r.id),
      ],
    );
  }

  @override
  Future<List<GenerationResult<Map<String, dynamic>>>> generateVariants(
    GenerationConstraints constraints, {
    int count = 5,
  }) async {
    final results = <GenerationResult<Map<String, dynamic>>>[];
    
    for (int i = 0; i < count; i++) {
      try {
        // Add some randomness to parameters
        final variedParams = Map<String, dynamic>.from(constraints.parameters);
        
        // Vary numeric parameters within bounds
        for (final entry in constraints.bounds.entries) {
          if (variedParams.containsKey(entry.key)) {
            final baseValue = variedParams[entry.key] as num;
            final variation = (_random.nextDouble() - 0.5) * 0.2 * baseValue;
            variedParams[entry.key] = baseValue + variation;
          }
        }
        
        final variedConstraints = GenerationConstraints(
          parameters: variedParams,
          rules: constraints.rules,
          bounds: constraints.bounds,
          requiredFeatures: constraints.requiredFeatures,
          excludedFeatures: constraints.excludedFeatures,
        );
        
        final result = await generate(variedConstraints);
        results.add(result);
      } catch (e) {
        // Skip failed generations
        continue;
      }
    }
    
    // Sort by quality
    results.sort((a, b) => b.quality.compareTo(a.quality));
    
    return results;
  }

  @override
  Future<GenerationResult<Map<String, dynamic>>> optimize(
    Map<String, dynamic> initial,
    OptimizationGoals goals, {
    int maxIterations = 100,
  }) async {
    var bestConfig = Map<String, dynamic>.from(initial);
    var bestScore = goals.calculateScore(_evaluateMetrics(bestConfig));

    for (int i = 0; i < maxIterations; i++) {
      // Generate a neighbor configuration
      final neighbor = _generateNeighbor(bestConfig);
      final neighborScore = goals.calculateScore(_evaluateMetrics(neighbor));

      if (neighborScore > bestScore) {
        bestConfig = neighbor;
        bestScore = neighborScore;
      }
    }

    return GenerationResult(
      generated: bestConfig,
      quality: bestScore,
      metadata: {
        'iterations': maxIterations,
        'optimization_method': 'hill_climbing',
      },
    );
  }

  Map<String, dynamic> _generateNeighbor(Map<String, dynamic> config) {
    final neighbor = Map<String, dynamic>.from(config);
    
    // Randomly modify one parameter
    final keys = neighbor.keys.toList();
    if (keys.isEmpty) return neighbor;
    
    final randomKey = keys[_random.nextInt(keys.length)];
    final currentValue = neighbor[randomKey];
    
    if (currentValue is num) {
      final variation = (_random.nextDouble() - 0.5) * 0.1 * currentValue.abs();
      neighbor[randomKey] = currentValue + variation;
    }
    
    return neighbor;
  }

  Map<String, dynamic> _evaluateMetrics(Map<String, dynamic> config) {
    // Placeholder for metrics evaluation
    // In a real implementation, this would simulate or calculate actual metrics
    return {
      'efficiency': _random.nextDouble(),
      'cost': _random.nextDouble() * 100,
      'throughput': _random.nextDouble() * 1000,
    };
  }

  double _calculateQuality(Map<String, dynamic> config, GenerationConstraints constraints) {
    // Simple quality metric based on constraint satisfaction and parameter optimization
    double quality = 1.0;
    
    // Penalize for being close to bounds
    for (final entry in constraints.bounds.entries) {
      if (config.containsKey(entry.key)) {
        final value = config[entry.key] as num;
        final distanceToBound = (entry.value - value).abs();
        if (distanceToBound < entry.value * 0.1) {
          quality -= 0.1; // Penalty for being too close to bound
        }
      }
    }
    
    return quality.clamp(0.0, 1.0);
  }
}

/// Template for generating configurations
class Template<T> {
  final String id;
  final String name;
  final List<String> tags;
  final Map<String, dynamic> defaultParameters;
  final Map<String, dynamic> Function(Map<String, dynamic>) transformer;

  Template({
    required this.id,
    required this.name,
    this.tags = const [],
    required this.defaultParameters,
    required this.transformer,
  });

  Map<String, dynamic> instantiate(Map<String, dynamic> overrides) {
    final base = Map<String, dynamic>.from(defaultParameters);
    base.addAll(overrides);
    return transformer(base);
  }
}
