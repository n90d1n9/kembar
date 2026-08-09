import '../../../domain/spatial/placement_surface.dart';
import '../../../domain/spatial/spatial_component.dart';
import '../../spatial_world.dart';
import '../placement_candidate.dart';
import 'placement_constraint.dart';

/// Constraint that checks if an object is properly supported by a surface.
/// 
/// Support means the object's bottom face is at the same height as the surface.
class SupportConstraint implements PlacementConstraint {
  const SupportConstraint();

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
      return PlacementConstraintResult.failed('No supporting surface');
    }

    final surface = _findSurface(candidate.surfaceId!, world);

    if (surface == null) {
      return PlacementConstraintResult.failed('Surface not found');
    }

    final bounds = subject.collisionShape.boundsAt(candidate.position);

    // Check if the bottom of the object is at the surface height (with tolerance)
    const tolerance = 0.01;
    final supported = (bounds.min.y - surface.height).abs() <= tolerance;

    return PlacementConstraintResult(
      satisfied: supported,
      reason: supported ? 'Supported by surface' : 'Not supported by surface',
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
