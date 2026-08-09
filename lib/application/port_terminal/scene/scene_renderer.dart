import 'scene.dart';

abstract class SceneRenderer {
  const SceneRenderer();

  Future<void> render(Scene scene);
}
