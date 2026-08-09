import '../../domain/core/twin_command.dart';
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_type.dart';

class InteractionCommandMapper {
  const InteractionCommandMapper();

  TwinCommand? map(
    InteractionEvent event,
  ) {
    switch (event.type) {
      case InteractionType.move:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'move',
          parameters: event.data,
        );

      case InteractionType.activate:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'activate',
        );

      case InteractionType.deactivate:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'deactivate',
        );

      default:
        return null;
    }
  }
}
