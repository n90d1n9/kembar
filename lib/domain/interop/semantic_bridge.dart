/// Semantic Bridge for resolving terminology differences between domains
/// 
/// Maps concepts, attributes, and relationships from one domain's vocabulary
/// to another's (e.g., "Berth" in Port ↔ "Dock" in Warehouse)
class SemanticBridge {
  final Map<String, Map<String, String>> _conceptMappings = {};
  final Map<String, Map<String, String>> _attributeMappings = {};
  
  /// Register a concept mapping between two domains
  void mapConcept({
    required String sourceDomain,
    required String targetDomain,
    required String sourceTerm,
    required String targetTerm,
  }) {
    final key = '$sourceDomain->$targetDomain';
    _conceptMappings.putIfAbsent(key, () => {});
    _conceptMappings[key]![sourceTerm] = targetTerm;
  }
  
  /// Register an attribute mapping between two domains
  void mapAttribute({
    required String sourceDomain,
    required String targetDomain,
    required String sourceAttr,
    required String targetAttr,
  }) {
    final key = '$sourceDomain->$targetDomain';
    _attributeMappings.putIfAbsent(key, () => {});
    _attributeMappings[key]![sourceAttr] = targetAttr;
  }
  
  /// Translate a concept from source domain to target domain
  String? translateConcept({
    required String sourceDomain,
    required String targetDomain,
    required String term,
  }) {
    final key = '$sourceDomain->$targetDomain';
    return _conceptMappings[key]?[term];
  }
  
  /// Translate an attribute from source domain to target domain
  String? translateAttribute({
    required String sourceDomain,
    required String targetDomain,
    required String attribute,
  }) {
    final key = '$sourceDomain->$targetDomain';
    return _attributeMappings[key]?[attribute];
  }
  
  /// Transform a properties map from source domain to target domain
  Map<String, dynamic> transformProperties({
    required String sourceDomain,
    required String targetDomain,
    required Map<String, dynamic> sourceProperties,
  }) {
    final result = <String, dynamic>{};
    final key = '$sourceDomain->$targetDomain';
    final attrMap = _attributeMappings[key] ?? {};
    
    for (final entry in sourceProperties.entries) {
      final targetKey = attrMap[entry.key] ?? entry.key;
      result[targetKey] = entry.value;
    }
    
    return result;
  }
  
  /// Build standard mappings for common domain pairs
  void buildStandardMappings() {
    // Port ↔ Warehouse
    mapConcept(sourceDomain: 'port', targetDomain: 'warehouse', sourceTerm: 'Berth', targetTerm: 'LoadingDock');
    mapConcept(sourceDomain: 'port', targetDomain: 'warehouse', sourceTerm: 'Container', targetTerm: 'Pallet');
    mapConcept(sourceDomain: 'port', targetDomain: 'warehouse', sourceTerm: 'Crane', targetTerm: 'Forklift');
    mapConcept(sourceDomain: 'port', targetDomain: 'warehouse', sourceTerm: 'Terminal', targetTerm: 'StorageArea');
    
    mapAttribute(sourceDomain: 'port', targetDomain: 'warehouse', sourceAttr: 'cargo_type', targetAttr: 'item_type');
    mapAttribute(sourceDomain: 'port', targetDomain: 'warehouse', sourceAttr: 'weight', targetAttr: 'weight');
    mapAttribute(sourceDomain: 'port', targetDomain: 'warehouse', sourceAttr: 'destination', targetAttr: 'storage_location');
    
    // Warehouse ↔ Restaurant
    mapConcept(sourceDomain: 'warehouse', targetDomain: 'restaurant', sourceTerm: 'StorageUnit', targetTerm: 'Table');
    mapConcept(sourceDomain: 'warehouse', targetDomain: 'restaurant', sourceTerm: 'WarehouseItem', targetTerm: 'Customer');
    mapConcept(sourceDomain: 'warehouse', targetDomain: 'restaurant', sourceTerm: 'Robot', targetTerm: 'Waiter');
    
    mapAttribute(sourceDomain: 'warehouse', targetDomain: 'restaurant', sourceAttr: 'capacity', targetAttr: 'seating_capacity');
    mapAttribute(sourceDomain: 'warehouse', targetDomain: 'restaurant', sourceAttr: 'is_occupied', targetAttr: 'is_seated');
    
    // Parking ↔ Restaurant
    mapConcept(sourceDomain: 'parking', targetDomain: 'restaurant', sourceTerm: 'ParkingSpace', targetTerm: 'Table');
    mapConcept(sourceDomain: 'parking', targetDomain: 'restaurant', sourceTerm: 'Vehicle', targetTerm: 'Customer');
    mapConcept(sourceDomain: 'parking', targetDomain: 'restaurant', sourceTerm: 'Gate', targetTerm: 'Entrance');
  }
}
