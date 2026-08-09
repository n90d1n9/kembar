# Step 13: Interactive Simulation & Game-Style Controls - Implementation

## Overview
This step transforms the digital twin from a static model into a living, interactive simulation with game-like controls, real-time physics, and user-driven events.

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    User Input Layer                         │
│  (Mouse/Touch/Gesture) → GestureHandler → ToolManager      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Interaction Layer                          │
│  DragDropController + CommandManager (Undo/Redo)           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Simulation Layer                          │
│  SimulationStep: Physics → Rules → Events → State Sync     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 Time Control Layer                          │
│  TimeWarp: Pause, Step, Speed, Rewind                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Scenario Layer                             │
│  ScenarioRunner: Objectives, Win/Lose, Scoring             │
└─────────────────────────────────────────────────────────────┘
```

## Files Created

### 1. Physics System (`lib/application/simulation/physics/`)

#### `physics_body.dart`
- **Purpose**: Represents physical properties of entities
- **Key Features**:
  - Mass, velocity, angular velocity
  - Friction and restitution (bounciness)
  - Static vs dynamic vs kinematic bodies
  - Force and impulse application

#### `simple_physics_engine.dart`
- **Purpose**: Lightweight Euler integration physics engine
- **Key Features**:
  - Gravity simulation
  - Collision detection and response
  - Friction and damping
  - Dynamic-static and dynamic-dynamic collision resolution

### 2. Simulation Core (`lib/application/simulation/core/`)

#### `simulation_step.dart`
- **Purpose**: Orchestrates the complete update loop
- **Execution Order**:
  1. Physics Update
  2. Rule Evaluation
  3. Event Processing
  4. State Synchronization
- **Integration**: Connects physics, rules, events, and twin state

### 3. Interaction System (`lib/application/interaction/`)

#### `drag_drop_controller.dart`
- **Purpose**: Manages drag-and-drop operations
- **Key Features**:
  - Start/update/end drag lifecycle
  - Snap-to-grid support
  - Placement validation via PlacementEngine
  - Rollback on invalid placement

#### `tool_manager.dart`
- **Purpose**: Manages interaction tools
- **Tools Implemented**:
  - SelectTool: Entity selection
  - MoveTool: Position manipulation
  - RotateTool: Orientation manipulation
  - ScaleTool: Size manipulation
  - SpawnTool: Entity creation
  - DeleteTool: Entity removal
- **Features**: Tool activation/deactivation, mode switching

#### `gesture_handler.dart`
- **Purpose**: Interprets touch/mouse input as gestures
- **Supported Gestures**:
  - Tap, Double-tap
  - Long-press
  - Swipe (up/down/left/right)
  - Pinch (in/out)
  - Rotate
- **Configurable**: Thresholds for swipe distance, long-press duration, double-tap timeout

### 4. Event System (`lib/domain/event/`)

#### `command.dart`
- **Purpose**: Implements Command Pattern for undo/redo
- **Commands**:
  - MoveEntityCommand
  - CreateEntityCommand
  - DeleteEntityCommand
  - ChangeStateCommand
- **CommandManager**: History tracking, undo/redo execution

#### `event_bus.dart`
- **Purpose**: Pub/Sub system for decoupled communication
- **Features**:
  - Subscribe/unsubscribe to event types
  - Immediate publishing
  - Queued event processing
  - Error handling in listeners

### 5. Game Features (`lib/application/simulation/`)

#### `time_warp.dart`
- **Purpose**: Advanced time control
- **Capabilities**:
  - Pause/resume
  - Speed control (0.5x, 2x, 10x, etc.)
  - Step-forward (frame-by-frame when paused)
  - Rewind (with configurable speed)
  - Fast-forward
  - Time history tracking
  - Formatted time display (MM:SS.ms)

#### `scenario_runner.dart`
- **Purpose**: Manages game-style scenarios
- **Components**:
  - Scenario: Definition with objectives and time limits
  - Objective: Abstract base for win conditions
  - FillPercentageObjective: Reach capacity target
  - MaximizeThroughputObjective: Process items target
  - ScenarioRunner: Execution, scoring, win/lose detection

## Key Features

### Real-Time Physics
```dart
final physics = SimplePhysicsEngine(
  gravity: SpatialVector3(0, -9.8, 0),
  damping: 0.99,
);

