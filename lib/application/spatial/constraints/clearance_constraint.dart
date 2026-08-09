import '../../../domain/spatial/bounds.dart';
import '../../../domain/spatial/collision_shape.dart';
import '../../../domain/spatial/spatial_component.dart';
import '../../spatial_world.dart';
import '../placement_candidate.dart';
import 'placement_constraint.dart';
import '../../../application/spatial/collision_detector.dart';

/// Constraint that checks for clearance violations with other entities.
/// 
/// Unlike collision, clearance allows for a safety margin around objects.
class ClearanceConstraint implements PlacementConstraint {
  final CollisionDetector detector;

  const ClearanceConstraint(this.detector);

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

    final candidateBounds = subject.collisionShape.boundsAt(candidate.position);

    for (final entry in world.components.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final otherComponent = entry.value;
      final otherBounds = otherComponent.worldBounds;

      if (detector.violatesClearance(
        candidateBounds,
        otherBounds,
        request.clearance,
      )) {
        return PlacementConstraintResult.failed(
          'Clearance violated with ${entry.key}',
        );
      }
    }

    return PlacementConstraintResult.satisfied('Clearance satisfied');
  }
}
