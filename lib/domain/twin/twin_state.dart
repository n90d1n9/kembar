import '../twin/twin_entity.dart';

/// The complete state of a digital twin at a point in time.
/// 
/// This is the source of truth for the entire twin system.
/// All other representations (SpatialWorld, SceneGraph, etc.) are derived from this.
class TwinState {
  final Map<String, TwinEntity> entities;
  final DateTime timestamp;

  const TwinState({
    required this.entities,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Get an entity by ID.
  TwinEntity? entity(String id) {
    return entities[id];
  }

  /// Check if an entity exists.
  bool hasEntity(String id) {
    return entities.containsKey(id);
  }

  /// Create a new state with an added/updated entity.
  TwinState withEntity(TwinEntity entity) {
    return TwinState(
      entities: {
        ...entities,
        entity.id: entity,
      },
      timestamp: DateTime.now(),
    );
  }

  /// Create a new state with a removed entity.
  TwinState withoutEntity(String entityId) {
    final newEntities = {...entities}..remove(entityId);
    return TwinState(
      entities: newEntities,
      timestamp: DateTime.now(),
    );
  }

  /// Get all entities of a specific type.
  List<TwinEntity> entitiesOfType(String type) {
    return entities.values.where((e) => e.type == type).toList();
  }

  /// Get all entities that have a specific component type.
  List<TwinEntity> entitiesWithComponent<T>() {
    return entities.values.where((e) => e.hasComponent<T>()).toList();
  }

  TwinState copyWith({
    Map<String, TwinEntity>? entities,
    DateTime? timestamp,
  }) {
    return TwinState(
      entities: entities ?? this.entities,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
