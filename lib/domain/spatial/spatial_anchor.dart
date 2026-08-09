import 'vector3.dart';

/// Type of spatial anchor.
enum SpatialAnchorType {
  placement,
  storage,
  seat,
  workstation,
  entrance,
  exit,
  connection,
}

/// A named logical location on/in an entity.
class SpatialAnchor {
  final String id;
  final String hostEntityId;
  final Vector3 localPosition;
  final Vector3 rotation;
  final SpatialAnchorType type;

  const SpatialAnchor({
    required this.id,
    required this.hostEntityId,
    required this.localPosition,
    required this.type,
    this.rotation = const Vector3(0, 0, 0),
  });

  /// Returns the world position given the host entity's position.
  Vector3 worldPosition(Vector3 hostPosition) {
    return hostPosition + localPosition;
  }

  @override
  bool operator ==(Object other) {
    return other is SpatialAnchor &&
        other.id == id &&
        other.hostEntityId == hostEntityId &&
        other.localPosition == localPosition &&
        other.rotation == rotation &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, hostEntityId, localPosition, rotation, type);
}
