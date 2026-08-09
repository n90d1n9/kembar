import 'package:digital_twin_core/digital_twin_core.dart';
import 'package:digital_twin_core/application/intelligence/prediction_manager.dart';
import 'package:digital_twin_core/application/intelligence/generation_manager.dart';
import 'package:digital_twin_core/application/intelligence/terminal_load_predictor.dart';
import 'package:digital_twin_core/domain/intelligence/statistical_predictor.dart';
import 'package:digital_twin_core/application/generation/template_generator.dart';
import 'package:digital_twin_core/application/generation/port_terminal_generator.dart';

void main() async {
  print('=== Digital Twin Intelligence & Generation Demo ===\n');
  
  // =====================================================
  // PART 1: Prediction System
  // =====================================================
  print('--- Part 1: Intelligent Prediction System ---\n');
  
  // Create prediction manager
  final predictionManager = PredictionManager();
  
  // Register predictors
  final statisticalPredictor = StatisticalPredictor(id: 'stat_pred_001');
  final terminalLoadPredictor = TerminalLoadPredictor(id: 'terminal_pred_001');
  
  predictionManager.registerPredictor(statisticalPredictor);
  predictionManager.registerPredictor(terminalLoadPredictor);
  
  print('✓ Registered predictors:');
  for (final predictor in predictionManager.getAllPredictors()) {
    print('  - ${predictor.name} (${predictor.id})');
  }
  
  // Train predictors with historical data
  print('\nTraining predictors with historical data...');
  
  final trainingData = [
    {'timestamp': DateTime.now().subtract(Duration(hours: 24)), 'value': 450, 'load': 450},
    {'timestamp': DateTime.now().subtract(Duration(hours: 23)), 'value': 465, 'load': 465},
    {'timestamp': DateTime.now().subtract(Duration(hours: 22)), 'value': 480, 'load': 480},
    {'timestamp': DateTime.now().subtract(Duration(hours: 21)), 'value': 495, 'load': 495},
    {'timestamp': DateTime.now().subtract(Duration(hours: 20)), 'value': 510, 'load': 510},
    {'timestamp': DateTime.now().subtract(Duration(hours: 19)), 'value': 525, 'load': 525},
    {'timestamp': DateTime.now().subtract(Duration(hours: 18)), 'value': 540, 'load': 540},
    {'timestamp': DateTime.now().subtract(Duration(hours: 17)), 'value': 555, 'load': 555},
    {'timestamp': DateTime.now().subtract(Duration(hours: 16)), 'value': 570, 'load': 570},
    {'timestamp': DateTime.now().subtract(Duration(hours: 15)), 'value': 585, 'load': 585},
  ];
  
  await predictionManager.trainAll(trainingData);
  print('✓ Training complete\n');
  
  // Make predictions
  print('Making predictions...');
  
  final statPrediction = await predictionManager.predict<num>(
    'stat_pred_001',
    {'current_value': 585, 'steps': 3},
  );
  
  print('\nStatistical Predictor Results:');
  print('  Predicted Value: ${statPrediction.predictedValue}');
  print('  Confidence: ${(statPrediction.confidence * 100).toStringAsFixed(1)}%');
  print('  Method: ${statPrediction.metadata['method']}');
  print('  Contributing Factors: ${statPrediction.contributingFactors.join(", ")}');
  
  // Terminal load prediction
  final terminalPrediction = await predictionManager.predict<int>(
    'terminal_pred_001',
    {
      'current_load': 450,
      'terminal_capacity': 1000,
      'target_time': DateTime.now().add(Duration(hours: 2)),
      'incoming_containers': 50,
      'outgoing_containers': 30,
    },
  );
  
  print('\nTerminal Load Predictor Results:');
  print('  Predicted Load: ${terminalPrediction.predictedValue} containers');
  print('  Confidence: ${(terminalPrediction.confidence * 100).toStringAsFixed(1)}%');
  print('  Target Time: ${terminalPrediction.predictedForTime}');
  print('  Hourly Factor: ${terminalPrediction.metadata['hourly_factor']}');
  print('  Daily Factor: ${terminalPrediction.metadata['daily_factor']}');
  print('  Net Flow: ${terminalPrediction.metadata['net_flow']} containers');
  
  // =====================================================
  // PART 2: Generation System
  // =====================================================
  print('\n\n--- Part 2: Intelligent Generation System ---\n');
  
  // Create generation manager
  final generationManager = GenerationManager();
  
  // Register generators
  final portGenerator = PortTerminalGenerator(id: 'port_gen_001');
  final templateGenerator = TemplateGenerator<Map<String, dynamic>>(
    id: 'template_gen_001',
    name: 'Generic Template Generator',
  );
  
  generationManager.registerGenerator(portGenerator);
  generationManager.registerGenerator(templateGenerator);
  
  print('✓ Registered generators:');
  for (final generator in generationManager.getAllGenerators()) {
    print('  - ${generator.name} (${generator.id})');
  }
  
  // Generate port terminal configuration
  print('\nGenerating port terminal configuration...');
  
  final terminalConstraints = GenerationConstraints(
    parameters: {
      'capacity': 800,
      'area': 15000,
      'crane_count': 6,
      'storage_zones': 4,
    },
    rules: [
      ConstraintRule(
        id: 'min_cranes',
        description: 'Must have at least 4 cranes',
        evaluator: (data) => (data['crane_count'] as int? ?? 0) >= 4,
      ),
      ConstraintRule(
        id: 'min_zones',
        description: 'Must have at least 3 storage zones',
        evaluator: (data) => (data['storage_zones'] as int? ?? 0) >= 3,
      ),
    ],
    bounds: {
      'capacity': 2000,
      'area': 50000,
    },
    requiredFeatures: {'capacity', 'area'},
  );
  
  final terminalResult = await generationManager.generate<Map<String, dynamic>>(
    'port_gen_001',
    terminalConstraints,
  );
  
  print('\n✓ Generated Terminal Configuration:');
  print('  Quality Score: ${(terminalResult.quality * 100).toStringAsFixed(1)}%');
  print('  Type: ${terminalResult.generated['terminal_type']}');
  print('  Total Capacity: ${terminalResult.generated['total_capacity']} containers');
  print('  Total Area: ${terminalResult.generated['total_area']} m²');
  print('  Storage Zones: ${(terminalResult.generated['zones'] as List).length}');
  print('  Cranes: ${(terminalResult.generated['cranes'] as List).length}');
  print('  Entry Gates: ${(terminalResult.generated['gates'] as Map)['entry_gates']}');
  
  // Generate variants
  print('\nGenerating terminal configuration variants...');
  
  final variants = await generationManager.generateVariants<Map<String, dynamic>>(
    'port_gen_001',
    terminalConstraints,
    count: 5,
  );
  
  print('\n✓ Generated ${variants.length} variants:');
  for (int i = 0; i < variants.length; i++) {
    final variant = variants[i];
    print('  Variant ${i + 1}:');
    print('    Quality: ${(variant.quality * 100).toStringAsFixed(1)}%');
    print('    Capacity: ${variant.generated['total_capacity']}');
    print('    Cranes: ${(variant.generated['cranes'] as List).length}');
    print('    Zones: ${(variant.generated['zones'] as List).length}');
  }
  
  // Optimize configuration
  print('\nOptimizing terminal configuration...');
  
  final optimizationGoals = OptimizationGoals(
    objectives: ['throughput', 'efficiency'],
    weights: {
      'throughput': 1.0,
      'efficiency': 1.5,
      'cost': -0.8, // Negative weight to minimize cost
    },
    goalTypes: {
      'throughput': GoalType.maximize,
      'efficiency': GoalType.maximize,
      'cost': GoalType.minimize,
    },
  );
  
  final optimizedResult = await generationManager.optimize<Map<String, dynamic>>(
    'port_gen_001',
    terminalResult.generated,
    optimizationGoals,
    maxIterations: 50,
  );
  
  print('\n✓ Optimized Configuration:');
  print('  Quality Score: ${(optimizedResult.quality * 100).toStringAsFixed(1)}%');
  print('  Iterations: ${optimizedResult.metadata['iterations']}');
  print('  Optimization Method: ${optimizedResult.metadata['optimization_method']}');
  print('  Final Score: ${optimizedResult.metadata['final_score']}');
  
  // =====================================================
  // PART 3: Integrated Scenario
  // =====================================================
  print('\n\n--- Part 3: Integrated Digital Twin Scenario ---\n');
  
  print('Scenario: Planning a new container terminal with predictive analytics\n');
  
  // Step 1: Generate initial terminal design
  print('Step 1: Generate initial terminal design...');
  final initialDesign = await generationManager.generate<Map<String, dynamic>>(
    'port_gen_001',
    GenerationConstraints(
      parameters: {
        'capacity': 600,
        'area': 12000,
        'crane_count': 5,
        'storage_zones': 3,
      },
    ),
  );
  print('  ✓ Initial design generated (Quality: ${(initialDesign.quality * 100).toStringAsFixed(1)}%)');
  
  // Step 2: Predict future load based on design
  print('\nStep 2: Predict terminal load patterns...');
  final loadPredictions = await terminalLoadPredictor.predictBatch([
    {
      'current_load': 300,
      'terminal_capacity': 600,
      'target_time': DateTime.now().add(Duration(hours: 1)),
      'incoming_containers': 40,
      'outgoing_containers': 25,
    },
    {
      'current_load': 315,
      'terminal_capacity': 600,
      'target_time': DateTime.now().add(Duration(hours: 3)),
      'incoming_containers': 60,
      'outgoing_containers': 30,
    },
    {
      'current_load': 345,
      'terminal_capacity': 600,
      'target_time': DateTime.now().add(Duration(hours: 6)),
      'incoming_containers': 80,
      'outgoing_containers': 35,
    },
  ]);
  
  print('  ✓ Load predictions generated:');
  for (int i = 0; i < loadPredictions.length; i++) {
    final pred = loadPredictions[i];
    print('    T+${pred.metadata['steps_ahead'] ?? (i + 1)}h: ${pred.predictedValue} containers (${(pred.confidence * 100).toStringAsFixed(0)}% confidence)');
  }
  
  // Step 3: Optimize design based on predictions
  print('\nStep 3: Optimize design based on predicted loads...');
  final optimizedDesign = await generationManager.optimize<Map<String, dynamic>>(
    'port_gen_001',
    initialDesign.generated,
    OptimizationGoals(
      objectives: ['throughput', 'efficiency'],
      weights: {
        'throughput': 1.2,
        'efficiency': 1.0,
      },
      goalTypes: {
        'throughput': GoalType.maximize,
        'efficiency': GoalType.maximize,
      },
    ),
    maxIterations: 30,
  );
  print('  ✓ Design optimized (Quality improved from ${(initialDesign.quality * 100).toStringAsFixed(1)}% to ${(optimizedDesign.quality * 100).toStringAsFixed(1)}%)');
  
  // Step 4: Generate multiple scenarios
  print('\nStep 4: Generate alternative scenarios...');
  final scenarios = await generationManager.generateVariants<Map<String, dynamic>>(
    'port_gen_001',
    GenerationConstraints(
      parameters: {
        'capacity': 600,
        'area': 12000,
        'crane_count': 5,
        'storage_zones': 3,
      },
    ),
    count: 3,
  );
  
  print('  ✓ Generated ${scenarios.length} scenarios:');
  for (int i = 0; i < scenarios.length; i++) {
    final scenario = scenarios[i];
    print('    Scenario ${i + 1}: Quality ${(scenario.quality * 100).toStringAsFixed(1)}%, '
          'Capacity ${scenario.generated['total_capacity']}, '
          'Cranes ${(scenario.generated['cranes'] as List).length}');
  }
  
  print('\n=== Demo Complete ===');
  print('\nKey Capabilities Demonstrated:');
  print('  ✓ Multi-domain prediction system');
  print('  ✓ Pattern recognition in time-series data');
  print('  ✓ Constraint-based generation');
  print('  ✓ Multi-objective optimization');
  print('  ✓ Variant generation and comparison');
  print('  ✓ Integrated prediction + generation workflow');
  print('\nThis platform-agnostic architecture can be extended to:');
  print('  • Parking lots (predict occupancy, generate layouts)');
  print('  • Restaurants (predict customer flow, generate table arrangements)');
  print('  • Warehouses (predict inventory levels, generate storage configurations)');
  print('  • And any other domain with spatial entities!');
}
