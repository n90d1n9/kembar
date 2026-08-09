import 'vector3.dart';

/// Spatial model describing an entity's physical characteristics.
class SpatialModel {
  final Vector3 position;
  final Vector3 rotation;
  final CollisionShape collisionShape;
  final Bounds localBounds;
  final String? parentId;

  const SpatialModel({
    required this.position,
    required this.collisionShape,
    required this.localBounds,
    this.rotation = const Vector3(0, 0, 0),
    this.parentId,
  });

  /// Returns the world-space bounding box.
  Bounds get worldBounds {
    return collisionShape.boundsAt(position);
  }

  SpatialModel copyWith({
    Vector3? position,
    Vector3? rotation,
    CollisionShape? collisionShape,
    Bounds? localBounds,
    String? parentId,
  }) {
    return SpatialModel(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      collisionShape: collisionShape ?? this.collisionShape,
      localBounds: localBounds ?? this.localBounds,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SpatialModel &&
        other.position == position &&
        other.rotation == rotation &&
        other.collisionShape == collisionShape &&
        other.localBounds == localBounds &&
        other.parentId == parentId;
  }

  @override
  int get hashCode => Object.hash(position, rotation, collisionShape, localBounds, parentId);
}
