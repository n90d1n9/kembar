import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';
import '../../domain/interaction/interaction_type.dart';
import 'interaction_handler.dart';

class SelectInteractionHandler implements InteractionHandler {
  const SelectInteractionHandler();

  @override
  bool supports(InteractionEvent event) {
    return event.type == InteractionType.select;
  }

  @override
  Future<InteractionResult> handle(
    InteractionEvent event,
  ) async {
    return const InteractionResult.accepted();
  }
}
