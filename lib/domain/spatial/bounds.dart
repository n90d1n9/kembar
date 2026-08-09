import 'vector3.dart';

/// Axis-aligned bounding box for spatial calculations.
class Bounds {
  final Vector3 min;
  final Vector3 max;

  const Bounds({
    required this.min,
    required this.max,
  });

  Vector3 get size => max - min;

  Vector3 get center => (min + max) * 0.5;

  double get width => max.x - min.x;

  double get height => max.y - min.y;

  double get depth => max.z - min.z;

  double get volume => width * height * depth;

  bool contains(Vector3 point) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y &&
        point.z >= min.z &&
        point.z <= max.z;
  }

  /// Check if this bounds intersects with another.
  /// 
  /// Uses strict inequality (< and >) so that touching boxes are NOT
  /// considered intersecting. This is important because touching is valid
  /// support (e.g., cargo sitting on a shelf).
  bool intersects(Bounds other) {
    return min.x < other.max.x &&
        max.x > other.min.x &&
        min.y < other.max.y &&
        max.y > other.min.y &&
        min.z < other.max.z &&
        max.z > other.min.z;
  }

  Bounds translated(Vector3 offset) {
    return Bounds(
      min: min + offset,
      max: max + offset,
    );
  }

  Bounds expanded(double amount) {
    final expansion = Vector3.all(amount);
    return Bounds(
      min: min - expansion,
      max: max + expansion,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Bounds && other.min == min && other.max == max;
  }

  @override
  int get hashCode => Object.hash(min, max);
}
