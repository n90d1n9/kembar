import '../../domain/spatial/bounds.dart';

/// Detects collisions between bounding boxes.
class CollisionDetector {
  const CollisionDetector();

  bool intersects(Bounds a, Bounds b, {double clearance = 0}) {
    return a.expanded(clearance).intersects(b);
  }
}
