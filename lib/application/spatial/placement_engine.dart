import 'package:vector_math/vector_math_64.dart';

import '../../domain/spatial/bounds.dart';
import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/placement_result.dart';
import '../../domain/spatial/spatial_relation.dart';
import 'collision_detector.dart';
import 'placement_candidate.dart';
import 'spatial_world.dart';
import 'surface_placement_strategy.dart';
import 'constraints/placement_constraint.dart';

/// Engine that finds valid placements for entities using a constraint-based approach.
/// 
/// The PlacementEngine is domain-agnostic - it knows nothing about warehouses,
/// restaurants, ports, or any specific domain. It only understands:
/// - SpatialComponents
/// - PlacementRequests
/// - PlacementConstraints
/// 
/// This makes it a true platform-level abstraction.
class PlacementEngine {
  final List<PlacementConstraint> constraints;
  final SurfacePlacementStrategy surfaceStrategy;

  const PlacementEngine({
    required this.constraints,
    required this.surfaceStrategy,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final candidates = _generateCandidates(request, world);

    if (candidates.isEmpty) {
      return const PlacementResult.invalid('No placement candidates');
    }

    PlacementResult? best;

    for (final candidate in candidates) {
      // Evaluate all constraints
      final results = constraints.map(
        (constraint) => constraint.evaluate(candidate, request, world),
      );

      final failures = results.where((result) => !result.satisfied).toList();

      // Skip if any hard constraint failed
      if (failures.isNotEmpty) {
        continue;
      }

      // Score the candidate
      final score = _scoreCandidate(candidate, request);

      final result = PlacementResult(
        valid: true,
        position: candidate.position,
        rotation: candidate.rotation,
        surfaceId: candidate.surfaceId,
        anchorId: candidate.anchorId,
        score: score,
        reasons: results.map((r) => r.reason).toList(),
      );

      if (best == null || result.score > best.score) {
        best = result;
      }
    }

    if (best == null) {
      return const PlacementResult.invalid('No valid placement found');
    }

    return best;
  }

  List<PlacementCandidate> _generateCandidates(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    switch (request.relation) {
      case SpatialRelationType.on:
      case SpatialRelationType.supports:
        return surfaceStrategy.generate(request, world);

      // TODO: Add more strategies for other relations
      default:
        return const [];
    }
  }

  double _scoreCandidate(
    PlacementCandidate candidate,
    PlacementRequest request,
  ) {
    final preferred = request.preferredPosition;

    if (preferred == null) {
      return 1.0;
    }

    final distance = candidate.position.distanceTo(preferred);
    return 1.0 / (1.0 + distance);
  }
}
