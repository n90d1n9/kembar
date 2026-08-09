import '../../domain/spatial/placement_request.dart';
import '../placement_candidate.dart';
import '../spatial_world.dart';

/// Result of evaluating a placement constraint.
class PlacementConstraintResult {
  final bool satisfied;
  final String reason;

  const PlacementConstraintResult({
    required this.satisfied,
    required this.reason,
  });

  /// Convenience constructor for satisfied results.
  factory PlacementConstraintResult.satisfied(String reason) {
    return PlacementConstraintResult(
      satisfied: true,
      reason: reason,
    );
  }

  /// Convenience constructor for failed results.
  factory PlacementConstraintResult.failed(String reason) {
    return PlacementConstraintResult(
      satisfied: false,
      reason: reason,
    );
  }
}

/// Abstract interface for placement constraints.
/// 
/// Constraints are pluggable rules that determine if a placement candidate is valid.
/// This allows the placement engine to be domain-agnostic and extensible.
abstract interface class PlacementConstraint {
  /// Whether this constraint is hard (must be satisfied) or soft (preference).
  /// Hard constraints cause rejection; soft constraints reduce score.
  bool get isHard => true;

  /// Evaluate the constraint for a given placement candidate.
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
