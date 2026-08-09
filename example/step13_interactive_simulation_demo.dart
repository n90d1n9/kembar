import 'package:digital_twin_core/digital_twin_core.dart';

void main() async {
  print('=== Step 13: Interactive Simulation & Game-Style Controls Demo ===\n');
  
  // Initialize core systems
  final physics = SimplePhysicsEngine(gravity: SpatialVector3(0, -9.8, 0));
  final ruleEngine = RuleEngine();
  final eventBus = EventBus();
  final timeWarp = TimeWarp();
  
  // Create initial twin state
  final initialState = TwinState(entities: {});
  
  // Create simulation step orchestrator
  final simulator = SimulationStep(
    physics: physics,
    ruleEngine: ruleEngine,
    eventBus: eventBus,
    initialState: initialState,
    timeWarp: timeWarp,
  );
  
  // Setup interaction tools
  final toolManager = ToolManager();
  toolManager.registerTool(SelectTool());
  toolManager.registerTool(MoveTool());
  toolManager.registerTool(RotateTool());
  toolManager.registerTool(ScaleTool());
  toolManager.registerTool(SpawnTool());
  toolManager.registerTool(DeleteTool());
  
  // Setup gesture handler
  final gestureHandler = GestureHandler(
    swipeThreshold: 30.0,
    longPressDuration: 400,
    doubleTapTimeout: 250,
  );
  
  // Setup drag-drop controller (needs placement engine)
  final placementEngine = PlacementEngine(
    candidateGenerator: CompositeCandidateGenerator.defaultSet(),
    constraints: [CollisionConstraint(), SurfaceFitConstraint()],
    scorer: CompositePlacementScorer.defaultSet(),
  );
  final dragDropController = DragDropController(placementEngine: placementEngine);
  
  // Setup command manager for undo/redo
  final commandManager = CommandManager(maxHistorySize: 100);
  
  print('✓ Core systems initialized');
  print('  - Physics engine with gravity: -9.8 m/s²');
  print('  - Rule engine ready');
  print('  - Event bus ready');
  print('  - Time warp controller ready');
  print('  - Tool manager with 6 tools');
  print('  - Gesture handler configured');
  print('  - Drag-drop controller ready');
  print('  - Command manager with undo/redo\n');
  
  // Demonstrate time control
  print('=== Time Control Demo ===');
  simulator.start();
  print('Simulation started at 1x speed');
  
  timeWarp.setSpeed(2.0);
  print('Fast-forward to 2x speed');
  
  timeWarp.pause();
  print('Simulation paused');
  
  timeWarp.stepForward(0.016); // Step one frame (60 FPS)
  print('Stepped forward one frame: ${timeWarp.formattedTime}');
  
  timeWarp.resume();
  timeWarp.startRewind(speed: 5.0);
  print('Rewinding at 5x speed');
  
  timeWarp.stopRewind();
  timeWarp.reset();
  print('Time reset: ${timeWarp.formattedTime}\n');
  
  // Demonstrate tool usage
  print('=== Tool Management Demo ===');
  toolManager.activateTool(ToolType.select);
  print('Activated: Select tool');
  
  toolManager.activateTool(ToolType.move);
  print('Activated: Move tool');
  
  toolManager.handleMouseDown(100.0, 150.0);
  print('Mouse down at (100, 150)');
  
  toolManager.handleMouseMove(120.0, 150.0, 20.0, 0.0);
  print('Mouse moved by (20, 0)');
  
  toolManager.handleMouseUp(120.0, 150.0);
  print('Mouse up at (120, 150)');
  
  toolManager.deactivateAll();
  print('All tools deactivated\n');
  
  // Demonstrate gesture recognition
  print('=== Gesture Recognition Demo ===');
  gestureHandler.onTap = (event) => print('  → Tap detected at (${event.x}, ${event.y})');
  gestureHandler.onDoubleTap = (event) => print('  → Double-tap detected');
  gestureHandler.onLongPress = (event) => print('  → Long-press detected');
  gestureHandler.onSwipe = (event) => print('  → Swipe ${event.type} detected (distance: ${event.magnitude})');
  
  // Simulate tap
  gestureHandler.handleDown(50.0, 50.0);
  gestureHandler.handleUp(50.0, 50.0);
  
  // Simulate swipe
  gestureHandler.handleDown(100.0, 100.0);
  gestureHandler.handleMove(100.0, 150.0);
  gestureHandler.handleUp(100.0, 200.0);
  print('Gesture simulation complete\n');
  
  // Demonstrate drag-and-drop
  print('=== Drag & Drop Demo ===');
  dragDropController.startDrag('entity_001', SpatialVector3(0, 0, 0));
  print('Started dragging entity_001 from origin');
  
  dragDropController.updateDrag(SpatialVector3(5, 0, 3));
  print('Dragged to position (5, 0, 3)');
  
  final result = dragDropController.endDrag();
  print('Drag ended: ${result.success ? 'SUCCESS' : 'FAILED'}');
  
  // Test snap-to-grid
  final snapped = dragDropController.snapToGrid(SpatialVector3(2.3, 1.7, 4.9), 1.0);
  print('Snapped (2.3, 1.7, 4.9) to grid: ($snapped)\n');
  
  // Demonstrate command pattern with undo/redo
  print('=== Command Pattern & Undo/Redo Demo ===');
  
  // Create a mock entity for commands
  final testEntity = Entity(
    name: 'Test Box',
    properties: {'type': 'box'},
    currentState: State(
      id: 'state_001',
      name: 'Initial',
      attributes: {},
    ),
  );
  
  var currentPosition = {'x': 0.0, 'y': 0.0, 'z': 0.0};
  
  // Execute move command
  final moveCommand = MoveEntityCommand(
    entity: testEntity,
    fromPosition: Map.from(currentPosition),
    toPosition: {'x': 10.0, 'y': 0.0, 'z': 0.0},
    updateCallback: (newPos) => currentPosition = newPos,
  );
  
  commandManager.execute(moveCommand);
  print('Executed: Move entity to (10, 0, 0)');
  print('Current position: $currentPosition');
  print('Can undo: ${commandManager.canUndo}, Can redo: ${commandManager.canRedo}');
  
  // Undo
  commandManager.undo();
  print('Undone! Position back to: $currentPosition');
  
  // Redo
  commandManager.redo();
  print('Redone! Position back to: $currentPosition\n');
  
  // Demonstrate scenario system
  print('=== Scenario System Demo ===');
  
  // Create a simple scenario
  final scenario = Scenario(
    id: 'warehouse_challenge_01',
    name: 'Warehouse Organization Challenge',
    description: 'Organize the warehouse to 80% capacity in 2 minutes',
    initialState: initialState,
    objectives: [
      FillPercentageObjective(
        id: 'fill_obj',
        targetEntityId: 'storage_001',
        targetPercentage: 0.8,
      ),
      MaximizeThroughputObjective(
        id: 'throughput_obj',
        targetCount: 50,
      ),
    ],
    timeLimit: Duration(seconds: 120),
  );
  
  final scenarioRunner = ScenarioRunner(
    scenario: scenario,
    onStateUpdate: (state) {
      // Update UI or perform other actions
    },
  );
  
  scenarioRunner.start();
  print('Started scenario: ${scenario.name}');
  print('Time limit: ${scenario.timeLimit!.inSeconds} seconds');
  print('Objectives: ${scenario.objectives.length}');
  
  // Simulate some progress
  await Future.delayed(Duration(milliseconds: 100));
  
  final score = scenarioRunner.calculateScore();
  print('Current score: ${(score * 100).toStringAsFixed(1)}%');
  print('Elapsed time: ${scenarioRunner.elapsedTime.inSeconds}s');
  print('Remaining time: ${scenarioRunner.remainingTime?.inSeconds ?? 'N/A'}s');
  
  scenarioRunner.checkObjectives();
  for (final result in scenarioRunner.objectiveResults) {
    print('  - $result');
  }
  
  scenarioRunner.stop();
  print('Scenario stopped\n');
  
  // Demonstrate event bus
  print('=== Event Bus Demo ===');
  
  eventBus.subscribe('entity_moved', (eventType, data) {
    print('  → Event received: $eventType');
    print('    Data: $data');
  });
  
  eventBus.publish('entity_moved', {
    'entity_id': 'box_001',
    'from': {'x': 0, 'y': 0},
    'to': {'x': 10, 'y': 5},
  });
  
  eventBus.queue('simulation_step', {'step': 1, 'time': 0.016});
  eventBus.processQueue();
  print('Event queue processed\n');
  
  // Final summary
  print('=== Summary ===');
  print('✓ Physics engine: Gravity, collision, friction, restitution');
  print('✓ Simulation loop: Physics → Rules → Events → State Sync');
  print('✓ Interaction tools: Select, Move, Rotate, Scale, Spawn, Delete');
  print('✓ Gesture support: Tap, Double-tap, Long-press, Swipe, Pinch, Rotate');
  print('✓ Drag & drop: Snap-to-grid, validation, rollback');
  print('✓ Command pattern: Full undo/redo support');
  print('✓ Time control: Pause, step, speed, rewind');
  print('✓ Scenarios: Objectives, win/lose conditions, scoring');
  print('✓ Event bus: Decoupled pub/sub communication');
  print('\n🎮 Your digital twin is now fully interactive and game-ready!');
}
