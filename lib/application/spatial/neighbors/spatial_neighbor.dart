import 'package:vector_math/vector_math_64.dart';

/// Direction to a neighboring entity in 3D space.
enum NeighborDirection {
  left,
  right,
  front,
  back,
  above,
  below,
  overlapping,
  nearby,
}

/// Represents a spatial relationship between two entities.
class SpatialNeighbor {
  /// ID of the neighboring entity.
  final String entityId;

  /// Direction from the subject to this neighbor.
  final NeighborDirection direction;

  /// Distance between the entities (bounds-to-bounds).
  final double distance;

  /// Offset vector from subject to neighbor.
  final Vector3 offset;

  const SpatialNeighbor({
    required this.entityId,
    required this.direction,
    required this.distance,
    required this.offset,
  });

  @override
  String toString() {
    return 'SpatialNeighbor(entityId: $entityId, direction: $direction, distance: ${distance.toStringAsFixed(3)})';
  }
}
