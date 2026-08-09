import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';
import 'interaction_handler.dart';

class InteractionSystem {
  final List<InteractionHandler> handlers;

  const InteractionSystem({
    required this.handlers,
  });

  Future<InteractionResult> handle(
    InteractionEvent event,
  ) async {
    for (final handler in handlers) {
      if (handler.supports(event)) {
        return handler.handle(event);
      }
    }

    return const InteractionResult.ignored();
  }
}
