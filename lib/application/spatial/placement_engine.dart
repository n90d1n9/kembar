import 'package:vector_math/vector_math_64.dart';

import '../../domain/spatial/bounds.dart';
import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/placement_result.dart';
import '../../domain/spatial/spatial_relation.dart';
import 'candidates/candidate_generator.dart';
import 'placement_candidate.dart';
import 'spatial_world.dart';
import 'constraints/placement_constraint.dart';
import 'scoring/placement_scorer.dart';

/// Engine that finds valid placements for entities using a constraint-based approach.
///
/// The PlacementEngine is domain-agnostic - it knows nothing about warehouses,
/// restaurants, ports, or any specific domain. It only understands:
/// - SpatialComponents
/// - PlacementRequests
/// - PlacementConstraints
/// - CandidateGenerators
/// - PlacementScorers
///
/// This makes it a true platform-level abstraction.
///
/// Architecture:
/// ```
/// PlacementRequest
///       │
///       ▼
/// ┌──────────────────┐
/// │ CandidateGenerator│ → Generate 20-50 possible positions
/// └────────┬─────────┘
///          │
///          ▼
/// ┌──────────────────┐
/// │   Constraints    │ → Filter invalid positions
/// └────────┬─────────┘
///          │
///          ▼
/// ┌──────────────────┐
/// │     Scorer       │ → Choose best valid position
/// └────────┬─────────┘
///          │
///          ▼
///    Best Placement
/// ```
class PlacementEngine {
  final CandidateGenerator candidateGenerator;
  final List<PlacementConstraint> constraints;
  final PlacementScorer scorer;

  const PlacementEngine({
    required this.candidateGenerator,
    required this.constraints,
    required this.scorer,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    // Generate all candidate positions
    final candidates = candidateGenerator.generate(request, world);

    if (candidates.isEmpty) {
      return const PlacementResult.invalid('No placement candidates generated');
    }

    PlacementResult? best;

    for (final candidate in candidates) {
      // Evaluate all constraints
      final evaluations = constraints.map(
        (constraint) => constraint.evaluate(candidate, request, world),
      );

      final failures = evaluations.where((result) => !result.satisfied).toList();

      // Skip if any hard constraint failed
      if (failures.isNotEmpty) {
        continue;
      }

      // Score the candidate
      final score = scorer.score(candidate, request, world);

      final result = PlacementResult(
        valid: true,
        position: candidate.position,
        rotation: candidate.rotation,
        surfaceId: candidate.surfaceId,
        anchorId: candidate.anchorId,
        score: score,
        reasons: evaluations.map((r) => r.reason).toList(),
      );

      if (best == null || result.score > best.score) {
        best = result;
      }
    }

    if (best == null) {
      return const PlacementResult.invalid('No valid placement found after constraint evaluation');
    }

    return best;
  }
}
