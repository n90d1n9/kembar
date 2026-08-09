import 'interaction_target.dart';
import 'interaction_type.dart';

class InteractionEvent {
  final InteractionType type;

  final InteractionTarget target;

  final Map<String, Object?> data;

  const InteractionEvent({
    required this.type,
    required this.target,
    this.data = const {},
  });
}
