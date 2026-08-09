import 'package:digital_twin_core/digital_twin_core.dart';

void main() async {
  print('=== Step 14: Multi-Domain Intelligence & Prediction Engine Demo ===\n');

  // Initialize prediction registry
  final registry = PredictorRegistry();
  
  // Register domain-specific predictors
  registry.register(PortCongestionPredictor());
  registry.register(ParkingOccupancyPredictor());
  registry.register(RestaurantWaitTimePredictor());
  registry.register(WarehouseBottleneckPredictor());

  print('✓ Registered predictors for domains: ${registry.getRegisteredDomains().join(", ")}\n');

  // Create sample twin states for each domain
  final portState = _createPortState();
  final parkingState = _createParkingState();
  final restaurantState = _createRestaurantState();
  final warehouseState = _createWarehouseState();

  // Demo 1: Port Congestion Prediction
  print('--- Demo 1: Port Terminal Congestion Prediction ---');
  final portRequest = PredictionRequest.forCongestion(
    domain: 'port',
    horizon: Duration(hours: 2),
    state: portState,
  );
  
  final portResult = await registry.predict(portRequest);
  if (portResult != null) {
    print('Prediction: ${portResult.summary}');
    print('Current Utilization: ${(portResult.forecastedState['current_utilization'] as num * 100).toStringAsFixed(1)}%');
    print('Projected Utilization: ${(portResult.forecastedState['projected_utilization'] as num * 100).toStringAsFixed(1)}%');
    print('Recommendations:');
    for (final rec in portResult.recommendations.take(2)) {
      print('  • $rec');
    }
  }
  print('');

  // Demo 2: Parking Occupancy Prediction
  print('--- Demo 2: Parking Lot Occupancy Forecast ---');
  final parkingRequest = PredictionRequest.forOccupancy(
    domain: 'parking',
    horizon: Duration(hours: 1),
    state: parkingState,
    additionalContext: {'has_event': true, 'event_size': 'large'},
  );
  
  final parkingResult = await registry.predict(parkingRequest);
  if (parkingResult != null) {
    print('Prediction: ${parkingResult.summary}');
    print('Current Occupancy: ${(parkingResult.forecastedState['current_occupancy_rate'] as num * 100).toStringAsFixed(1)}%');
    print('Projected Occupancy: ${(parkingResult.forecastedState['projected_occupancy_rate'] as num * 100).toStringAsFixed(1)}%');
    print('Available Spaces: ${parkingResult.forecastedState['available_spaces']}');
    print('Recommendations:');
    for (final rec in parkingResult.recommendations.take(2)) {
      print('  • $rec');
    }
  }
  print('');

  // Demo 3: Restaurant Wait Time Prediction
  print('--- Demo 3: Restaurant Wait Time Estimation ---');
  final restaurantRequest = PredictionRequest.forWaitTime(
    domain: 'restaurant',
    horizon: Duration(minutes: 30),
    state: restaurantState,
  );
  
  final restaurantResult = await registry.predict(restaurantRequest);
  if (restaurantResult != null) {
    print('Prediction: ${restaurantResult.summary}');
    print('Average Wait: ${restaurantResult.forecastedState['avg_wait_time_minutes']} minutes');
    print('Waiting Parties: ${restaurantResult.forecastedState['waiting_parties']}');
    print('Recommendations:');
    for (final rec in restaurantResult.recommendations.take(2)) {
      print('  • $rec');
    }
  }
  print('');

  // Demo 4: Warehouse Bottleneck Prediction
  print('--- Demo 4: Warehouse Bottleneck Detection ---');
  final warehouseRequest = PredictionRequest(
    domain: 'warehouse',
    predictionType: 'bottleneck',
    horizon: Duration(hours: 4),
    currentState: warehouseState,
    context: {
      'order_rate': 15.0,
      'pick_rate': 10.0,
      'worker_count': 2,
    },
  );
  
  final warehouseResult = await registry.predict(warehouseRequest);
  if (warehouseResult != null) {
    print('Prediction: ${warehouseResult.summary}');
    print('Congestion Severity: ${(warehouseResult.forecastedState['congestion_severity'] as num * 100).toStringAsFixed(1)}%');
    print('Projected Backlog: ${warehouseResult.forecastedState['projected_backlog']} orders');
    print('Bottleneck Zones:');
    final zones = warehouseResult.forecastedState['bottleneck_zones'] as List? ?? [];
    for (final zone in zones.take(3)) {
      print('  • $zone');
    }
    print('Recommendations:');
    for (final rec in warehouseResult.recommendations.take(2)) {
      print('  • $rec');
    }
  }
  print('');

  // Demo 5: Optimization Suggestions
  print('--- Demo 5: Optimization Suggestions ---');
  final optimizer = SimpleOptimizer();
  final objectives = [
    ObjectiveFunction.minimizeWaitTime(weight: 2.0),
    ObjectiveFunction.maximizeThroughput(weight: 1.5),
  ];
  
  final suggestions = await optimizer.suggest(
    currentState: restaurantState,
    objectives: objectives,
  );
  
  print('Top Optimization Suggestions:');
  for (final suggestion in suggestions.take(3)) {
    print('  • ${suggestion.description}');
    print('    Estimated Improvement: ${suggestion.estimatedImprovement.toStringAsFixed(1)}%');
    print('    Complexity: ${suggestion.implementationComplexity}');
  }
  print('');

  // Demo 6: Anomaly Detection
  print('--- Demo 6: Anomaly Detection ---');
  final detector = AnomalyDetector(defaultThreshold: 2.0);
  
  // Register baseline for crane productivity
  detector.registerBaseline(
    'crane_productivity',
    BaselineMetrics.fromValues([25.0, 27.0, 26.0, 28.0, 25.5, 27.5, 26.5]),
  );
  
  // Check current value
  final anomalyResult = detector.check('crane_productivity', 15.0);
  print('Metric: crane_productivity');
  print('Status: ${anomalyResult.isAnomalous ? "⚠️ ANOMALY DETECTED" : "✓ Normal"}');
  print('Severity: ${anomalyResult.severity}');
  print('Reason: ${anomalyResult.reason}');
  print('');

  print('=== Demo Complete ===');
  print('Your digital twin platform now has intelligent prediction, optimization, and anomaly detection across ALL domains!');
}

