import 'twin_entity.dart';
import 'twin_entity_id.dart';

sealed class TwinEvent {
  const TwinEvent();
}

class EntityCreated extends TwinEvent {
  final TwinEntity entity;

  const EntityCreated(this.entity);
}

class EntityUpdated extends TwinEvent {
  final TwinEntity entity;

  const EntityUpdated(this.entity);
}

class EntityRemoved extends TwinEvent {
  final TwinEntityId id;

  const EntityRemoved(this.id);
}
