import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';

abstract class InteractionHandler {
  bool supports(InteractionEvent event);

  Future<InteractionResult> handle(
    InteractionEvent event,
  );
}
