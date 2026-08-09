/// Spatial relationship types between entities.
enum SpatialRelationType {
  // Containment relations
  inside,
  contains,

  // Support relations
  on,
  supports,
  stackedOn,

  // Proximity relations
  adjacentTo,
  near,
  far,

  // Positional relations
  leftOf,
  rightOf,
  above,
  below,
  inFrontOf,
  behind,

  // Connection relations
  attachedTo,
  connectedTo,
  alignedWith,

  // Collision/overlap relations
  overlaps,
  intersects,
}

/// Definition of a spatial relation type with its properties.
class SpatialRelationDefinition {
  final SpatialRelationType type;

  /// Whether this relation has a direction (e.g., above/below are directional).
  final bool directional;

  /// Whether the relation is symmetric (e.g., adjacentTo is symmetric).
  final bool symmetric;

  /// The inverse relation type (e.g., above ↔ below).
  final SpatialRelationType? inverse;

  /// Whether this relation requires containment (e.g., inside/contains).
  final bool requiresContainment;

  /// Whether this relation requires physical support (e.g., on/stackedOn).
  final bool requiresSupport;

  /// Whether this relation allows geometric overlap.
  final bool allowsOverlap;

  const SpatialRelationDefinition({
    required this.type,
    this.directional = false,
    this.symmetric = false,
    this.inverse,
    this.requiresContainment = false,
    this.requiresSupport = false,
    this.allowsOverlap = false,
  });
}

/// Registry of all spatial relation definitions.
class SpatialRelationRegistry {
  static const Map<SpatialRelationType, SpatialRelationDefinition> definitions = {
    // Containment relations
    SpatialRelationType.inside: SpatialRelationDefinition(
      type: SpatialRelationType.inside,
      directional: true,
      inverse: SpatialRelationType.contains,
      requiresContainment: true,
    ),
    SpatialRelationType.contains: SpatialRelationDefinition(
      type: SpatialRelationType.contains,
      directional: true,
      inverse: SpatialRelationType.inside,
      requiresContainment: true,
    ),

    // Support relations
    SpatialRelationType.on: SpatialRelationDefinition(
      type: SpatialRelationType.on,
      directional: true,
      inverse: SpatialRelationType.supports,
      requiresSupport: true,
    ),
    SpatialRelationType.supports: SpatialRelationDefinition(
      type: SpatialRelationType.supports,
      directional: true,
      inverse: SpatialRelationType.on,
      requiresSupport: true,
    ),
    SpatialRelationType.stackedOn: SpatialRelationDefinition(
      type: SpatialRelationType.stackedOn,
      directional: true,
      inverse: SpatialRelationType.supports,
      requiresSupport: true,
      allowsOverlap: true,
    ),

    // Proximity relations
    SpatialRelationType.adjacentTo: SpatialRelationDefinition(
      type: SpatialRelationType.adjacentTo,
      symmetric: true,
    ),
    SpatialRelationType.near: SpatialRelationDefinition(
      type: SpatialRelationType.near,
      symmetric: true,
    ),
    SpatialRelationType.far: SpatialRelationDefinition(
      type: SpatialRelationType.far,
      symmetric: true,
    ),

    // Positional relations
    SpatialRelationType.leftOf: SpatialRelationDefinition(
      type: SpatialRelationType.leftOf,
      directional: true,
      inverse: SpatialRelationType.rightOf,
    ),
    SpatialRelationType.rightOf: SpatialRelationDefinition(
      type: SpatialRelationType.rightOf,
      directional: true,
      inverse: SpatialRelationType.leftOf,
    ),
    SpatialRelationType.above: SpatialRelationDefinition(
      type: SpatialRelationType.above,
      directional: true,
      inverse: SpatialRelationType.below,
    ),
    SpatialRelationType.below: SpatialRelationDefinition(
      type: SpatialRelationType.below,
      directional: true,
      inverse: SpatialRelationType.above,
    ),
    SpatialRelationType.inFrontOf: SpatialRelationDefinition(
      type: SpatialRelationType.inFrontOf,
      directional: true,
      inverse: SpatialRelationType.behind,
    ),
    SpatialRelationType.behind: SpatialRelationDefinition(
      type: SpatialRelationType.behind,
      directional: true,
      inverse: SpatialRelationType.inFrontOf,
    ),

    // Connection relations
    SpatialRelationType.attachedTo: SpatialRelationDefinition(
      type: SpatialRelationType.attachedTo,
      symmetric: true,
      allowsOverlap: true,
    ),
    SpatialRelationType.connectedTo: SpatialRelationDefinition(
      type: SpatialRelationType.connectedTo,
      symmetric: true,
    ),
    SpatialRelationType.alignedWith: SpatialRelationDefinition(
      type: SpatialRelationType.alignedWith,
      symmetric: true,
    ),

    // Collision/overlap relations
    SpatialRelationType.overlaps: SpatialRelationDefinition(
      type: SpatialRelationType.overlaps,
      symmetric: true,
      allowsOverlap: true,
    ),
    SpatialRelationType.intersects: SpatialRelationDefinition(
      type: SpatialRelationType.intersects,
      symmetric: true,
      allowsOverlap: true,
    ),
  };

  /// Get the definition for a relation type.
  static SpatialRelationDefinition? getDefinition(SpatialRelationType type) {
    return definitions[type];
  }

  /// Check if two relation types are inverses of each other.
  static bool areInverses(SpatialRelationType a, SpatialRelationType b) {
    final defA = definitions[a];
    return defA?.inverse == b;
  }

  /// Get the inverse relation type, if it exists.
  static SpatialRelationType? getInverse(SpatialRelationType type) {
    return definitions[type]?.inverse;
  }
}
