import '../core/twin_property.dart';

/// Defines the type of a property in a twin definition
enum PropertyType {
  string,
  number,
  boolean,
  enumValue,
  dateTime,
  vector,
  geoPoint,
  reference,
  array,
  object,
}

/// Metadata for a property including constraints and visualization hints
class PropertyMetadata {
  final String? unit;
  final String? description;
  final bool required;
  final TwinProperty? defaultValue;
  final List<String>? enumValues; // For enum type
  final num? min; // For number type
  final num? max; // For number type
  final String? refType; // For reference type
  final Map<String, Object?> custom;

  const PropertyMetadata({
    this.unit,
    this.description,
    this.required = false,
    this.defaultValue,
    this.enumValues,
    this.min,
    this.max,
    this.refType,
    this.custom = const {},
  });
}

/// Definition of a single property in an entity type
class PropertyDefinition {
  final String id;
  final PropertyType type;
  final PropertyMetadata metadata;

  const PropertyDefinition({
    required this.id,
    required this.type,
    this.metadata = const PropertyMetadata(),
  });

  /// Validate a value against this property definition
  bool validate(TwinProperty value) {
    switch (type) {
      case PropertyType.string:
        return value is TwinString;
      case PropertyType.number:
        if (value is! TwinNumber) return false;
        final numVal = value.value;
        if (metadata.min != null && numVal < metadata.min!) return false;
        if (metadata.max != null && numVal > metadata.max!) return false;
        return true;
      case PropertyType.boolean:
        return value is TwinBoolean;
      case PropertyType.enumValue:
        if (value is! TwinEnum) return false;
        if (metadata.enumValues == null) return true;
        return metadata.enumValues!.contains(value.value);
      case PropertyType.dateTime:
        return value is TwinDateTime;
      case PropertyType.vector:
      case PropertyType.geoPoint:
      case PropertyType.reference:
      case PropertyType.array:
      case PropertyType.object:
        // TODO: Implement validation for complex types
        return true;
    }
  }
}
