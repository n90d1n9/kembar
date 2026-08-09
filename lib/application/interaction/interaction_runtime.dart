import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_state.dart';
import '../../domain/interaction/interaction_type.dart';

class InteractionRuntime {
  InteractionState _state =
      const InteractionState();

  InteractionState get state => _state;

  void apply(InteractionEvent event) {
    switch (event.type) {
      case InteractionType.hover:
        _state = _state.copyWith(
          hoveredEntityId: event.target.entityId,
        );

      case InteractionType.select:
        _state = _state.copyWith(
          selectedEntityId: event.target.entityId,
        );

      case InteractionType.focus:
        _state = _state.copyWith(
          focusedEntityId: event.target.entityId,
        );

      default:
        break;
    }
  }
}
