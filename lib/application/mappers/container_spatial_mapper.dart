import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';

/// Maps ContainerTwin to 3D spatial positions.
/// 
/// This is a simplified mapper that converts container slot information
/// into Vector3 positions for the generic TwinEntity spatial component.
class ContainerSpatialMapper {
  const ContainerSpatialMapper();

  /// Map a container to its 3D position.
  /// 
  /// Uses the container's slot information to calculate position.
  Vector3 map(ContainerTwin container) {
    // Simple mapping: bay * 20m, row * 2.5m, tier * 2.9m
    // These are approximate real-world container dimensions
    const double baySpacing = 20.0; // meters between bays
    const double rowSpacing = 2.5; // meters between rows (container width + gap)
    const double tierHeight = 2.9; // meters per tier (container height + gap)

    return Vector3(
      container.slot.bay * baySpacing,
      container.slot.row * rowSpacing,
      container.slot.tier * tierHeight,
    );
  }
}
