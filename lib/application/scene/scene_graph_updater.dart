import 'scene_change.dart';
import 'scene_graph.dart';

/// Applies [SceneChange] events to a [SceneGraph] to produce an updated graph.
///
/// This enables incremental scene updates instead of full rebuilds,
/// which is critical for performance with large numbers of entities.
class SceneGraphUpdater {
  const SceneGraphUpdater();

  /// Apply a single change to the graph.
  SceneGraph apply(SceneGraph graph, SceneChange change) {
    switch (change) {
      case SceneNodeCreated():
        return _applyCreation(graph, change.node);
      case SceneNodeUpdated():
        return _applyUpdate(graph, change.node);
      case SceneNodeRemoved():
        return _applyRemoval(graph, change.id);
      case SceneChangeBatch():
        return _applyBatch(graph, change.changes);
    }
  }

  SceneGraph _applyCreation(SceneGraph graph, SceneNode node) {
    final nodes = Map<String, SceneNode>.of(graph.nodes);
    nodes[node.id] = node;
    return SceneGraph(nodes: Map.unmodifiable(nodes));
  }

  SceneGraph _applyUpdate(SceneGraph graph, SceneNode node) {
    if (!graph.hasNode(node.id)) {
      // If node doesn't exist, treat as creation
      return _applyCreation(graph, node);
    }

    final nodes = Map<String, SceneNode>.of(graph.nodes);
    nodes[node.id] = node;
    return SceneGraph(nodes: Map.unmodifiable(nodes));
  }

  SceneGraph _applyRemoval(SceneGraph graph, String id) {
    if (!graph.hasNode(id)) {
      return graph; // Nothing to remove
    }

    final nodes = Map<String, SceneNode>.of(graph.nodes);
    nodes.remove(id);
    return SceneGraph(nodes: Map.unmodifiable(nodes));
  }

  SceneGraph _applyBatch(SceneGraph graph, List<SceneChange> changes) {
    var result = graph;
    for (final change in changes) {
      result = apply(result, change);
    }
    return result;
  }

  /// Compute the difference between two graphs and return the changes needed
  /// to transform [oldGraph] into [newGraph].
  List<SceneChange> diff(SceneGraph oldGraph, SceneGraph newGraph) {
    final changes = <SceneChange>[];

    // Find removed nodes
    for (final id in oldGraph.nodeIds) {
      if (!newGraph.hasNode(id)) {
        changes.add(SceneNodeRemoved(id));
      }
    }

    // Find created or updated nodes
    for (final id in newGraph.nodeIds) {
      final newNode = newGraph.node(id)!;
      final oldNode = oldGraph.node(id);

      if (oldNode == null) {
        changes.add(SceneNodeCreated(newNode));
      } else if (oldNode != newNode) {
        changes.add(SceneNodeUpdated(newNode));
      }
    }

    return changes;
  }
}
