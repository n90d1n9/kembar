import 'vector3.dart';

/// A candidate position for placement.
class PlacementCandidate {
  final Vector3 position;
  final Vector3 rotation;
  final String? surfaceId;
  final String? anchorId;

  const PlacementCandidate({
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.surfaceId,
    this.anchorId,
  });

  @override
  bool operator ==(Object other) {
    return other is PlacementCandidate &&
        other.position == position &&
        other.rotation == rotation &&
        other.surfaceId == surfaceId &&
        other.anchorId == anchorId;
  }

  @override
  int get hashCode => Object.hash(position, rotation, surfaceId, anchorId);
}
