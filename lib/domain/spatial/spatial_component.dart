import 'package:vector_math/vector_math_64.dart';

import 'bounds.dart';
import 'collision_shape.dart';
import 'placement_surface.dart';
import 'spatial_anchor.dart';

/// Component that provides spatial information to any twin entity.
/// 
/// This is the domain-level spatial representation that can be attached
/// to any entity regardless of its domain (port, parking, restaurant, warehouse, etc.).
class SpatialComponent {
  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;
  final CollisionShape collisionShape;
  final Bounds localBounds;
  final List<PlacementSurface> surfaces;
  final List<SpatialAnchor> anchors;
  final String? parentId;

  const SpatialComponent({
    required this.position,
    required this.collisionShape,
    required this.localBounds,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
    this.surfaces = const [],
    this.anchors = const [],
    this.parentId,
  });

  /// Returns the world-space bounding box.
  Bounds get worldBounds {
    return collisionShape.boundsAt(position);
  }

  SpatialComponent copyWith({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    CollisionShape? collisionShape,
    Bounds? localBounds,
    List<PlacementSurface>? surfaces,
    List<SpatialAnchor>? anchors,
    String? parentId,
  }) {
    return SpatialComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      collisionShape: collisionShape ?? this.collisionShape,
      localBounds: localBounds ?? this.localBounds,
      surfaces: surfaces ?? this.surfaces,
      anchors: anchors ?? this.anchors,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! SpatialComponent) return false;
    return other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.collisionShape == collisionShape &&
        other.localBounds == localBounds &&
        other.parentId == parentId;
  }

  @override
  int get hashCode => Object.hash(
        position,
        rotation,
        scale,
        collisionShape,
        localBounds,
        parentId,
      );
}
