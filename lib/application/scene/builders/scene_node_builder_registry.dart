import '../../domain/core/twin_core.dart';
import 'scene_node_builder.dart';

/// Registry for managing [SceneNodeBuilder] instances across domains.
///
/// This enables dynamic registration and discovery of builders,
/// supporting the platform-agnostic architecture where new domains
/// can be added without modifying core infrastructure.
///
/// Example usage:
/// ```dart
/// final registry = SceneNodeBuilderRegistry();
/// registry.register(const ContainerSceneNodeBuilder());
/// registry.register(const CraneSceneNodeBuilder());
///
/// // Get all builders for TwinSceneBuilder
/// final sceneBuilder = TwinSceneBuilder(
///   builders: registry.getAllBuilders(),
/// );
/// ```
class SceneNodeBuilderRegistry {
  final Map<String, SceneNodeBuilder> _builders = {};

  const SceneNodeBuilderRegistry._();

  /// Create a new registry with default builders.
  factory SceneNodeBuilderRegistry() {
    final registry = SceneNodeBuilderRegistry._();
    return registry;
  }

  /// Register a builder for a specific entity type.
  void register(SceneNodeBuilder builder) {
    // Use runtime type as key for uniqueness
    final key = builder.runtimeType.toString();
    _builders[key] = builder;
  }

  /// Unregister a builder by its type.
  void unregister<T extends SceneNodeBuilder>() {
    _builders.remove(T.toString());
  }

  /// Get all registered builders.
  List<SceneNodeBuilder> getAllBuilders() {
    return _builders.values.toList(growable: false);
  }

  /// Find a builder that supports a given entity type.
  SceneNodeBuilder? findBuilderForType(String entityType) {
    return _builders.values.firstWhere(
      (builder) => builder.supports(_createMockEntity(entityType)),
      orElse: () => throw UnsupportedError(
        'No builder found for entity type: $entityType',
      ),
    );
  }

  /// Check if a builder exists for a given entity type.
  bool hasBuilderForType(String entityType) {
    return _builders.values.any(
      (builder) => builder.supports(_createMockEntity(entityType)),
    );
  }

  /// Get the number of registered builders.
  int get builderCount => _builders.length;

  /// Clear all registered builders.
  void clear() {
    _builders.clear();
  }

  /// Create a mock entity for type checking.
  static dynamic _createMockEntity(String type) {
    // This is a simplified mock for type checking purposes
    return _MockTwinEntity(type);
  }
}

/// Mock entity for builder type checking.
class _MockTwinEntity {
  final String type;

  const _MockTwinEntity(this.type);
}
