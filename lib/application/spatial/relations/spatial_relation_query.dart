import '../domain/spatial/relations/spatial_relationship.dart';
import '../domain/spatial/spatial_relation.dart';
import 'spatial_world.dart';

/// Query API for searching and filtering spatial relationships in a world.
class SpatialRelationQuery {
  final SpatialWorld world;

  const SpatialRelationQuery(this.world);

  /// Find all relationships where the given entity is the subject.
  List<SpatialRelationship> whereSubject(String subjectId) {
    return world.relationships
        .where((r) => r.subjectId == subjectId)
        .toList();
  }

  /// Find all relationships where the given entity is the object.
  List<SpatialRelationship> whereObject(String objectId) {
    return world.relationships
        .where((r) => r.objectId == objectId)
        .toList();
  }

  /// Find relationships matching specific criteria.
  ///
  /// All parameters are optional filters.
  List<SpatialRelationship> find({
    String? subjectId,
    SpatialRelationType? relation,
    String? objectId,
    SpatialRelationState? state,
  }) {
    return world.relationships.where((r) {
      if (subjectId != null && r.subjectId != subjectId) {
        return false;
      }
      if (relation != null && r.relation != relation) {
        return false;
      }
      if (objectId != null && r.objectId != objectId) {
        return false;
      }
      if (state != null && r.state != state) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Find all relationships of a specific type where the given entity is the object.
  ///
  /// Example: Find everything that is ON a shelf.
  List<SpatialRelationship> findByRelationAndObject(
    SpatialRelationType relation,
    String objectId,
  ) {
    return find(relation: relation, objectId: objectId);
  }

  /// Find all entities that have a specific relation to the given object.
  ///
  /// Example: Get all entities that are INSIDE a room.
  List<String> getSubjectsRelatedTo(
    SpatialRelationType relation,
    String objectId,
  ) {
    return find(relation: relation, objectId: objectId)
        .map((r) => r.subjectId)
        .toList();
  }

  /// Find all entities that the given subject is related to.
  ///
  /// Example: Get all entities that a chair is ADJACENT_TO.
  List<String> getObjectsRelatedToSubject(
    String subjectId,
    SpatialRelationType? relation,
  ) {
    final relationships = relation != null
        ? whereSubject(subjectId).where((r) => r.relation == relation).toList()
        : whereSubject(subjectId);
    
    return relationships.map((r) => r.objectId).toList();
  }

  /// Check if a specific relationship exists.
  bool hasRelationship({
    required String subjectId,
    required SpatialRelationType relation,
    required String objectId,
  }) {
    return world.relationships.any((r) =>
        r.subjectId == subjectId &&
        r.relation == relation &&
        r.objectId == objectId &&
        r.isActive);
  }

  /// Get all active relationships.
  List<SpatialRelationship> get activeRelationships {
    return world.relationships.where((r) => r.isActive).toList();
  }

  /// Get all broken relationships.
  List<SpatialRelationship> get brokenRelationships {
    return world.relationships.where((r) => r.isBroken).toList();
  }

  /// Find the inverse of a given relationship.
  SpatialRelationship? findInverse(SpatialRelationship relationship) {
    final inverseType = relationship.inverse?.relation;
    if (inverseType == null) {
      return null;
    }
    
    return world.relationships.firstWhere(
      (r) =>
          r.subjectId == relationship.objectId &&
          r.relation == inverseType &&
          r.objectId == relationship.subjectId,
      orElse: () => throw StateError('Inverse relationship not found'),
    );
  }

  /// Group relationships by their type.
  Map<SpatialRelationType, List<SpatialRelationship>> groupByRelationType() {
    final result = <SpatialRelationType, List<SpatialRelationship>>{};
    
    for (final relationship in world.relationships) {
      result.putIfAbsent(relationship.relation, () => []).add(relationship);
    }
    
    return result;
  }

  /// Get relationships involving any of the given entity IDs.
  List<SpatialRelationship> involvingEntities(List<String> entityIds) {
    final entityIdSet = entityIds.toSet();
    return world.relationships.where((r) =>
        entityIdSet.contains(r.subjectId) ||
        entityIdSet.contains(r.objectId)).toList();
  }
}
