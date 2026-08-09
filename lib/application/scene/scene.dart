import 'scene_node.dart';

class Scene {
  final List<SceneNode> nodes;

  const Scene({
    this.nodes = const [],
  });

  Scene copyWith({
    List<SceneNode>? nodes,
  }) {
    return Scene(
      nodes: nodes ?? this.nodes,
    );
  }
}
