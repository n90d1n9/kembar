import '../../domain/core/twin_state.dart';
import 'scene.dart';
import 'scene_node.dart';

abstract class SceneBuilder {
  const SceneBuilder();

  Scene build(TwinState state);
}
