import 'package:vector_math/vector_math_64.dart';

import '../../domain/spatial/bounds.dart';
import '../spatial_world.dart';
import 'spatial_neighbor.dart';

/// Analyzes spatial relationships between entities to find neighbors.
class NeighborAnalyzer {
  /// Maximum distance to consider an entity as a neighbor.
  final double nearbyDistance;

  const NeighborAnalyzer({
    this.nearbyDistance = 2.0,
  });

  /// Find all neighbors of the given entity within the specified distance.
  List<SpatialNeighbor> findNeighbors(
    String entityId,
    SpatialWorld world,
  ) {
    final subject = world.component(entityId);

    if (subject == null) {
      return const [];
    }

    final result = <SpatialNeighbor>[];

    for (final entry in world.components.entries) {
      if (entry.key == entityId) {
        continue;
      }

      final other = entry.value;

      // Calculate bounds-to-bounds distance (more accurate than center-to-center)
      final distance = _distanceBetweenBounds(
        subject.worldBounds,
        other.worldBounds,
      );

      if (distance > nearbyDistance) {
        continue;
      }

      final offset = other.position - subject.position;

      result.add(
        SpatialNeighbor(
          entityId: entry.key,
          direction: _direction(offset),
          distance: distance,
          offset: offset,
        ),
      );
    }

    // Sort by distance (closest first)
    result.sort((a, b) => a.distance.compareTo(b.distance));

    return result;
  }

  /// Calculate the distance between two bounding boxes.
  /// Returns 0 if they intersect or touch.
  double _distanceBetweenBounds(Bounds a, Bounds b) {
    final dx = _axisDistance(a.min.x, a.max.x, b.min.x, b.max.x);
    final dy = _axisDistance(a.min.y, a.max.y, b.min.y, b.max.y);
    final dz = _axisDistance(a.min.z, a.max.z, b.min.z, b.max.z);

    return Vector3(dx, dy, dz).length;
  }

  /// Calculate distance along a single axis.
  double _axisDistance(double minA, double maxA, double minB, double maxB) {
    if (maxA < minB) {
      return minB - maxA;
    }

    if (maxB < minA) {
      return minA - maxB;
    }

    // Overlapping on this axis
    return 0;
  }

  /// Determine the primary direction from the offset vector.
  NeighborDirection _direction(Vector3 offset) {
    final absX = offset.x.abs();
    final absY = offset.y.abs();
    final absZ = offset.z.abs();

    // Check vertical first (above/below)
    if (absY > absX && absY > absZ) {
      return offset.y > 0
          ? NeighborDirection.above
          : NeighborDirection.below;
    }

    // Then horizontal (left/right vs front/back)
    if (absX > absZ) {
      return offset.x > 0
          ? NeighborDirection.right
          : NeighborDirection.left;
    }

    if (absZ > 0) {
      return offset.z > 0
          ? NeighborDirection.front
          : NeighborDirection.back;
    }

    return NeighborDirection.overlapping;
  }

  /// Find neighbors that match specific directions.
  List<SpatialNeighbor> findNeighborsInDirection(
    String entityId,
    SpatialWorld world,
    List<NeighborDirection> directions,
  ) {
    final allNeighbors = findNeighbors(entityId, world);
    return allNeighbors
        .where((n) => directions.contains(n.direction))
        .toList();
  }

  /// Find the closest neighbor in a specific direction.
  SpatialNeighbor? findClosestNeighborInDirection(
    String entityId,
    SpatialWorld world,
    NeighborDirection direction,
  ) {
    final neighbors = findNeighborsInDirection(
      entityId,
      world,
      [direction],
    );

    if (neighbors.isEmpty) {
      return null;
    }

    return neighbors.first;
  }
}
