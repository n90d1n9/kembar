import 'twin_entity_id.dart';

class TwinCommand {
  final TwinEntityId entityId;

  final String action;

  final Map<String, Object?> parameters;

  const TwinCommand({
    required this.entityId,
    required this.action,
    this.parameters = const {},
  });
}
