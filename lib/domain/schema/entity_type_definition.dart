import 'property_definition.dart';
import '../core/spatial_component.dart';

/// Defines how an entity should be visualized
class VisualizationDefinition {
  final String? modelId;
  final String? colorByProperty;
  final Map<String, String>? propertyToColor;
  final double? defaultScale;
  final bool? castShadow;
  final bool? receiveShadow;

  const VisualizationDefinition({
    this.modelId,
    this.colorByProperty,
    this.propertyToColor,
    this.defaultScale,
    this.castShadow = true,
    this.receiveShadow = true,
  });
}

/// Defines spatial configuration for an entity type
class SpatialDefinition {
  final String type; // 'slot', 'grid', 'world', 'geo', 'freeform'
  final Map<String, Object?> constraints;

  const SpatialDefinition({
    required this.type,
    this.constraints = const {},
  });
}

/// Definition of a relationship type that entities can have
class RelationshipDefinition {
  final String id;
  final String fromType;
  final String toType;
  final String name;
  final bool bidirectional;
  final String? inverseName;

  const RelationshipDefinition({
    required this.id,
    required this.fromType,
    required this.toType,
    required this.name,
    this.bidirectional = false,
    this.inverseName,
  });
}

/// Definition of behavior rules for an entity type
class BehaviorRule {
  final String id;
  final Map<String, Object?> when; // Conditions
  final List<Map<String, Object?>> then; // Actions

  const BehaviorRule({
    required this.id,
    required this.when,
    required this.then,
  });
}

/// Complete definition of an entity type in the twin schema
class EntityTypeDefinition {
  final String type;
  final List<PropertyDefinition> properties;
  final SpatialDefinition? spatial;
  final VisualizationDefinition? visualization;
  final List<RelationshipDefinition> relationships;
  final List<BehaviorRule> behaviors;
  final Set<String> tags;

  const EntityTypeDefinition({
    required this.type,
    this.properties = const [],
    this.spatial,
    this.visualization,
    this.relationships = const [],
    this.behaviors = const [],
    this.tags = const {},
  });

  /// Get a property definition by ID
  PropertyDefinition? getProperty(String id) {
    try {
      return properties.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Validate that all required properties are present
  bool validateProperties(Map<String, dynamic> properties) {
    for (final propDef in properties) {
      if (propDef.metadata.required && !properties.containsKey(propDef.id)) {
        return false;
      }
    }
    return true;
  }
}
