import 'vector3.dart';

/// Source of a placement candidate - useful for debugging and scoring.
enum CandidateSource {
  preferred,
  grid,
  center,
  edge,
  corner,
  anchor,
  neighbor,
}

/// A candidate position for placement.
class PlacementCandidate {
  final Vector3 position;
  final Vector3 rotation;
  final String? surfaceId;
  final String? anchorId;
  final CandidateSource source;

  const PlacementCandidate({
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.surfaceId,
    this.anchorId,
    this.source = CandidateSource.preferred,
  });

  @override
  bool operator ==(Object other) {
    return other is PlacementCandidate &&
        other.position == position &&
        other.rotation == rotation &&
        other.surfaceId == surfaceId &&
        other.anchorId == anchorId &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(position, rotation, surfaceId, anchorId, source);
}
