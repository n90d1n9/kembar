import 'package:vector_math/vector_math_64.dart';

import '../spatial_world.dart';
import '../placement_candidate.dart';
import '../placement_request.dart';
import 'placement_scorer.dart';

/// Scores candidates based on neighbor relationships and alignment.
class NeighborPatternScorer implements PlacementScorer {
  /// Desired spacing between objects.
  final double desiredSpacing;

  /// Tolerance for spacing variations.
  final double spacingTolerance;

  /// Whether to prefer aligned positions.
  final bool preferAlignment;

  /// Whether to prefer same orientation.
  final bool preferSameOrientation;

  const NeighborPatternScorer({
    this.desiredSpacing = 0.05,
    this.spacingTolerance = 0.02,
    this.preferAlignment = true,
    this.preferSameOrientation = true,
  });

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.component(request.subjectId);

    if (subject == null) {
      return 0;
    }

    var score = 0.0;

    for (final entry in world.components.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final neighbor = entry.value;

      final distance = candidate.position.distanceTo(neighbor.position);

      // Only consider nearby neighbors
      if (distance > 2.0) {
        continue;
      }

      // Proximity score (closer is better, but not too close)
      score += _proximityScore(distance);

      // Horizontal alignment score
      if (preferAlignment) {
        score += _alignmentScore(candidate.position, neighbor.position);
      }

      // Orientation score
      if (preferSameOrientation) {
        score += _orientationScore(candidate.rotation, neighbor.rotation);
      }

      // Spacing consistency score
      score += _spacingScore(distance);
    }

    return score;
  }

  /// Score based on proximity to neighbors.
  double _proximityScore(double distance) {
    // Prefer closer positions, but penalize if too close
    if (distance < desiredSpacing - spacingTolerance) {
      return 0; // Too close
    }
    return 1.0 / (1.0 + distance);
  }

  /// Score based on horizontal alignment with neighbors.
  double _alignmentScore(Vector3 candidate, Vector3 neighbor) {
    // Check lateral offset (Z-axis for typical arrangements)
    final lateralOffset = (candidate.z - neighbor.z).abs();
    return 1.0 / (1.0 + lateralOffset);
  }

  /// Score based on orientation alignment.
  double _orientationScore(Vector3 candidateRotation, Vector3 neighborRotation) {
    final difference = (candidateRotation.y - neighborRotation.y).abs();
    // Normalize to [0, π]
    final normalizedDiff = difference > Math.pi ? 2 * Math.pi - difference : difference;
    return 1.0 / (1.0 + normalizedDiff);
  }

  /// Score based on spacing consistency.
  double _spacingScore(double actualDistance) {
    final error = (actualDistance - desiredSpacing).abs();
    return 1.0 / (1.0 + error / spacingTolerance);
  }
}
