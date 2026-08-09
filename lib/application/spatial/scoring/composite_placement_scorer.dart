import '../placement_candidate.dart';
import '../../domain/spatial/placement_request.dart';
import '../spatial_world.dart';
import 'placement_scorer.dart';

/// Composite scorer that combines multiple scorers.
///
/// This allows you to build sophisticated scoring strategies by
/// combining simpler scorers. The total score is the sum of all
/// individual scorer results.
///
/// Example usage:
/// ```dart
/// final scorer = CompositePlacementScorer(
///   scorers: [
///     DistanceScorer(),        // Prefer positions near user's click
///     AnchorPreferenceScorer(), // Bonus for anchor positions
///     StabilityScorer(),       // Bonus for lower center of mass
///   ],
/// );
/// ```
///
/// Future enhancement: Add weights to each scorer for fine-tuned control:
/// ```dart
/// WeightedScorer([
///   (DistanceScorer(), 0.5),
///   (AnchorPreferenceScorer(), 0.3),
///   (StabilityScorer(), 0.2),
/// ])
/// ```
class CompositePlacementScorer implements PlacementScorer {
  final List<PlacementScorer> scorers;

  const CompositePlacementScorer({
    required this.scorers,
  });

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    var total = 0.0;

    for (final scorer in scorers) {
      total += scorer.score(candidate, request, world);
    }

    return total;
  }
}
