import '../../../domain/spatial/spatial_relation.dart';
import '../constraints/placement_constraint.dart';
import '../constraints/collision_constraint.dart';
import '../constraints/clearance_constraint.dart';
import '../constraints/surface_fit_constraint.dart';
import '../constraints/support_constraint.dart';

/// Resolves appropriate constraints based on spatial relation type.
class RelationConstraintResolver {
  const RelationConstraintResolver();

  /// Get the list of constraints appropriate for a given relation type.
  List<PlacementConstraint> resolve(SpatialRelationType relation) {
    switch (relation) {
      case SpatialRelationType.on:
      case SpatialRelationType.stackedOn:
        return [
          const SurfaceFitConstraint(),
          const SupportConstraint(),
          const CollisionConstraint(),
        ];

      case SpatialRelationType.inside:
      case SpatialRelationType.contains:
        return [
          // ContainmentConstraint() - to be implemented
          const CollisionConstraint(),
        ];

      case SpatialRelationType.adjacentTo:
      case SpatialRelationType.near:
        return [
          const CollisionConstraint(),
          const ClearanceConstraint(clearance: 0.5),
        ];

      case SpatialRelationType.attachedTo:
      case SpatialRelationType.connectedTo:
        return [
          // AttachmentConstraint() - to be implemented
          const CollisionConstraint(),
        ];

      case SpatialRelationType.above:
      case SpatialRelationType.below:
        return [
          const CollisionConstraint(),
          const ClearanceConstraint(clearance: 0.1),
        ];

      case SpatialRelationType.leftOf:
      case SpatialRelationType.rightOf:
      case SpatialRelationType.inFrontOf:
      case SpatialRelationType.behind:
        return [
          const CollisionConstraint(),
          const ClearanceConstraint(clearance: 0.3),
        ];

      case SpatialRelationType.alignedWith:
        return [
          const CollisionConstraint(),
        ];

      case SpatialRelationType.supports:
        return [
          const SupportConstraint(),
          const CollisionConstraint(),
        ];

      case SpatialRelationType.overlaps:
      case SpatialRelationType.intersects:
        // These relations allow overlap, so no collision constraint
        return [];

      case SpatialRelationType.far:
        return [
          // DistanceConstraint() - to be implemented
        ];
    }
  }

  /// Get constraints for a relation, optionally adding generic constraints.
  List<PlacementConstraint> resolveWithGenerics(
    SpatialRelationType relation, {
    List<PlacementConstraint>? additionalConstraints,
  }) {
    final relationConstraints = resolve(relation);
    
    if (additionalConstraints == null || additionalConstraints.isEmpty) {
      return relationConstraints;
    }

    return [...relationConstraints, ...additionalConstraints];
  }
}
