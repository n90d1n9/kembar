import 'dart:convert';
import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/domain/interop/dtml_serializer.dart';

/// Export Engine for serializing TwinState to various formats
/// 
/// Supports DTML (native), glTF (3D geometry), and CSV (data export)
class ExportEngine {
  final DtmlSerializer _dtmlSerializer = DtmlSerializer();
  
  /// Export TwinState to DTML JSON string
  String exportToDtml(TwinState state, {bool includeGeometry = true}) {
    return _dtmlSerializer.serialize(state, includeGeometry: includeGeometry);
  }
  
  /// Export TwinState to generic JSON (DTML format)
  String exportToJson(TwinState state, {bool includeGeometry = true}) {
    return exportToDtml(state, includeGeometry: includeGeometry);
  }
  
  /// Export TwinState to glTF-compatible structure (geometry only)
  Future<String> exportToGltf(TwinState state, String outputPath) async {
    // In a real implementation, this would generate glTF 2.0 JSON + binary buffer
    print('Exporting geometry to glTF: $outputPath');
    throw UnimplementedError('glTF export requires 3D geometry serialization library');
  }
  
  /// Export entity properties to CSV format
  String exportToCsv(TwinState state, {String? entityTypeFilter}) {
    final entities = entityTypeFilter != null
        ? state.entities.where((e) => e.runtimeType.toString() == entityTypeFilter).toList()
        : state.entities;
    
    if (entities.isEmpty) {
      return '';
    }
    
    // Build CSV header from property keys
    final allKeys = <String>{};
    for (final entity in entities) {
      allKeys.addAll(entity.properties.keys.map((k) => k.toString()));
    }
    allKeys.addAll(['id', 'name', 'type']);
    
    final sortedKeys = allKeys.toList()..sort();
    
    // Build CSV rows
    final buffer = StringBuffer();
    buffer.writeln(sortedKeys.join(','));
    
    for (final entity in entities) {
      final row = sortedKeys.map((key) {
        if (key == 'id') return '"${entity.id}"';
        if (key == 'name') return '"${entity.name}"';
        if (key == 'type') return '"${entity.runtimeType}"';
        
        final value = entity.properties[key];
        if (value == null) return '';
        if (value is String) return '"${value.replaceAll('"', '""')}"';
        return value.toString();
      }).join(',');
      
      buffer.writeln(row);
    }
    
    return buffer.toString();
  }
  
  /// Save DTML to file (requires file system access)
  Future<void> saveToFile(TwinState state, String filePath, {bool includeGeometry = true}) async {
    final dtmlContent = exportToDtml(state, includeGeometry: includeGeometry);
    // In a real implementation with dart:io, this would write to disk
    print('Would save DTML to: $filePath (${dtmlContent.length} bytes)');
    throw UnimplementedError('File I/O requires dart:io import');
  }
}
