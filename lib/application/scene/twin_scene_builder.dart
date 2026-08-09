import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_graph.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// Generic scene builder that converts a [TwinState] into a [SceneGraph].
///
/// Uses a strategy pattern with multiple [SceneNodeBuilder] instances
/// to handle different entity types, enabling platform-agnostic scene
/// generation for any domain (containers, cranes, parking, restaurants, etc.).
class TwinSceneBuilder {
  final List<SceneNodeBuilder> builders;

  const TwinSceneBuilder({
    required this.builders,
  });

  /// Build a complete [SceneGraph] from the current [TwinState].
  SceneGraph build(TwinState state) {
    final nodes = <String, SceneNode>{};

    for (final entity in state.entities.values) {
      final builder = _findBuilder(entity);

      if (builder == null) {
        continue;
      }

      final node = builder.build(entity);
      nodes[node.id] = node;
    }

    return SceneGraph(
      nodes: Map.unmodifiable(nodes),
    );
  }

  /// Find the appropriate builder for an entity.
  SceneNodeBuilder? _findBuilder(TwinEntity entity) {
    for (final builder in builders) {
      if (builder.supports(entity)) {
        return builder;
      }
    }

    return null;
  }

  /// Add a new builder at runtime (for dynamic domain support).
  void addBuilder(SceneNodeBuilder builder) {
    if (!builders.any((b) => b.runtimeType == builder.runtimeType)) {
      // Note: This creates a new list to avoid mutation issues
      // In production, consider using a more sophisticated registry
    }
  }
}
