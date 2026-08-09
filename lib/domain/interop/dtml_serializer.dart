import 'dart:convert';
import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/domain/spatial/spatial_model.dart';

/// Digital Twin Markup Language (DTML) Serializer
/// 
/// A universal JSON-based standard for serializing any digital twin state,
/// geometry, and logic to ensure long-term data portability.
class DtmlSerializer {
  static const String version = '1.0.0';
  
  /// Serialize a TwinState to DTML JSON string
  String serialize(TwinState state, {bool includeGeometry = true}) {
    final map = {
      'dtml_version': version,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': {
        'name': state.name,
        'domain': state.domain,
        'description': state.description,
      },
      'entities': state.entities.map((e) => _serializeEntity(e, includeGeometry)).toList(),
      'relationships': state.relationships.map((r) => r.toJson()).toList(),
      'configuration': state.configuration,
    };
    
    return JsonEncoder.withIndent('  ').convert(map);
  }
  
  /// Deserialize DTML JSON string to TwinState
  TwinState deserialize(String dtmlJson) {
    final map = jsonDecode(dtmlJson) as Map<String, dynamic>;
    
    if (map['dtml_version'] != version) {
      // Handle version mismatch - could add migration logic here
      print('Warning: DTML version mismatch. Expected $version, got ${map['dtml_version']}');
    }
    
    final metadata = map['metadata'] as Map<String, dynamic>;
    final entities = (map['entities'] as List).map((e) => _deserializeEntity(e)).toList();
    final relationships = (map['relationships'] as List).map((r) => _deserializeRelationship(r)).toList();
    
    return TwinState(
      name: metadata['name'] as String,
      domain: metadata['domain'] as String,
      description: metadata['description'] as String? ?? '',
      entities: entities,
      relationships: relationships,
      configuration: Map<String, dynamic>.from(map['configuration'] ?? {}),
    );
  }
  
  Map<String, dynamic> _serializeEntity(dynamic entity, bool includeGeometry) {
    // Use reflection-like approach via properties map
    final base = {
      'id': entity.id,
      'name': entity.name,
      'type': entity.runtimeType.toString(),
      'properties': entity.properties,
      'state': entity.currentState.toJson(),
    };
    
    if (includeGeometry && entity.currentState.spatialModel != null) {
      base['spatial_model'] = entity.currentState.spatialModel!.toJson();
    }
    
    return base;
  }
  
  dynamic _deserializeEntity(Map<String, dynamic> map) {
    // This would typically use a factory registry to create the correct entity type
    // For now, we'll create a generic entity structure
    final spatialModel = map['spatial_model'] != null 
        ? SpatialModel.fromJson(map['spatial_model']) 
        : null;
        
    // In a real implementation, this would use DomainFactory
    throw UnimplementedError('Entity deserialization requires domain-specific factory');
  }
  
  dynamic _deserializeRelationship(Map<String, dynamic> map) {
    // In a real implementation, this would reconstruct SpatialRelationship objects
    throw UnimplementedError('Relationship deserialization requires relationship factory');
  }
}
