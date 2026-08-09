import 'twin_component.dart';
import 'twin_entity_id.dart';

class TwinEntity {
  final TwinEntityId id;

  /// Generic type of the entity.
  ///
  /// Examples:
  /// - container
  /// - crane
  /// - truck
  /// - machine
  /// - robot
  /// - building
  final String type;

  final Map<String, TwinComponent> components;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
  });

  TwinComponent? component(String type) {
    return components[type];
  }

  bool hasComponent(String type) {
    return components.containsKey(type);
  }

  TwinEntity copyWith({
    TwinEntityId? id,
    String? type,
    Map<String, TwinComponent>? components,
  }) {
    return TwinEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      components: components ?? this.components,
    );
  }
}
