import '../placement_candidate.dart';
import '../../domain/spatial/placement_request.dart';
import '../spatial_world.dart';

/// Abstract interface for scoring placement candidates.
///
/// Scorers evaluate how "good" a candidate position is, returning a
/// numerical score where higher is better. Multiple scorers can be
/// combined to create sophisticated scoring strategies.
///
/// Examples of scoring criteria:
/// - Distance from user's preferred position
/// - Alignment with existing objects
/// - Preference for certain anchors
/// - Stability (lower center of mass)
/// - Accessibility (ease of reaching the object)
/// - Semantic preferences (e.g., keep hazardous materials together)
abstract interface class PlacementScorer {
  /// Score a placement candidate.
  ///
  /// Returns a numerical score where higher values indicate better placements.
  /// A score of 0 means the candidate is neutral/acceptable.
  /// Negative scores indicate undesirable placements (but not necessarily invalid).
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
