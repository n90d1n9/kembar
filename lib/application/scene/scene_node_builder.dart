import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';

/// Abstract builder for converting a [TwinEntity] into a [SceneNode].
///
/// Each domain (containers, cranes, trucks, parking spots, etc.) can
/// implement its own builder, enabling platform-agnostic scene generation.
abstract class SceneNodeBuilder {
  const SceneNodeBuilder();

  /// Check if this builder supports the given entity type.
  bool supports(TwinEntity entity);

  /// Build a [SceneNode] from a [TwinEntity].
  SceneNode build(TwinEntity entity);
}
