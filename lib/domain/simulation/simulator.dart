import '../../domain/core/twin_state.dart';
import 'simulation_parameters.dart';
import 'simulation_scenario.dart';

/// Abstract interface for simulation engines
/// 
/// The platform supports multiple simulation paradigms:
/// - Discrete Event Simulation (DES)
/// - Agent-Based Simulation
/// - Continuous/Physics Simulation
/// - State Machine Simulation
/// - Monte Carlo Simulation
abstract class TwinSimulator {
  /// Run a simulation with the given parameters
  Future<SimulationResult> run({
    required TwinState initialState,
    required SimulationParameters parameters,
  });

  /// Run a specific scenario
  Future<SimulationResult> runScenario({
    required TwinState initialState,
    required SimulationScenario scenario,
    required SimulationParameters parameters,
  });

  /// Validate if this simulator can handle the given state/scenario
  bool canSimulate(TwinState state, SimulationScenario? scenario);
}

/// Result of validating simulation capability
class SimulationCapability {
  final bool supported;
  final String simulatorType;
  final List<String> limitations;

  const SimulationCapability({
    required this.supported,
    required this.simulatorType,
    this.limitations = const [],
  });
}
