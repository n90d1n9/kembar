import '../../domain/spatial/bounds.dart';

/// Detects collisions between spatial bounds.
/// 
/// Separates collision detection from clearance checking to allow
/// different handling of these two distinct concepts.
class CollisionDetector {
  const CollisionDetector();

  /// Check if two bounds intersect (actual overlap, not just touching).
  bool intersects(Bounds a, Bounds b) {
    return a.intersects(b);
  }

  /// Check if two bounds violate a clearance requirement.
  /// 
  /// This expands the first bound by the clearance amount and checks
  /// for intersection with the second bound.
  bool violatesClearance(Bounds a, Bounds b, double clearance) {
    return a.expanded(clearance).intersects(b);
  }
}
