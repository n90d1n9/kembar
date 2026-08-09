import '../../domain/scene/scene_graph.dart';

/// Abstract renderer interface for converting a [SceneGraph] into
/// renderer-specific output.
///
/// The type parameter [T] represents the renderer's output type:
/// - Canvas: List<Widget> or CustomPainter instructions
/// - 3D: Scene object for three.dart or similar
/// - WebGL: JavaScript interop commands
/// - GLB: Binary glTF data
///
/// This abstraction enables the same SceneGraph to be rendered by
/// multiple backends without modification.
abstract class SceneRenderer<T> {
  const SceneRenderer();

  /// Render a [SceneGraph] into the renderer-specific output type.
  T render(SceneGraph scene);

  /// Optional: Update only changed nodes for performance.
  void update(SceneGraph scene) {
    // Default implementation does full re-render
    // Subclasses can override for incremental updates
  }

  /// Dispose of resources when the renderer is no longer needed.
  void dispose() {
    // Default implementation does nothing
    // Subclasses should override to clean up resources
  }
}
