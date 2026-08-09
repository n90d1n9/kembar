import 'simulation_parameters.dart';

/// A scenario defines a specific situation or sequence of events to simulate
/// 
/// Scenarios are first-class citizens in the platform, enabling:
/// - What-if analysis
/// - Training and education
/// - Testing operational procedures
/// - Risk assessment
/// 
/// Example:
/// ```yaml
/// scenario:
///   name: Crane Failure
///   description: Simulate a crane breakdown during peak operations
///   
///   initial:
///     crane-04:
///       state: operational
///   
///   events:
///     - at: 10m
///       action:
///         entity: crane-04
///         set:
///           state: failed
///     
///     - at: 12m
///       action:
///         entity: crane-05
///         command: takeOver
/// ```
class SimulationScenario {
  final String id;
  final String name;
  final String? description;
  
  /// Initial state modifications before simulation starts
  final Map<String, dynamic> initialStateModifications;
  
  /// Scheduled events during the simulation
  final List<ScheduledEvent> scheduledEvents;
  
  /// Conditions that trigger additional events
  final List<TriggeredEvent> triggeredEvents;
  
  /// Success criteria for the scenario
  final List<SuccessCriterion> successCriteria;
  
  const SimulationScenario({
    required this.id,
    required this.name,
    this.description,
    this.initialStateModifications = const {},
    this.scheduledEvents = const [],
    this.triggeredEvents = const [],
    this.successCriteria = const [],
  });

  /// Check if all success criteria are met
  bool checkSuccess(SimulationResult result) {
    if (successCriteria.isEmpty) return true;
    
    for (final criterion in successCriteria) {
      if (!criterion.isMet(result)) {
        return false;
      }
    }
    return true;
  }

  SimulationScenario copyWith({
    String? id,
    String? name,
    String? description,
    Map<String, dynamic>? initialStateModifications,
    List<ScheduledEvent>? scheduledEvents,
    List<TriggeredEvent>? triggeredEvents,
    List<SuccessCriterion>? successCriteria,
  }) {
    return SimulationScenario(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      initialStateModifications:
          initialStateModifications ?? this.initialStateModifications,
      scheduledEvents: scheduledEvents ?? this.scheduledEvents,
      triggeredEvents: triggeredEvents ?? this.triggeredEvents,
      successCriteria: successCriteria ?? this.successCriteria,
    );
  }
}

/// An event scheduled to occur at a specific simulation time
class ScheduledEvent {
  final Duration atTime;
  final SimulationAction action;
  final String? condition; // Optional condition to check before executing

  const ScheduledEvent({
    required this.atTime,
    required this.action,
    this.condition,
  });
}

/// An event triggered by a condition being met
class TriggeredEvent {
  final String condition;
  final SimulationAction action;
  final bool once; // If true, only trigger once

  const TriggeredEvent({
    required this.condition,
    required this.action,
    this.once = true,
  });
}

/// Criterion for determining scenario success
class SuccessCriterion {
  final String id;
  final String description;
  final bool Function(SimulationResult result) evaluator;

  const SuccessCriterion({
    required this.id,
    required this.description,
    required this.evaluator,
  });
}
