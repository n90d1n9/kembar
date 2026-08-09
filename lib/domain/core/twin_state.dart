import 'twin_entity.dart';
import 'twin_relationship.dart';

class TwinState {
  final Map<String, TwinEntity> entities;

  final List<TwinRelationship> relationships;

  const TwinState({
    this.entities = const {},
    this.relationships = const [],
  });

  TwinEntity? entity(String id) {
    return entities[id];
  }

  List<TwinEntity> entitiesOfType(String type) {
    return entities.values
        .where((entity) => entity.type == type)
        .toList(growable: false);
  }

  List<TwinRelationship> relationshipsFrom(String entityId) {
    return relationships
        .where((relationship) => relationship.from.value == entityId)
        .toList(growable: false);
  }

  List<TwinRelationship> relationshipsTo(String entityId) {
    return relationships
        .where((relationship) => relationship.to.value == entityId)
        .toList(growable: false);
  }

  TwinState copyWith({
    Map<String, TwinEntity>? entities,
    List<TwinRelationship>? relationships,
  }) {
    return TwinState(
      entities: entities ?? this.entities,
      relationships: relationships ?? this.relationships,
    );
  }
}
