import '../core/vector3.dart';

/// A generic visual representation of a twin entity in a scene.
///
/// This is the bridge between the domain-agnostic [TwinEntity] and
/// renderer-specific representations. One twin can have multiple
/// SceneNodes for different views (3D, 2D, AR, dashboard, etc.).
class SceneNode {
  final String id;

  /// Generic twin entity type.
  ///
  /// Examples:
  /// - container
  /// - crane
  /// - truck
  /// - robot
  /// - building
  /// - parking_spot
  /// - table (restaurant)
  final String entityType;

  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  /// Optional visual/model identifier.
  ///
  /// Examples:
  /// - container_20ft
  /// - container_40ft
  /// - crane
  /// - truck
  /// - robot_arm
  final String? assetId;

  final bool visible;

  const SceneNode({
    required this.id,
    required this.entityType,
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
    this.assetId,
    this.visible = true,
  });

  SceneNode copyWith({
    String? id,
    String? entityType,
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    String? assetId,
    bool? visible,
  }) {
    return SceneNode(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      assetId: assetId ?? this.assetId,
      visible: visible ?? this.visible,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SceneNode &&
        other.id == id &&
        other.entityType == entityType &&
        other.position == position &&
        other.rotation == rotation &&
        other.scale == scale &&
        other.assetId == assetId &&
        other.visible == visible;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entityType,
        position,
        rotation,
        scale,
        assetId,
        visible,
      );

  @override
  String toString() =>
      'SceneNode(id: $id, type: $entityType, pos: $position, asset: $assetId)';
}
