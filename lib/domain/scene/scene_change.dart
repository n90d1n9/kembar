import 'scene_node.dart';

/// Represents a change in the scene graph for efficient incremental updates.
///
/// Instead of rebuilding the entire scene when one entity changes,
/// the system can emit [SceneChange] events that describe exactly
/// what changed, enabling optimized renderer updates.
sealed class SceneChange {
  const SceneChange();
}

/// A new scene node has been created.
class SceneNodeCreated extends SceneChange {
  final SceneNode node;

  const SceneNodeCreated(this.node);

  @override
  String toString() => 'SceneNodeCreated(${node.id})';
}

/// An existing scene node has been updated (position, visibility, etc.).
class SceneNodeUpdated extends SceneChange {
  final SceneNode node;

  const SceneNodeUpdated(this.node);

  @override
  String toString() => 'SceneNodeUpdated(${node.id})';
}

/// A scene node has been removed.
class SceneNodeRemoved extends SceneChange {
  final String id;

  const SceneNodeRemoved(this.id);

  @override
  String toString() => 'SceneNodeRemoved($id)';
}

/// Batch multiple changes together for efficient processing.
class SceneChangeBatch extends SceneChange {
  final List<SceneChange> changes;

  const SceneChangeBatch(this.changes);

  @override
  String toString() => 'SceneChangeBatch(${changes.length} changes)';
}
