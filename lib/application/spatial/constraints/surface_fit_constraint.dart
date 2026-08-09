import '../../../domain/spatial/bounds.dart';
import '../../../domain/spatial/placement_surface.dart';
import '../../../domain/spatial/spatial_component.dart';
import '../../spatial_world.dart';
import '../placement_candidate.dart';
import 'placement_constraint.dart';

/// Constraint that checks if an object fits on a placement surface.
class SurfaceFitConstraint implements PlacementConstraint {
  const SurfaceFitConstraint();

  @override
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.component(request.subjectId);

    if (subject == null) {
      return PlacementConstraintResult.failed('Subject not found');
    }

    if (candidate.surfaceId == null) {
      return PlacementConstraintResult.failed('No surface selected');
    }

    final surface = _findSurface(candidate.surfaceId!, world);

    if (surface == null) {
      return PlacementConstraintResult.failed('Surface not found');
    }

    final bounds = subject.collisionShape.boundsAt(candidate.position);

    // Check if the object fits within the surface bounds in X and Z dimensions
    final fits = bounds.min.x >= surface.bounds.min.x &&
        bounds.max.x <= surface.bounds.max.x &&
        bounds.min.z >= surface.bounds.min.z &&
        bounds.max.z <= surface.bounds.max.z;

    return PlacementConstraintResult(
      satisfied: fits,
      reason: fits ? 'Fits surface' : 'Does not fit surface',
    );
  }

  PlacementSurface? _findSurface(String id, SpatialWorld world) {
    for (final component in world.components.values) {
      for (final surface in component.surfaces) {
        if (surface.id == id) {
          return surface;
        }
      }
    }

    return null;
  }
}