// Add physics body to entity
final body = PhysicsBody(
  entityId: 'box_001',
  mass: 5.0,
  friction: 0.5,
  restitution: 0.3,
);
physics.addBody(body);

// Apply force
body.applyForce(SpatialVector3(0, 10, 0), deltaTime);
```

### Tool-Based Interaction
```dart
final toolManager = ToolManager();
toolManager.registerTool(MoveTool());
toolManager.activateTool(ToolType.move);

// Handle input
toolManager.handleMouseDown(x, y);
toolManager.handleMouseMove(x, y, deltaX, deltaY);
toolManager.handleMouseUp(x, y);
```

### Gesture Recognition
```dart
final gestureHandler = GestureHandler(
  swipeThreshold: 50.0,
  longPressDuration: 500,
);

gestureHandler.onTap = (event) => selectEntity(event.x, event.y);
gestureHandler.onSwipe = (event) => panCamera(event.type);
gestureHandler.onPinch = (event) => zoom(event.magnitude!);
```

### Undo/Redo
```dart
final commandManager = CommandManager(maxHistorySize: 100);

// Execute command
commandManager.execute(moveCommand);

// Undo last action
if (commandManager.canUndo) {
  commandManager.undo();
}

// Redo
if (commandManager.canRedo) {
  commandManager.redo();
}
```

### Time Control
```dart
final timeWarp = TimeWarp();

// Standard controls
timeWarp.pause();
timeWarp.resume();
timeWarp.setSpeed(2.0); // 2x speed

// Advanced controls
timeWarp.stepForward(0.016); // One frame at 60 FPS
timeWarp.startRewind(speed: 5.0);
timeWarp.rewindBy(10.0); // Go back 10 seconds
timeWarp.formattedTime; // "02:35.42"
```

### Scenarios & Objectives
```dart
final scenario = Scenario(
  id: 'warehouse_challenge',
  name: 'Warehouse Organization',
  objectives: [
    FillPercentageObjective(
      id: 'fill_obj',
      targetEntityId: 'storage_001',
      targetPercentage: 0.8,
    ),
  ],
  timeLimit: Duration(minutes: 2),
);

final runner = ScenarioRunner(
  scenario: scenario,
  onStateUpdate: (state) => updateUI(state),
);

runner.start();
final score = runner.calculateScore();
final isWon = runner.isWon;
```

## Integration Example

```dart
// Initialize all systems
final physics = SimplePhysicsEngine();
final ruleEngine = RuleEngine();
final eventBus = EventBus();
final timeWarp = TimeWarp();
final simulator = SimulationStep(
  physics: physics,
  ruleEngine: ruleEngine,
  eventBus: eventBus,
  initialState: initialState,
  timeWarp: timeWarp,
);

// Setup interaction
final toolManager = ToolManager();
final gestureHandler = GestureHandler();
final commandManager = CommandManager();

// Game loop
void gameLoop(double deltaTime) {
  // Handle user input
  gestureHandler.handleDown(x, y);
  
  // Update simulation
  if (!timeWarp.isPaused) {
    simulator.step(timeWarp.getDeltaTime(deltaTime));
  }
  
  // Process events
  eventBus.processQueue();
  
  // Render
  renderer.render(currentState);
}
```

## Benefits

1. **Game-Like Feel**: Intuitive controls, responsive feedback, satisfying interactions
2. **User-Friendly**: Drag-drop, gestures, undo/redo make it accessible
3. **Educational**: Scenarios with objectives turn learning into a game
4. **Flexible**: Works across domains (port, parking, restaurant, warehouse)
5. **Performant**: Lightweight physics, efficient event handling
6. **Extensible**: Easy to add new tools, gestures, commands, objectives

## Testing

Run the demo:
```bash
dart run example/step13_interactive_simulation_demo.dart
```

Expected output shows:
- Physics initialization
- Tool management
- Gesture recognition
- Drag-drop operations
- Command undo/redo
- Scenario execution
- Event bus communication

## Next Steps

- Step 14: Multi-user collaboration
- Step 15: AR/VR integration
- Step 16: Machine learning predictions
- Step 17: Real-time data streaming from IoT sensors
