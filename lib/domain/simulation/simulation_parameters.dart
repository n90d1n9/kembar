import '../../domain/core/twin_state.dart';

/// Parameters for configuring a simulation run
class SimulationParameters {
  final Duration duration;
  final Duration timeStep;
  final double speed;
  final int? randomSeed;
  final Map<String, Object?> custom;

  const SimulationParameters({
    required this.duration,
    this.timeStep = const Duration(seconds: 1),
    this.speed = 1.0,
    this.randomSeed,
    this.custom = const {},
  });
}

/// An action that occurs during simulation
abstract class SimulationAction {
  final String id;
  final String description;

  const SimulationAction({
    required this.id,
    required this.description,
  });

  SimulationActionResult apply(TwinState state);
}

class SimulationActionResult {
  final bool success;
  final TwinState newState;
  final List<String> messages;

  const SimulationActionResult({
    required this.success,
    required this.newState,
    this.messages = const [],
  });
}

/// Result of a complete simulation run
class SimulationResult {
  final bool success;
  final TwinState initialState;
  final TwinState finalState;
  final List<TwinState> history;
  final List<SimulationEvent> events;
  final Duration simulatedDuration;
  final DateTime completedAt;
  final String? error;

  const SimulationResult({
    required this.success,
    required this.initialState,
    required this.finalState,
    this.history = const [],
    this.events = const [],
    required this.simulatedDuration,
    required this.completedAt,
    this.error,
  });
}

/// Events that occur during simulation
class SimulationEvent {
  final String type;
  final DateTime timestamp;
  final Duration simulationTime;
  final Map<String, Object?> data;

  const SimulationEvent({
    required this.type,
    required this.timestamp,
    required this.simulationTime,
    this.data = const {},
  });
}