TwinState _createPortState() {
  final terminal = DomainFactory.createEntity(
    'port', 'terminal', 'Main Terminal', {'capacity': 500}
  ) as Terminal;
  
  // Add 400 containers (80% full)
  for (int i = 0; i < 400; i++) {
    final container = DomainFactory.createEntity(
      'port', 'container', 'CTN-$i',
      {'cargo_type': 'general', 'weight': 5000.0, 'destination': 'Unknown'}
    ) as Container;
    terminal.addContainer(container);
  }
  
  return TwinState(entities: [terminal]);
}

TwinState _createParkingState() {
  final spaces = <Entity>[];
  
  // Create 100 parking spaces, 75 occupied
  for (int i = 0; i < 100; i++) {
    final space = DomainFactory.createEntity(
      'parking', 'space', 'Space-$i',
      {'size': 'standard', 'is_occupied': i < 75}
    ) as ParkingSpace;
    spaces.add(space);
  }
  
  return TwinState(entities: spaces);
}

TwinState _createRestaurantState() {
  final entities = <Entity>[];
  
  // Create 20 tables, 18 occupied
  for (int i = 0; i < 20; i++) {
    final table = DomainFactory.createEntity(
      'restaurant', 'table', 'Table-$i',
      {'capacity': 4, 'is_occupied': i < 18}
    ) as RestaurantTable;
    entities.add(table);
  }
  
  // Create 8 waiting customer parties
  for (int i = 0; i < 8; i++) {
    final customer = DomainFactory.createEntity(
      'restaurant', 'customer', 'Party-$i',
      {'party_size': (i % 4) + 1, 'wait_time': i * 5}
    ) as Customer;
    entities.add(customer);
  }
  
  return TwinState(entities: entities);
}

TwinState _createWarehouseState() {
  final entities = <Entity>[];
  
  // Create 10 storage units
  for (int i = 0; i < 10; i++) {
    final capacity = 50;
    final load = i < 3 ? 48 : (i < 7 ? 35 : 20); // First 3 are nearly full
    
    final storage = DomainFactory.createEntity(
      'warehouse', 'storage', 'Shelf-$i',
      {'capacity': capacity, 'unit_type': 'shelf'}
    ) as StorageUnit;
    
    // Add items to storage
    for (int j = 0; j < load; j++) {
      final item = DomainFactory.createEntity(
        'warehouse', 'item', 'Item-${i}-${j}',
        {'item_type': 'component', 'weight': 1.0, 'dimensions': {'length': 0.1, 'width': 0.1, 'height': 0.1}}
      ) as WarehouseItem;
      storage.addItem(item);
    }
    
    entities.add(storage);
  }
  
  return TwinState(entities: entities);
}
