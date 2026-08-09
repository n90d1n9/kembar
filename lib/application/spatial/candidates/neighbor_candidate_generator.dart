import 'package:vector_math/vector_math_64.dart';

import '../spatial_world.dart';
import 'placement_candidate.dart';
import '../placement_request.dart';

/// Generates placement candidates based on neighboring entities.
class NeighborCandidateGenerator {
  /// Desired spacing between adjacent objects.
  final double spacing;

  const NeighborCandidateGenerator({
    this.spacing = 0.05,
  });

  /// Generate candidates around neighboring entities.
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.component(request.subjectId);

    if (subject == null) {
      return const [];
    }

    final candidates = <PlacementCandidate>[];

    for (final entry in world.components.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final neighbor = entry.value;

      candidates.addAll(
        _generateAroundNeighbor(subject, neighbor, entry.key),
      );
    }

    return candidates;
  }

  /// Generate candidates around a single neighbor.
  List<PlacementCandidate> _generateAroundNeighbor(
    SpatialComponent subject,
    SpatialComponent neighbor,
    String neighborId,
  ) {
    final bounds = neighbor.worldBounds;
    final halfWidth = subject.localBounds.width / 2;
    final halfDepth = subject.localBounds.depth / 2;
    final halfHeight = subject.localBounds.height / 2;
    final y = subject.position.y;

    return [
      // Right of neighbor
      PlacementCandidate(
        position: Vector3(
          bounds.max.x + halfWidth + spacing,
          y,
          neighbor.position.z,
        ),
        rotation: subject.rotation,
        source: CandidateSource.neighbor,
        metadata: {'neighbor_id': neighborId, 'direction': 'right'},
      ),
      // Left of neighbor
      PlacementCandidate(
        position: Vector3(
          bounds.min.x - halfWidth - spacing,
          y,
          neighbor.position.z,
        ),
        rotation: subject.rotation,
        source: CandidateSource.neighbor,
        metadata: {'neighbor_id': neighborId, 'direction': 'left'},
      ),
      // Front of neighbor
      PlacementCandidate(
        position: Vector3(
          neighbor.position.x,
          y,
          bounds.max.z + halfDepth + spacing,
        ),
        rotation: subject.rotation,
        source: CandidateSource.neighbor,
        metadata: {'neighbor_id': neighborId, 'direction': 'front'},
      ),
      // Back of neighbor
      PlacementCandidate(
        position: Vector3(
          neighbor.position.x,
          y,
          bounds.min.z - halfDepth - spacing,
        ),
        rotation: subject.rotation,
        source: CandidateSource.neighbor,
        metadata: {'neighbor_id': neighborId, 'direction': 'back'},
      ),
      // Above neighbor (for stacking)
      PlacementCandidate(
        position: Vector3(
          neighbor.position.x,
          bounds.max.y + halfHeight + spacing,
          neighbor.position.z,
        ),
        rotation: subject.rotation,
        source: CandidateSource.neighbor,
        metadata: {'neighbor_id': neighborId, 'direction': 'above'},
      ),
    ];
  }
}
