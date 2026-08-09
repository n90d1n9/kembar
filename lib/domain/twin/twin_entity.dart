/// A generic twin entity with typed components.
/// 
/// This is the core entity type for the platform-agnostic digital twin system.
/// Entities are composed of typed components rather than having fixed fields,
/// allowing the system to support any domain (port, parking, restaurant, warehouse, etc.)
class TwinEntity {
  final String id;
  final String type;
  final Map<Type, Object> components;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
  });

  /// Get a component of type T, or null if not present.
  T? component<T>() {
    return components[T] as T?;
  }

  /// Check if entity has a component of type T.
  bool hasComponent<T>() {
    return components.containsKey(T);
  }

  /// Create a new entity with an added/updated component of type T.
  TwinEntity withComponent<T>(T component) {
    return TwinEntity(
      id: id,
      type: type,
      components: {
        ...components,
        T: component,
      },
    );
  }

  /// Create a new entity with a removed component of type T.
  TwinEntity withoutComponent<T>() {
    return TwinEntity(
      id: id,
      type: type,
      components: {
        ...components..remove(T),
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! TwinEntity) return false;
    return other.id == id &&
        other.type == type &&
        other.components == components;
  }

  @override
  int get hashCode => Object.hash(id, type, components);
}
