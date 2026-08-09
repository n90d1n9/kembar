import '../../domain/core/vector3.dart';

import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/placement_result.dart';
import '../../domain/spatial/spatial_relation.dart';
import 'collision_detector.dart';
import 'placement_candidate.dart';
import 'spatial_world.dart';
import 'surface_placement_strategy.dart';

/// Engine that finds valid placements for entities.
class PlacementEngine {
  final CollisionDetector collisionDetector;
  final SurfacePlacementStrategy surfaceStrategy;

  const PlacementEngine({
    required this.collisionDetector,
    required this.surfaceStrategy,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.model(request.subjectId);

    if (subject == null) {
      return const PlacementResult.invalid('Subject does not exist');
    }

    final target = world.model(request.targetId);

    if (target == null) {
      return const PlacementResult.invalid('Target does not exist');
    }

    final candidates = _generateCandidates(request, world);

    if (candidates.isEmpty) {
      return const PlacementResult.invalid('No placement candidates');
    }

    PlacementResult? best;

    for (final candidate in candidates) {
      final result = _evaluateCandidate(candidate, request, world);

      if (!result.valid) {
        continue;
      }

      if (best == null || result.score > best.score) {
        best = result;
      }
    }

    if (best == null) {
      return const PlacementResult.invalid('All candidates invalid');
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

  PlacementResult _evaluateCandidate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.model(request.subjectId);
    final reasons = <String>[];

    if (subject == null) {
      return const PlacementResult.invalid('Subject not found');
    }

    // Check collision with other entities
    final subjectBounds = subject.localBounds as dynamic;
    final candidateBounds = subjectBounds.translated(candidate.position);

    for (final entry in world.models.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final otherModel = entry.value;
      final otherBounds = (otherModel.localBounds as dynamic).translated(otherModel.position as Vector3);

      if (collisionDetector.intersects(
        candidateBounds,
        otherBounds,
        clearance: request.clearance,
      )) {
        reasons.add('Collision with ${entry.key}');
      }
    }

    if (reasons.isNotEmpty) {
      return PlacementResult.invalid(reasons.join('; '));
    }

    // Calculate score based on distance from preferred position
    double score = 1.0;
    if (request.preferredPosition != null) {
      final distance = (candidate.position - request.preferredPosition!).length;
      score = 1.0 / (1.0 + distance);
    }

    return PlacementResult(
      valid: true,
      position: candidate.position,
      rotation: candidate.rotation,
      surfaceId: candidate.surfaceId,
      anchorId: candidate.anchorId,
      score: score,
      reasons: ['Valid placement'],
    );
  }
}
