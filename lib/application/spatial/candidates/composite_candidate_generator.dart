import '../placement_candidate.dart';
import '../spatial_world.dart';
import '../../../domain/spatial/placement_request.dart';
import 'candidate_generator.dart';

/// Composite candidate generator that combines multiple generators.
///
/// This allows you to compose different generation strategies:
/// - Surface-based generation (for placing on tables, shelves, floors)
/// - Anchor-based generation (for predefined slots/positions)
/// - Grid sampling (for fine-grained placement)
/// - Neighbor-aware generation (for packing objects together)
///
/// The composite generator collects candidates from all generators
/// and deduplicates them based on position.
class CompositeCandidateGenerator implements CandidateGenerator {
  final List<CandidateGenerator> generators;

  const CompositeCandidateGenerator({
    required this.generators,
  });

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final candidates = <PlacementCandidate>[];

    for (final generator in generators) {
      candidates.addAll(
        generator.generate(request, world),
      );
    }

    return _deduplicate(candidates);
  }

  List<PlacementCandidate> _deduplicate(
    List<PlacementCandidate> candidates,
  ) {
    final result = <PlacementCandidate>[];

    for (final candidate in candidates) {
      final duplicate = result.any(
        (existing) =>
            existing.position.distanceTo(candidate.position) < 0.001,
      );

      if (!duplicate) {
        result.add(candidate);
      }
    }

    return result;
  }
}
