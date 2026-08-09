import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/application/simulation/core/simulation_step.dart';

/// Twin Federation Manager for orchestrating multiple independent twins
/// 
/// Enables running multiple domain twins in sync (e.g., Port + Warehouse + City Traffic)
class TwinFederationManager {
  final Map<String, SimulationStep> _twins = {};
  final Map<String, TwinState> _twinStates = {};
  bool _isRunning = false;
  
  /// Add a twin to the federation
  void addTwin(String twinId, SimulationStep simulator, {TwinState? initialState}) {
    if (_twins.containsKey(twinId)) {
      throw ArgumentError('Twin with ID $twinId already exists in federation');
    }
    
    _twins[twinId] = simulator;
    if (initialState != null) {
      _twinStates[twinId] = initialState;
    }
    
    print('Added twin to federation: $twinId');
  }
  
  /// Remove a twin from the federation
  void removeTwin(String twinId) {
    _twins.remove(twinId);
    _twinStates.remove(twinId);
    print('Removed twin from federation: $twinId');
  }
  
  /// Get a twin's simulator by ID
  SimulationStep? getTwin(String twinId) {
    return _twins[twinId];
  }
  
  /// Get all twin IDs in the federation
  List<String> getTwinIds() {
    return _twins.keys.toList();
  }
  
  /// Start synchronized simulation across all twins
  Future<void> startSyncedSimulation({DateTime? startTime}) async {
    if (_isRunning) {
      throw StateError('Federation is already running');
    }
    
    print('Starting synchronized simulation with ${_twins.length} twins');
    _isRunning = true;
    
    // Initialize all twins to the same start time
    final start = startTime ?? DateTime.now();
    for (final entry in _twins.entries) {
      print('Initializing twin ${entry.key} to $start');
      // Would call simulator.initialize(start) in real implementation
    }
    
    // Run simulation loop for all twins in lockstep
    await _runFederatedSimulationLoop();
  }
  
  /// Stop the federated simulation
  void stop() {
    _isRunning = false;
    print('Stopped federated simulation');
  }
  
  /// Pause all twins simultaneously
  void pauseAll() {
    for (final entry in _twins.entries) {
      entry.value.pause();
    }
    print('Paused all ${_twins.length} twins');
  }
  
  /// Resume all twins simultaneously
  void resumeAll() {
    for (final entry in _twins.entries) {
      entry.value.resume();
    }
    print('Resumed all ${_twins.length} twins');
  }
  
  /// Set simulation speed for all twins
  void setSpeedForAll(double multiplier) {
    for (final entry in _twins.entries) {
      entry.value.setTimeMultiplier(multiplier);
    }
    print('Set speed to ${multiplier}x for all twins');
  }
  
  Future<void> _runFederatedSimulationLoop() async {
    while (_isRunning) {
      // Advance all twins by one time step in sync
      for (final entry in _twins.entries) {
        entry.value.step();
      }
      
      // Small delay to prevent CPU spinning
      await Future.delayed(Duration(milliseconds: 16)); // ~60 FPS
    }
  }
  
  /// Get federation status
  Map<String, dynamic> getStatus() {
    return {
      'is_running': _isRunning,
      'twin_count': _twins.length,
      'twin_ids': _twins.keys.toList(),
      'states': _twinStates.map((k, v) => MapEntry(k, v.name)),
    };
  }
}
