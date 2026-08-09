import 'package:vector_math/vector_math_64.dart' as vm;

import '../placement_candidate.dart';
import '../../domain/spatial/placement_request.dart';
import '../spatial_world.dart';
import 'placement_scorer.dart';

/// Scorer that prefers candidates closer to the user's preferred position.
///
/// Uses an inverse distance formula: score = 1 / (1 + distance)
/// This ensures:
/// - Score approaches 1.0 as distance approaches 0
/// - Score approaches 0 as distance increases
/// - Never negative, always finite
class DistanceScorer implements PlacementScorer {
  const DistanceScorer();

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final preferred = request.preferredPosition;

    if (preferred == null) {
      return 0; // No preference means no distance-based scoring
    }

    final distance = candidate.position.distanceTo(preferred);
    return 1.0 / (1.0 + distance);
  }
}
