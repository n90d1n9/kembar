import 'dart:async';

import '../domain/core/twin_entity.dart';
import '../domain/core/twin_event.dart';
import '../domain/core/twin_state.dart';

class TwinRuntime {
  TwinState _state;

  final StreamController<TwinEvent> _eventController =
      StreamController<TwinEvent>.broadcast();

  final StreamController<TwinState> _stateController =
      StreamController<TwinState>.broadcast();

  TwinRuntime({
    TwinState initialState = const TwinState(),
  }) : _state = initialState;

  TwinState get state => _state;

  Stream<TwinEvent> get events => _eventController.stream;

  /// Stream of TwinState that emits after every event.
  /// 
  /// Useful for UI/dashboard consumers that want current state
  /// rather than individual events.
  Stream<TwinState> get states => _stateController.stream;

  /// Number of entities currently in the runtime.
  int get entityCount => _state.entities.length;

  /// Count entities by type.
  /// 
  /// Useful for debugging and dashboards.
  int countByType(String type) {
    return _state.entities.values
        .where((entity) => entity.type == type)
        .length;
  }

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
    _stateController.add(_state);
  }

  /// Apply multiple events at once.
  /// 
  /// Useful for initial snapshot loading.
  void applyAll(Iterable<TwinEvent> events) {
    for (final event in events) {
      apply(event);
    }
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
    await _stateController.close();
  }
}
