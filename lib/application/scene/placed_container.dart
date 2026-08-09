import '../../domain/entities/container_status.dart';
import '../../domain/value_objects/position3d.dart';

/// Render-agnostic description of one container's placement — the output
/// of [ContainerSceneBuilder] and the input to whatever rendering adapter
/// is plugged in. Contains no lite_3d_core / Flutter types, so scene
/// composition stays unit-testable without a rendering engine.
class PlacedContainer {
  final String id;
  final String label;

  /// Bottom-center of the container footprint, matching the convention
  /// used by the cuboid mesh builder (box sits on the ground plane).
  final Position3D baseCenter;

  final double lengthM;
  final double widthM;
  final double heightM;
  final double rotationYDeg;
  final ContainerStatus status;

  const PlacedContainer({
    required this.id,
    required this.label,
    required this.baseCenter,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    this.rotationYDeg = 0,
    required this.status,
  });
}
