import 'spatial_relation.dart';
import 'vector3.dart';

/// Request to place a subject entity relative to a target entity.
class PlacementRequest {
  final String subjectId;
  final String targetId;
  final SpatialRelationType relation;
  final Vector3? preferredPosition;
  final double clearance;

  const PlacementRequest({
    required this.subjectId,
    required this.targetId,
    required this.relation,
    this.preferredPosition,
    this.clearance = 0,
  });

  @override
  bool operator ==(Object other) {
    return other is PlacementRequest &&
        other.subjectId == subjectId &&
        other.targetId == targetId &&
        other.relation == relation &&
        other.preferredPosition == preferredPosition &&
        other.clearance == clearance;
  }

  @override
  int get hashCode => Object.hash(subjectId, targetId, relation, preferredPosition, clearance);
}
