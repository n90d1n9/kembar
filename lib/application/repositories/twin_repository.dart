import '../../domain/core/twin_core.dart';

/// Generic repository interface for any digital twin domain.
/// 
/// This is the bridge between external data sources (WebSocket, REST, DB, MQTT, etc.)
/// and the platform-agnostic Twin Kernel.
/// 
/// It knows nothing about specific domains like containers, warehouses, or restaurants.
/// It only knows about TwinEntity and TwinEvent.
abstract class TwinRepository {
  /// Emits events whenever the external twin source changes.
  /// 
  /// This allows fine-grained updates rather than full snapshot rebuilds.
  /// Important for large-scale twins (factories, cities, warehouses with 10k+ entities).
  Stream<TwinEvent> watch();

  /// Fetches the current state once.
  /// 
  /// Used for initial snapshot loading.
  Future<List<TwinEntity>> fetchEntities({
    String? type,
  });
}
