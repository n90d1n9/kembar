import '../placement_candidate.dart';
import '../spatial_world.dart';
import '../../../domain/spatial/placement_request.dart';

/// Abstract interface for generating placement candidates.
///
/// Candidate generators are responsible for producing plausible positions
/// where an object could potentially be placed. They do NOT validate
/// whether those positions are actually valid - that's the job of the
/// constraint engine.
///
/// This separation allows multiple generation strategies to be composed:
/// - Surface-based generation (center, edges, corners)
/// - Grid sampling around user intent
/// - Anchor-based generation (predefined slots)
/// - Neighbor-aware generation (packing next to existing objects)
abstract interface class CandidateGenerator {
  /// Generate candidate positions for the given placement request.
  ///
  /// [request] contains information about what is being placed and where.
  /// [world] provides access to spatial components, surfaces, and anchors.
  ///
  /// Returns a list of candidate positions. May be empty if no candidates
  /// can be generated for this request.
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  );
}
