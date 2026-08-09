import 'package:digital_twin_core/domain/entity.dart';

/// Abstract interface for mapping entities between different domains
/// 
/// Enables semantic translation when importing/exporting across domains
/// (e.g., "Container" in Port ↔ "Pallet" in Warehouse)
abstract class DomainMapper {
  String get sourceDomain;
  String get targetDomain;
  
  /// Map an entity from source domain to target domain representation
  Entity? mapEntity(Entity sourceEntity);
  
  /// Map a collection of entities
  List<Entity> mapEntities(List<Entity> sourceEntities) {
    return sourceEntities
        .map((e) => mapEntity(e))
        .whereType<Entity>()
        .toList();
  }
  
  /// Check if this mapper can handle the given entity type
  bool canMap(String entityType);
}

/// Registry for managing domain mappers
class DomainMapperRegistry {
  final Map<String, DomainMapper> _mappers = {};
  
  /// Register a mapper for a specific domain pair
  void register(DomainMapper mapper) {
    final key = '${mapper.sourceDomain}->${mapper.targetDomain}';
    _mappers[key] = mapper;
  }
  
  /// Get a mapper for converting between two domains
  DomainMapper? getMapper(String sourceDomain, String targetDomain) {
    final key = '$sourceDomain->$targetDomain';
    return _mappers[key];
  }
  
  /// Check if a mapper exists for the given domain pair
  bool hasMapper(String sourceDomain, String targetDomain) {
    final key = '$sourceDomain->$targetDomain';
    return _mappers.containsKey(key);
  }
  
  /// List all registered mapper pairs
  List<String> getRegisteredPairs() {
    return _mappers.keys.toList();
  }
}

/// Example: Port to Warehouse entity mapper
class PortToWarehouseMapper extends DomainMapper {
  @override
  String get sourceDomain => 'port';
  
  @override
  String get targetDomain => 'warehouse';
  
  @override
  Entity? mapEntity(Entity sourceEntity) {
    // In a real implementation, this would transform Port entities to Warehouse entities
    // For example: Container → Pallet, Crane → Forklift, Berth → LoadingDock
    print('Mapping ${sourceEntity.name} from port to warehouse domain');
    
    // This is a placeholder - actual implementation would create new entity instances
    return sourceEntity;
  }
  
  @override
  bool canMap(String entityType) {
    const portTypes = ['Container', 'Terminal', 'Crane', 'Berth'];
    return portTypes.contains(entityType);
  }
}

/// Example: Warehouse to Restaurant entity mapper
class WarehouseToRestaurantMapper extends DomainMapper {
  @override
  String get sourceDomain => 'warehouse';
  
  @override
  String get targetDomain => 'restaurant';
  
  @override
  Entity? mapEntity(Entity sourceEntity) {
    // Map StorageUnit → Table, Item → Customer, Robot → Waiter
    print('Mapping ${sourceEntity.name} from warehouse to restaurant domain');
    return sourceEntity;
  }
  
  @override
  bool canMap(String entityType) {
    const warehouseTypes = ['StorageUnit', 'WarehouseItem', 'Robot'];
    return warehouseTypes.contains(entityType);
  }
}
