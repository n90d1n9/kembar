import 'bounds.dart';

/// Type of placement surface.
enum PlacementSurfaceType {
  horizontal,
  vertical,
  freeform,
}

/// A surface on which objects can be placed.
class PlacementSurface {
  final String id;
  final String hostEntityId;
  final PlacementSurfaceType type;
  final Bounds bounds;
  final double height;

  const PlacementSurface({
    required this.id,
    required this.hostEntityId,
    required this.type,
    required this.bounds,
    required this.height,
  });

  @override
  bool operator ==(Object other) {
    return other is PlacementSurface &&
        other.id == id &&
        other.hostEntityId == hostEntityId &&
        other.type == type &&
        other.bounds == bounds &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(id, hostEntityId, type, bounds, height);
}
