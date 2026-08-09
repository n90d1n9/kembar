import 'package:digital_twin_core/application/simulation/physics/simple_physics_engine.dart';
import 'package:digital_twin_core/domain/rules/rule_engine.dart';
import 'package:digital_twin_core/domain/event/event_bus.dart';
import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/application/spatial/spatial_world_builder.dart';
import 'package:digital_twin_core/application/simulation/time_warp.dart';

/// Orchestrates the complete simulation update loop.
/// Order: Physics → Rules → Events → State Sync
class SimulationStep {
  final SimplePhysicsEngine physics;
  final RuleEngine ruleEngine;
  final EventBus eventBus;
  final TimeWarp timeWarp;
  
  TwinState _currentState;
  SpatialWorldBuilder? _worldBuilder;
  
  bool _isRunning = false;
  int _stepCount = 0;
  
  SimulationStep({
    required this.physics,
    required this.ruleEngine,
    required this.eventBus,
    required TwinState initialState,
    TimeWarp? timeWarp,
  })  : _currentState = initialState,
        timeWarp = timeWarp ?? TimeWarp();
  
  /// Set the spatial world builder for state synchronization
  void setWorldBuilder(SpatialWorldBuilder builder) {
    _worldBuilder = builder;
  }
  
  /// Current simulation time in seconds
  double get currentTime => timeWarp.currentTime;
  
  /// Number of steps executed
  int get stepCount => _stepCount;
  
  /// Whether simulation is running
  bool get isRunning => _isRunning;
  
  /// Get current twin state
  TwinState get currentState => _currentState;
  
  /// Start the simulation loop
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    timeWarp.resume();
  }
  
  /// Stop the simulation loop
  void stop() {
    _isRunning = false;
    timeWarp.pause();
  }
  
  /// Pause simulation (can be resumed)
  void pause() {
    timeWarp.pause();
  }
  
  /// Resume paused simulation
  void resume() {
    if (!_isRunning) return;
    timeWarp.resume();
  }
  
  /// Execute a single simulation step
  void step(double baseDeltaTime) {
    if (!timeWarp.canStep) return;
    
    final deltaTime = timeWarp.getDeltaTime(baseDeltaTime);
    if (deltaTime <= 0) return;
    
    // Step 1: Physics Update
    final collidables = _worldBuilder?.build(_currentState).boundsList ?? [];
    physics.step(deltaTime, collidables);
    
    // Step 2: Rule Evaluation
    // Convert physics bodies back to entity states if needed
    ruleEngine.processAll(_currentState.entities.values.toList());
    
    // Step 3: Event Processing
    eventBus.processQueue();
    
    // Step 4: State Synchronization
    _syncPhysicsToState();
    
    _stepCount++;
    
    // Broadcast step completion
    eventBus.publish('simulation_step', {
      'step': _stepCount,
      'time': currentTime,
      'deltaTime': deltaTime,
    });
  }
  
  /// Run multiple steps at once (for fast-forward)
  void stepMultiple(int steps, double baseDeltaTime) {
    for (int i = 0; i < steps; i++) {
      step(baseDeltaTime);
    }
  }
  
  /// Synchronize physics state back to twin state
  void _syncPhysicsToState() {
    // In a full implementation, this would update entity positions
    // based on their physics body velocities and positions
    // For now, this is a placeholder for the integration point
  }
  
  /// Reset simulation to initial state
  void reset(TwinState initialState) {
    stop();
    _currentState = initialState;
    _stepCount = 0;
    timeWarp.reset();
    eventBus.publish('simulation_reset', {'time': 0});
  }
}
