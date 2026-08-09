import 'package:digital_twin_core/domain/twin/twin_state.dart';

/// Represents a simulation scenario with objectives and win/lose conditions.
class Scenario {
  final String id;
  final String name;
  final String description;
  final TwinState initialState;
  final List<Objective> objectives;
  final Duration? timeLimit;
  final Map<String, dynamic> metadata;
  
  Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.initialState,
    this.objectives = const [],
    this.timeLimit,
    this.metadata = const {},
  });
}

/// An objective that can be completed in a scenario
abstract class Objective {
  final String id;
  final String description;
  final double weight; // For scoring
  
  Objective({
    required this.id,
    required this.description,
    this.weight = 1.0,
  });
  
  /// Check if the objective is complete
  bool isComplete(TwinState state);
  
  /// Get progress as a percentage (0.0 - 1.0)
  double getProgress(TwinState state);
}

/// Objective to reach a certain fill percentage
class FillPercentageObjective extends Objective {
  final String targetEntityId;
  final double targetPercentage;
  
  FillPercentageObjective({
    required String id,
    required this.targetEntityId,
    required this.targetPercentage,
  }) : super(
    id: id,
    description: 'Fill $targetEntityId to ${targetPercentage * 100}%',
  );
  
  @override
  bool isComplete(TwinState state) => getProgress(state) >= 1.0;
  
  @override
  double getProgress(TwinState state) {
    final entity = state.entities[targetEntityId];
    if (entity == null) return 0.0;
    
    final capacity = entity.properties['capacity'] as num? ?? 0;
    final current = entity.properties['current_load'] as num? ?? 0;
    
    if (capacity == 0) return 0.0;
    
    final progress = (current / capacity).clamp(0.0, 1.0);
    return (progress / targetPercentage).clamp(0.0, 1.0);
  }
}

/// Objective to maximize throughput
class MaximizeThroughputObjective extends Objective {
  final int targetCount;
  
  MaximizeThroughputObjective({
    required String id,
    required this.targetCount,
  }) : super(
    id: id,
    description: 'Process $targetCount items',
  );
  
  @override
  bool isComplete(TwinState state) => getProgress(state) >= 1.0;
  
  @override
  double getProgress(TwinState state) {
    // Count entities with 'processed' status
    var processedCount = 0;
    for (final entity in state.entities.values) {
      if (entity.properties['processed'] == true) {
        processedCount++;
      }
    }
    return (processedCount / targetCount).clamp(0.0, 1.0);
  }
}

/// Manages scenario execution, loading, saving, and objective tracking.
class ScenarioRunner {
  final Scenario scenario;
  final Function(TwinState) onStateUpdate;
  
  bool _isRunning = false;
  DateTime? _startTime;
  DateTime? _endTime;
  TwinState _currentState;
  final List<ObjectiveResult> _objectiveResults = [];
  
  ScenarioRunner({
    required this.scenario,
    required this.onStateUpdate,
    TwinState? initialState,
  }) : _currentState = initialState ?? scenario.initialState;
  
  /// Start the scenario
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _startTime = DateTime.now();
    _objectiveResults.clear();
    
    print('Started scenario: ${scenario.name}');
    if (scenario.timeLimit != null) {
      print('Time limit: ${scenario.timeLimit!.inSeconds} seconds');
    }
  }
  
  /// Stop the scenario
  void stop() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _endTime = DateTime.now();
    
    print('Stopped scenario: ${scenario.name}');
  }
  
  /// Check if scenario is running
  bool get isRunning => _isRunning;
  
  /// Get elapsed time
  Duration get elapsedTime {
    if (_startTime == null) return Duration.zero;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!);
  }
  
  /// Get remaining time (if time-limited)
  Duration? get remainingTime {
    if (scenario.timeLimit == null || !_isRunning) return null;
    final elapsed = elapsedTime;
    if (elapsed >= scenario.timeLimit!) return Duration.zero;
    return scenario.timeLimit! - elapsed;
  }
  
  /// Check if time limit exceeded
  bool get isTimeUp {
    if (scenario.timeLimit == null || !_isRunning) return false;
    return elapsedTime >= scenario.timeLimit!;
  }
  
  /// Update the current state
  void updateState(TwinState newState) {
    _currentState = newState;
    onStateUpdate(newState);
  }
  
  /// Get current state
  TwinState get currentState => _currentState;
  
  /// Check all objectives
  void checkObjectives() {
    for (final objective in scenario.objectives) {
      final complete = objective.isComplete(_currentState);
      final progress = objective.getProgress(_currentState);
      
      _objectiveResults.add(ObjectiveResult(
        objective: objective,
        isComplete: complete,
        progress: progress,
      ));
    }
  }
  
  /// Get all objective results
  List<ObjectiveResult> get objectiveResults => 
      List.unmodifiable(_objectiveResults);
  
  /// Check if all objectives are complete
  bool get allObjectivesComplete {
    return scenario.objectives.every((obj) => obj.isComplete(_currentState));
  }
  
  /// Calculate overall score (0.0 - 1.0)
  double calculateScore() {
    if (scenario.objectives.isEmpty) return 0.0;
    
    double totalWeight = 0;
    double weightedProgress = 0;
    
    for (final objective in scenario.objectives) {
      final progress = objective.getProgress(_currentState);
      weightedProgress += progress * objective.weight;
      totalWeight += objective.weight;
    }
    
    return totalWeight > 0 ? weightedProgress / totalWeight : 0.0;
  }
  
  /// Check if scenario is won
  bool get isWon => allObjectivesComplete && !isTimeUp;
  
  /// Check if scenario is lost
  bool get isLost => isTimeUp && !allObjectivesComplete;
  
  /// Reset scenario to initial state
  void reset() {
    stop();
    _currentState = scenario.initialState;
    _objectiveResults.clear();
    _startTime = null;
    _endTime = null;
    onStateUpdate(_currentState);
    print('Reset scenario: ${scenario.name}');
  }
}

/// Result of an objective check
class ObjectiveResult {
  final Objective objective;
  final bool isComplete;
  final double progress;
  
  ObjectiveResult({
    required this.objective,
    required this.isComplete,
    required this.progress,
  });
  
  @override
  String toString() => 
      'ObjectiveResult(${objective.id}: ${(progress * 100).toStringAsFixed(1)}%, complete: $isComplete)';
}
