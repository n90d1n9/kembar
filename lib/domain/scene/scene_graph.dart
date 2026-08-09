import 'scene_node.dart';

/// A collection of [SceneNode] objects representing the complete
/// visual state of a digital twin scene.
///
/// The SceneGraph is independent of the rendering technology and
/// can be consumed by Canvas, WebGL, 3D engines, or other renderers.
class SceneGraph {
  final Map<String, SceneNode> nodes;

  const SceneGraph({
    this.nodes = const {},
  });

  /// Get a specific node by ID.
  SceneNode? node(String id) {
    return nodes[id];
  }

  /// Get all visible nodes for rendering.
  List<SceneNode> get visibleNodes {
    return nodes.values.where((node) => node.visible).toList(growable: false);
  }

  /// Get all nodes of a specific entity type.
  List<SceneNode> nodesOfType(String type) {
    return nodes.values
        .where((node) => node.entityType == type)
        .toList(growable: false);
  }

  /// Get all node IDs.
  Iterable<String> get nodeIds => nodes.keys;

  /// Check if a node exists.
  bool hasNode(String id) => nodes.containsKey(id);

  SceneGraph copyWith({
    Map<String, SceneNode>? nodes,
  }) {
    return SceneGraph(
      nodes: nodes ?? this.nodes,
    );
  }

  @override
  String toString() =>
      'SceneGraph(${nodes.length} nodes, ${visibleNodes.length} visible)';
}
