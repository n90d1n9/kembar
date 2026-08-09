import 'entity_type_definition.dart';

/// Complete schema definition for a digital twin
/// 
/// This is the declarative specification that defines:
/// - What entity types exist
/// - Their properties and constraints
/// - Relationships between entities
/// - Visualization configuration
/// - Behavior rules
/// 
/// Example usage:
/// ```dart
/// final terminalSchema = TwinDefinition(
///   id: 'container-terminal',
///   version: '1.0.0',
///   entityTypes: [
///     EntityTypeDefinition(
///       type: 'container',
///       properties: [...],
///       visualization: VisualizationDefinition(modelId: 'container.glb'),
///     ),
///   ],
/// );
/// ```
class TwinDefinition {
  /// Unique identifier for this twin definition
  final String id;

  /// Version of the schema (semver format recommended)
  final String version;

  /// Human-readable name
  final String? name;

  /// Description of what this twin represents
  final String? description;

  /// All entity types defined in this twin
  final List<EntityTypeDefinition> entityTypes;

  /// Global relationships that apply across entity types
  final List<RelationshipDefinition> globalRelationships;

  /// Default visualization settings
  final Map<String, Object?>? defaultVisualization;

  /// Custom metadata
  final Map<String, Object?> metadata;

  const TwinDefinition({
    required this.id,
    required this.version,
    this.name,
    this.description,
    this.entityTypes = const [],
    this.globalRelationships = const [],
    this.defaultVisualization,
    this.metadata = const {},
  });

  /// Get an entity type definition by its type name
  EntityTypeDefinition? getEntityType(String type) {
    try {
      return entityTypes.firstWhere((et) => et.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Check if an entity type is defined in this schema
  bool hasEntityType(String type) {
    return entityTypes.any((et) => et.type == type);
  }

  /// Get all entity types with a specific tag
  List<EntityTypeDefinition> getEntitiesByTag(String tag) {
    return entityTypes.where((et) => et.tags.contains(tag)).toList();
  }

  /// Validate the schema itself (not instances)
  ValidationResult validate() {
    final errors = <String>[];

    // Check for duplicate entity types
    final typeNames = <String>{};
    for (final entityType in entityTypes) {
      if (typeNames.contains(entityType.type)) {
        errors.add('Duplicate entity type: ${entityType.type}');
      }
      typeNames.add(entityType.type);

      // Check for duplicate property names within entity type
      final propNames = <String>{};
      for (final prop in entityType.properties) {
        if (propNames.contains(prop.id)) {
          errors.add(
            'Duplicate property "${prop.id}" in entity type "${entityType.type}"',
          );
        }
        propNames.add(prop.id);
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Create a copy with modifications
  TwinDefinition copyWith({
    String? id,
    String? version,
    String? name,
    String? description,
    List<EntityTypeDefinition>? entityTypes,
    List<RelationshipDefinition>? globalRelationships,
    Map<String, Object?>? defaultVisualization,
    Map<String, Object?>? metadata,
  }) {
    return TwinDefinition(
      id: id ?? this.id,
      version: version ?? this.version,
      name: name ?? this.name,
      description: description ?? this.description,
      entityTypes: entityTypes ?? this.entityTypes,
      globalRelationships: globalRelationships ?? this.globalRelationships,
      defaultVisualization: defaultVisualization ?? this.defaultVisualization,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Result of schema validation
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}
