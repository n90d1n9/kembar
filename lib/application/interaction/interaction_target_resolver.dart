import '../../domain/interaction/interaction_target.dart';
import '../../domain/scene/scene_graph.dart';

class InteractionTargetResolver {
  final SceneGraph scene;

  const InteractionTargetResolver({
    required this.scene,
  });

  InteractionTarget? resolve(String nodeId) {
    final node = scene.node(nodeId);

    if (node == null) {
      return null;
    }

    return InteractionTarget(
      entityId: node.id,
      nodeId: node.id,
    );
  }
}
