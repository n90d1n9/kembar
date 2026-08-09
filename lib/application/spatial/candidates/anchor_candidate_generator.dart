import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../domain/spatial/placement_request.dart';
import '../placement_candidate.dart';
import '../spatial_world.dart';
import 'candidate_generator.dart';

/// Candidate generator that creates positions from spatial anchors.
///
/// Anchors are predefined placement points defined on spatial components.
/// They are useful for:
/// - Chair positions around a table
/// - Slot positions in a warehouse rack
/// - Equipment mounting points
/// - Door/window frames in buildings
///
/// This generator simply converts each anchor into a candidate position,
/// transforming the anchor's local position to world space.
class AnchorCandidateGenerator implements CandidateGenerator {
  const AnchorCandidateGenerator();

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final target = world.component(request.targetId);

    if (target == null) {
      return const [];
    }

    return target.anchors
        .map((anchor) => PlacementCandidate(
              position: _worldAnchorPosition(target, anchor),
              rotation: anchor.rotation,
              anchorId: anchor.id,
              surfaceId: null,
              source: CandidateSource.anchor,
            ))
        .toList();
  }

  /// Convert an anchor's local position to world space.
  ///
  /// For now this is a simple translation. In the future this should
  /// account for full transform hierarchies including rotation and scale.
  vm.Vector3 _worldAnchorPosition(
    vm.SpatialComponent host,
    vm.SpatialAnchor anchor,
  ) {
    return host.position + anchor.localPosition;
  }
}
