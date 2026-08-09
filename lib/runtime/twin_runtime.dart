import 'dart:async';

import '../domain/core/twin_entity.dart';
import '../domain/core/twin_event.dart';
import '../domain/core/twin_state.dart';

class TwinRuntime {
  TwinState _state;

  final StreamController<TwinEvent> _eventController =
      StreamController<TwinEvent>.broadcast();

  TwinRuntime({
    TwinState initialState = const TwinState(),
  }) : _state = initialState;

  TwinState get state => _state;

  Stream<TwinEvent> get events => _eventController.stream;

  void apply(TwinEvent event) {
    switch (event) {
      case EntityCreated():
        _applyCreated(event);

      case EntityUpdated():
        _applyUpdated(event);

      case EntityRemoved():
        _applyRemoved(event);
    }

    _eventController.add(event);
  }

  void _applyCreated(EntityCreated event) {
    final entities = Map<String, TwinEntity>.of(
      _state.entities,
    );

    entities[event.entity.id.value] = event.entity;

    _state = _state.copyWith(
      entities: entities,
    );
  }

  void _applyUpdated(EntityUpdated event) {
    final entities = Map<String, TwinEntity>.of(
      _state.entities,
    );

    entities[event.entity.id.value] = event.entity;

    _state = _state.copyWith(
      entities: entities,
    );
  }

  void _applyRemoved(EntityRemoved event) {
    final entities = Map<String, TwinEntity>.of(
      _state.entities,
    );

    entities.remove(event.id.value);

    _state = _state.copyWith(
      entities: entities,
    );
  }

  Future<void> dispose() async {
    await _eventController.close();
  }
}
