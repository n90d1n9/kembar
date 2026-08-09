import 'package:digital_twin_core/domain/intelligence/i_generator.dart';
import 'package:digital_twin_core/domains/port/terminal.dart';
import 'package:digital_twin_core/domains/port/container.dart';

/// Generator for port terminal layouts and configurations
class PortTerminalGenerator implements IGenerator<Map<String, dynamic>> {
  @override
  final String id;
  @override
  final String name = 'Port Terminal Generator';

  PortTerminalGenerator({String? id}) 
      : id = id ?? 'port_terminal_gen_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<GenerationResult<Map<String, dynamic>>> generate(
    GenerationConstraints constraints
  ) async {
    // Generate terminal configuration
    final config = _generateTerminalConfig(constraints);
    
    return GenerationResult(
      generated: config,
      quality: _evaluateTerminalConfig(config, constraints),
      metadata: {
        'generator_type': 'port_terminal',
        'generation_method': 'template_based',
      },
      appliedConstraints: [
        ...constraints.requiredFeatures,
        ...constraints.rules.map((r) => r.id),
      ],
    );
  }

  Map<String, dynamic> _generateTerminalConfig(GenerationConstraints constraints) {
    final capacity = constraints.parameters['capacity'] as int? ?? 500;
    final area = constraints.parameters['area'] as num? ?? 10000;
    final craneCount = constraints.parameters['crane_count'] as int? ?? 4;
    final storageZones = constraints.parameters['storage_zones'] as int? ?? 3;
    
    // Calculate optimal layout
    final zoneCapacity = (capacity / storageZones).round();
    final areaPerZone = area / storageZones;
    
    return {
      'terminal_type': 'container_terminal',
      'total_capacity': capacity,
      'total_area': area,
      'zones': List.generate(storageZones, (index) => {
        'zone_id': 'ZONE-${index + 1}',
        'capacity': zoneCapacity,
        'area': areaPerZone,
        'type': index == 0 ? 'import' : (index == 1 ? 'export' : 'transit'),
      }),
      'cranes': List.generate(craneCount, (index) => {
        'crane_id': 'CRANE-${index + 1}',
        'type': 'gantry',
        'capacity_per_hour': 30,
        'position': {'x': index * (area / craneCount), 'y': 0},
      }),
      'gates': {
        'entry_gates': 3,
        'exit_gates': 3,
        'processing_time_minutes': 5,
      },
      'operating_hours': {
        'start': 6,
        'end': 22,
        'peak_hours': [9, 10, 11, 14, 15, 16],
      },
    };
  }

  double _evaluateTerminalConfig(
    Map<String, dynamic> config,
    GenerationConstraints constraints
  ) {
    double score = 1.0;
    
    // Check capacity constraint
    if (constraints.parameters.containsKey('min_capacity')) {
      final minCapacity = constraints.parameters['min_capacity'] as int;
      if (config['total_capacity'] < minCapacity) {
        score -= 0.3;
      }
    }
    
    // Check efficiency (cranes per capacity)
    final cranes = config['cranes'] as List;
    final capacity = config['total_capacity'] as int;
    final craneRatio = cranes.length / capacity;
    
    if (craneRatio < 0.005) score -= 0.2; // Too few cranes
    if (craneRatio > 0.02) score -= 0.1;  // Too many cranes (costly)
    
    // Check zone distribution
    final zones = config['zones'] as List;
    if (zones.length < 2) score -= 0.2; // Need at least import/export
    
    return score.clamp(0.0, 1.0);
  }

  @override
  Future<List<GenerationResult<Map<String, dynamic>>>> generateVariants(
    GenerationConstraints constraints, {
    int count = 5,
  }) async {
    final results = <GenerationResult<Map<String, dynamic>>>[];
    
    for (int i = 0; i < count; i++) {
      final variedParams = Map<String, dynamic>.from(constraints.parameters);
      
      // Vary key parameters
      if (variedParams.containsKey('crane_count')) {
        final baseCranes = variedParams['crane_count'] as int;
        variedParams['crane_count'] = baseCranes + (i - 2); // -2 to +2 variation
      }
      
      if (variedParams.containsKey('storage_zones')) {
        final baseZones = variedParams['storage_zones'] as int;
        variedParams['storage_zones'] = (baseZones + (i % 3) - 1).clamp(2, 10);
      }
      
      final variedConstraints = GenerationConstraints(
        parameters: variedParams,
        rules: constraints.rules,
        bounds: constraints.bounds,
        requiredFeatures: constraints.requiredFeatures,
        excludedFeatures: constraints.excludedFeatures,
      );
      
      try {
        final result = await generate(variedConstraints);
        results.add(result);
      } catch (e) {
        continue;
      }
    }
    
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
    var bestScore = goals.calculateScore(_simulateTerminalMetrics(bestConfig));

    for (int i = 0; i < maxIterations; i++) {
      final neighbor = _mutateConfig(bestConfig);
      final neighborScore = goals.calculateScore(_simulateTerminalMetrics(neighbor));

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
        'final_score': bestScore,
      },
    );
  }

  Map<String, dynamic> _mutateConfig(Map<String, dynamic> config) {
    final mutated = Map<String, dynamic>.from(config);
    
    // Randomly mutate one aspect
    final mutationType = DateTime.now().millisecond % 3;
    
    switch (mutationType) {
      case 0:
        // Adjust crane count
        final cranes = List<Map<String, dynamic>>.from(mutated['cranes'] as List);
        if (cranes.length > 2 && DateTime.now().isEven) {
          cranes.removeLast();
        } else {
          cranes.add({
            'crane_id': 'CRANE-${cranes.length + 1}',
            'type': 'gantry',
            'capacity_per_hour': 30,
          });
        }
        mutated['cranes'] = cranes;
        break;
        
      case 1:
        // Adjust zones
        final zones = List<Map<String, dynamic>>.from(mutated['zones'] as List);
        if (zones.length > 2 && DateTime.now().isOdd) {
          zones.removeLast();
        } else {
          zones.add({
            'zone_id': 'ZONE-${zones.length + 1}',
            'capacity': (mutated['total_capacity'] as int) ~/ (zones.length + 1),
            'type': 'transit',
          });
        }
        mutated['zones'] = zones;
        break;
        
      case 2:
        // Adjust gate count
        final gates = Map<String, dynamic>.from(mutated['gates'] as Map);
        final entryGates = gates['entry_gates'] as int;
        gates['entry_gates'] = entryGates + (DateTime.now().isEven ? 1 : -1);
        gates['exit_gates'] = gates['entry_gates'];
        mutated['gates'] = gates;
        break;
    }
    
    return mutated;
  }

  Map<String, dynamic> _simulateTerminalMetrics(Map<String, dynamic> config) {
    final cranes = config['cranes'] as List;
    final zones = config['zones'] as List;
    final gates = config['gates'] as Map;
    final capacity = config['total_capacity'] as int;
    
    // Simulate throughput (containers per hour)
    final craneThroughput = cranes.length * 30;
    final gateThroughput = (gates['entry_gates'] as int) * 12;
    final throughput = craneThroughput * 0.8; // 80% efficiency
    
    // Simulate cost (arbitrary units)
    final craneCost = cranes.length * 100;
    final zoneCost = zones.length * 50;
    final gateCost = (gates['entry_gates'] as int) * 30;
    final cost = craneCost + zoneCost + gateCost;
    
    // Simulate utilization
    final utilization = throughput / capacity * 100;
    
    return {
      'throughput': throughput,
      'cost': cost,
      'utilization': utilization,
      'efficiency': throughput / (cost + 1),
    };
  }
}
