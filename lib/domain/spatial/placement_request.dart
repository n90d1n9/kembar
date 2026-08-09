import 'spatial_relation.dart';
import 'vector3.dart';

/// Request to place a subject entity relative to a target entity.
class PlacementRequest {
  /// The ID of the entity being placed.
  final String subjectId;

  /// The ID of the target entity (the reference object).
  final String? targetId;

  /// The semantic spatial relation type.
  final SpatialRelationType relation;

  /// Preferred world position (if not using relation-based placement).
  final Vector3? preferredPosition;

  /// Preferred anchor ID on the target entity.
  final String? preferredAnchorId;

  /// Required clearance distance around the placed object.
  final double clearance;

  /// Whether to automatically create a relationship after successful placement.
  final bool createRelationship;

  const PlacementRequest({
    required this.subjectId,
    required this.relation,
    this.targetId,
    this.preferredPosition,
    this.preferredAnchorId,
    this.clearance = 0,
    this.createRelationship = true,
  });

  @override
  bool operator ==(Object other) {
    return other is PlacementRequest &&
        other.subjectId == subjectId &&
        other.targetId == targetId &&
        other.relation == relation &&
        other.preferredPosition == preferredPosition &&
        other.preferredAnchorId == preferredAnchorId &&
        other.clearance == clearance &&
        other.createRelationship == createRelationship;
  }

  @override
  int get hashCode => Object.hash(
    subjectId,
    targetId,
    relation,
    preferredPosition,
    preferredAnchorId,
    clearance,
    createRelationship,
  );

  @override
  String toString() {
    return 'PlacementRequest(subject=$subjectId, target=$targetId, relation=$relation)';
  }
}
