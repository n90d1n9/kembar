import '../../domain/twin/twin_state.dart';
import '../../domain/spatial/spatial_component.dart';
import 'spatial_world.dart';

/// Builder that creates a SpatialWorld from TwinState.
/// 
/// This is the critical connection between the twin state (source of truth)
/// and the spatial world (derived query representation).
class SpatialWorldBuilder {
  const SpatialWorldBuilder();

  /// Build a SpatialWorld from the current TwinState.
  /// 
  /// Only entities with SpatialComponents are included in the spatial world.
  SpatialWorld build(TwinState state) {
    final components = <String, SpatialComponent>{};

    for (final entity in state.entities.values) {
      final spatial = entity.component<SpatialComponent>();

      if (spatial == null) {
        continue;
      }

      components[entity.id] = spatial;
    }

    return SpatialWorld(components: components);
  }

  /// Build a SpatialWorld filtered by entity type.
  SpatialWorld buildByType(TwinState state, String entityType) {
    final components = <String, SpatialComponent>{};

    for (final entity in state.entities.values) {
      if (entity.type != entityType) {
        continue;
      }

      final spatial = entity.component<SpatialComponent>();

      if (spatial == null) {
        continue;
      }

      components[entity.id] = spatial;
    }

    return SpatialWorld(components: components);
  }

  /// Build a SpatialWorld with only entities that have specific component types.
  SpatialWorld buildWithComponents<T>(TwinState state) {
    final components = <String, SpatialComponent>{};

    for (final entity in state.entities.values) {
      if (!entity.hasComponent<T>()) {
        continue;
      }

      final spatial = entity.component<SpatialComponent>();

      if (spatial == null) {
        continue;
      }

      components[entity.id] = spatial;
    }

    return SpatialWorld(components: components);
  }
}
