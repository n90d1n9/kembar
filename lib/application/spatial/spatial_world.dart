import '../../domain/spatial/spatial_component.dart';
import '../../domain/spatial/placement_surface.dart';
import '../../domain/spatial/relations/spatial_relationship.dart';

/// Spatial world containing all spatial components and derived relationships.
///
/// This is a derived/query representation of spatial data from TwinState.
/// The SpatialWorld should NOT be modified directly - instead, create commands
/// that update the TwinState, then rebuild the SpatialWorld from the updated state.
class SpatialWorld {
  final Map<String, SpatialComponent> components;
  final List<SpatialRelationship> relationships;

  const SpatialWorld({
    this.components = const {},
    this.relationships = const [],
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

  /// Create a copy of this world with updated fields.
  SpatialWorld copyWith({
    Map<String, SpatialComponent>? components,
    List<SpatialRelationship>? relationships,
  }) {
    return SpatialWorld(
      components: components ?? Map.from(this.components),
      relationships: relationships ?? List.from(this.relationships),
    );
  }

  /// Add a relationship to the world.
  SpatialWorld withRelationship(SpatialRelationship relationship) {
    return copyWith(
      relationships: [...relationships, relationship],
    );
  }

  /// Remove a relationship from the world.
  SpatialWorld withoutRelationship(SpatialRelationship relationship) {
    return copyWith(
      relationships: relationships.where((r) => r != relationship).toList(),
    );
  }

  /// Update relationships based on a filter.
  SpatialWorld updateRelationships(
    bool Function(SpatialRelationship) predicate,
    SpatialRelationship Function(SpatialRelationship) updater,
  ) {
    return copyWith(
      relationships: relationships.map((r) {
        if (predicate(r)) {
          return updater(r);
        }
        return r;
      }).toList(),
    );
  }
}
