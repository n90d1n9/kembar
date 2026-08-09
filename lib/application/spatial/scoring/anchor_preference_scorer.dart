import '../placement_candidate.dart';
import '../../domain/spatial/placement_request.dart';
import '../spatial_world.dart';
import 'placement_scorer.dart';

/// Scorer that gives bonus points to anchor-based placements.
///
/// Anchors often represent semantically meaningful positions:
/// - Chair positions around a table
/// - Equipment mounting points
/// - Storage slots in racks
///
/// This scorer simply returns 1.0 for any candidate with an anchor ID,
/// and 0.0 otherwise. More sophisticated versions could consider:
/// - Anchor priority/capacity
/// - Semantic matching between object type and anchor purpose
/// - Anchor occupancy status
class AnchorPreferenceScorer implements PlacementScorer {
  const AnchorPreferenceScorer();

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    if (candidate.anchorId == null) {
      return 0;
    }

    return 1.0;
  }
}
