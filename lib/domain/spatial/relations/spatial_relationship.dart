import '../spatial_relation.dart';

/// Represents a semantic spatial relationship between two entities.
class SpatialRelationship {
  /// The ID of the subject entity (the entity that has the relation).
  final String subjectId;

  /// The type of spatial relation.
  final SpatialRelationType relation;

  /// The ID of the object entity (the entity that the subject is related to).
  final String objectId;

  /// Confidence score for this relationship (0.0 to 1.0).
  final double confidence;

  /// Additional metadata about this relationship.
  final Map<String, dynamic> metadata;

  /// The current state of this relationship.
  final SpatialRelationState state;

  const SpatialRelationship({
    required this.subjectId,
    required this.relation,
    required this.objectId,
    this.confidence = 1.0,
    this.metadata = const {},
    this.state = SpatialRelationState.active,
  });

  /// Create a copy of this relationship with updated fields.
  SpatialRelationship copyWith({
    String? subjectId,
    SpatialRelationType? relation,
    String? objectId,
    double? confidence,
    Map<String, dynamic>? metadata,
    SpatialRelationState? state,
  }) {
    return SpatialRelationship(
      subjectId: subjectId ?? this.subjectId,
      relation: relation ?? this.relation,
      objectId: objectId ?? this.objectId,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? Map.from(this.metadata),
      state: state ?? this.state,
    );
  }

  /// Get the inverse of this relationship (if it exists).
  SpatialRelationship? get inverse {
    final inverseType = SpatialRelationRegistry.getInverse(relation);
    if (inverseType == null) {
      return null;
    }
    return SpatialRelationship(
      subjectId: objectId,
      relation: inverseType,
      objectId: subjectId,
      confidence: confidence,
      metadata: metadata,
      state: state,
    );
  }

  /// Check if this relationship is currently valid/active.
  bool get isActive => state == SpatialRelationState.active;

  /// Check if this relationship has been marked as broken.
  bool get isBroken => state == SpatialRelationState.broken;

  @override
  bool operator ==(Object other) {
    return other is SpatialRelationship &&
        other.subjectId == subjectId &&
        other.relation == relation &&
        other.objectId == objectId &&
        other.confidence == confidence &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subjectId, relation, objectId, confidence, state);

  @override
  String toString() {
    return 'SpatialRelationship($subjectId ${relation.name} $objectId, state=$state, confidence=$confidence)';
  }
}

/// Lifecycle state of a spatial relationship.
enum SpatialRelationState {
  /// Relationship has been proposed but not yet validated.
  proposed,

  /// Relationship is active and valid.
  active,

  /// Relationship is temporarily invalid (e.g., during movement).
  invalid,

  /// Relationship has been permanently broken.
  broken,
}
