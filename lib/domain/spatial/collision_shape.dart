import 'bounds.dart';
import 'vector3.dart';

/// Base collision shape for spatial calculations.
abstract class CollisionShape {
  const CollisionShape();

  /// Returns the bounding box of this shape at the given position.
  Bounds boundsAt(Vector3 position);
}

/// Axis-aligned box collision shape.
class BoxCollisionShape extends CollisionShape {
  final Vector3 size;

  const BoxCollisionShape({
    required this.size,
  });

  @override
  Bounds boundsAt(Vector3 position) {
    final half = size * 0.5;
    return Bounds(
      min: position - half,
      max: position + half,
    );
  }
}

/// Sphere collision shape.
class SphereCollisionShape extends CollisionShape {
  final double radius;

  const SphereCollisionShape({
    required this.radius,
  });

  @override
  Bounds boundsAt(Vector3 position) {
    final r = Vector3.all(radius);
    return Bounds(
      min: position - r,
      max: position + r,
    );
  }
}
