import 'vector3.dart';

/// Result of a placement evaluation.
class PlacementResult {
  final bool valid;
  final Vector3? position;
  final Vector3? rotation;
  final String? surfaceId;
  final String? anchorId;
  final double score;
  final List<String> reasons;

  const PlacementResult({
    required this.valid,
    this.position,
    this.rotation,
    this.surfaceId,
    this.anchorId,
    this.score = 0,
    this.reasons = const [],
  });

  const PlacementResult.invalid(String reason)
      : valid = false,
        position = null,
        rotation = null,
        surfaceId = null,
        anchorId = null,
        score = 0,
        reasons = [reason];

  @override
  bool operator ==(Object other) {
    return other is PlacementResult &&
        other.valid == valid &&
        other.position == position &&
        other.rotation == rotation &&
        other.surfaceId == surfaceId &&
        other.anchorId == anchorId &&
        other.score == score &&
        other.reasons == reasons;
  }

  @override
  int get hashCode => Object.hash(valid, position, rotation, surfaceId, anchorId, score, reasons);
}
