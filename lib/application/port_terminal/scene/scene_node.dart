import '../../../domain/core/spatial_component.dart';
import '../../../domain/core/vector3.dart';

class SceneNode {
  final String id;
  final String entityId;

  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  final String? modelId;

  const SceneNode({
    required this.id,
    required this.entityId,
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
    this.modelId,
  });

  SceneNode copyWith({
    String? id,
    String? entityId,
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    String? modelId,
  }) {
    return SceneNode(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      modelId: modelId ?? this.modelId,
    );
  }
}
