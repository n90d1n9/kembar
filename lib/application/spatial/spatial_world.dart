import '../../domain/spatial/placement_surface.dart';

/// Spatial world containing all spatial models and surfaces.
class SpatialWorld {
  final Map<String, dynamic> models;
  final Map<String, List<PlacementSurface>> surfaces;

  const SpatialWorld({
    this.models = const {},
    this.surfaces = const {},
  });

  dynamic model(String entityId) {
    return models[entityId];
  }

  List<PlacementSurface> surfacesFor(String entityId) {
    return surfaces[entityId] ?? const [];
  }
}
