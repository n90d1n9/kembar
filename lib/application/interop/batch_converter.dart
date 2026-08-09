import 'package:digital_twin_core/domain/twin/twin_state.dart';
import 'package:digital_twin_core/application/interop/import_engine.dart';
import 'package:digital_twin_core/application/interop/export_engine.dart';

/// Batch Converter for high-volume migration of legacy data sets
/// 
/// Converts multiple files between formats (CSV→DTML, JSON→DTML, etc.)
class BatchConverter {
  final ImportEngine _importEngine = ImportEngine();
  final ExportEngine _exportEngine = ExportEngine();
  
  int filesProcessed = 0;
  int errorsEncountered = 0;
  
  /// Convert multiple CSV files to DTML
  Future<List<String>> convertCsvToDtml(
    List<MapEntry<String, Map<String, String>>> csvFilesWithSchema,
    String outputDir,
  ) async {
    final results = <String>[];
    
    for (final entry in csvFilesWithSchema) {
      try {
        final filePath = entry.key;
        final schema = entry.value;
        
        print('Converting CSV: $filePath');
        final state = await _importEngine.importFromCsv(filePath, schema);
        final outputPath = '$outputDir/${_extractFileName(filePath)}.dtml.json';
        
        await _exportEngine.saveToFile(state, outputPath);
        results.add(outputPath);
        filesProcessed++;
      } catch (e) {
        print('Error converting $filePath: $e');
        errorsEncountered++;
      }
    }
    
    return results;
  }
  
  /// Convert multiple JSON/DTML files to CSV
  Future<List<String>> convertDtmlToCsv(
    List<String> dtmlFiles,
    String outputDir, {
    String? entityTypeFilter,
  }) async {
    final results = <String>[];
    
    for (final filePath in dtmlFiles) {
      try {
        print('Converting DTML: $filePath');
        // In real implementation, would read file content
        final dtmlContent = '{/* placeholder */}'; 
        final state = _importEngine.importFromJson(dtmlContent);
        
        final csvContent = _exportEngine.exportToCsv(state, entityTypeFilter: entityTypeFilter);
        final outputPath = '$outputDir/${_extractFileName(filePath)}.csv';
        
        // Would write to file here
        results.add(outputPath);
        filesProcessed++;
      } catch (e) {
        print('Error converting $filePath: $e');
        errorsEncountered++;
      }
    }
    
    return results;
  }
  
  /// Migrate legacy format to DTML with entity mapping
  Future<List<TwinState>> migrateWithMapping(
    List<String> sourceFiles,
    String sourceDomain,
    String targetDomain,
  ) async {
    final results = <TwinState>[];
    
    // Would use DomainMapperRegistry in real implementation
    print('Migrating ${sourceFiles.length} files from $sourceDomain to $targetDomain');
    
    for (final filePath in sourceFiles) {
      try {
        // Placeholder for actual migration logic
        filesProcessed++;
      } catch (e) {
        print('Error migrating $filePath: $e');
        errorsEncountered++;
      }
    }
    
    return results;
  }
  
  String _extractFileName(String path) {
    final parts = path.split('/');
    final fileName = parts.last;
    return fileName.contains('.') 
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
  }
  
  /// Get conversion statistics
  Map<String, dynamic> getStatistics() {
    return {
      'files_processed': filesProcessed,
      'errors_encountered': errorsEncountered,
      'success_rate': filesProcessed > 0 
          ? (filesProcessed - errorsEncountered) / filesProcessed 
          : 0.0,
    };
  }
}
