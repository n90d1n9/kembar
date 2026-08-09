import '../../domain/spatial/spatial_component.dart';
import '../../domain/spatial/placement_surface.dart';

/// Spatial world containing all spatial components and derived surfaces.
/// 
/// This is a derived/query representation of spatial data from TwinState.
/// The SpatialWorld should NOT be modified directly - instead, create commands
/// that update the TwinState, then rebuild the SpatialWorld from the updated state.
class SpatialWorld {
  final Map<String, SpatialComponent> components;

  const SpatialWorld({
    this.components = const {},
  });

  /// Get a spatial component by entity ID.
  SpatialComponent? component(String entityId) {
    return components[entityId];
  }

  /// Get all spatial components.
  List<SpatialComponent> get all => components.values.toList();

  /// Get all surfaces for a specific entity.
  List<PlacementSurface> surfacesFor(String entityId) {
    return component(entityId)?.surfaces ?? const [];
  }

  /// Get all surfaces from all entities.
  List<PlacementSurface> get allSurfaces {
    return components.values
        .expand((component) => component.surfaces)
        .toList();
  }

  /// Check if an entity exists in the spatial world.
  bool hasEntity(String entityId) {
    return components.containsKey(entityId);
  }

  /// Get all entity IDs.
  List<String> get entityIds => components.keys.toList();
}
