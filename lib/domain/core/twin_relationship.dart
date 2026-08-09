import 'twin_entity_id.dart';

class TwinRelationship {
  final TwinEntityId from;
  final String type;
  final TwinEntityId to;

  const TwinRelationship({
    required this.from,
    required this.type,
    required this.to,
  });

  @override
  bool operator ==(Object other) {
    return other is TwinRelationship &&
        other.from == from &&
        other.type == type &&
        other.to == to;
  }

  @override
  int get hashCode {
    return Object.hash(from, type, to);
  }
}
