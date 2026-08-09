import 'package:digital_twin_core/digital_twin_core.dart';

void main() {
  print('=== Step 12: Semantic Spatial Relations Demo ===\n');

  // Create a spatial world with some components
  final shelf = SpatialComponent(
    id: 'shelf-01',
    position: Vector3(0, 0, 0),
    rotation: Vector3(0, 0, 0),
    bounds: Bounds(min: Vector3(-1, 0, -0.5), max: Vector3(1, 1.5, 0.5)),
    surfaces: [
      PlacementSurface(
        id: 'top-surface',
        bounds: Bounds(min: Vector3(-0.8, 1.4, -0.4), max: Vector3(0.8, 1.5, 0.4)),
      ),
    ],
  );

  final box = SpatialComponent(
    id: 'box-001',
    position: Vector3(0, 1.5, 0),
    rotation: Vector3(0, 0, 0),
    bounds: Bounds(min: Vector3(-0.2, 1.4, -0.2), max: Vector3(0.2, 1.6, 0.2)),
    surfaces: [],
  );

  final chair = SpatialComponent(
    id: 'chair-01',
    position: Vector3(2, 0, 1),
    rotation: Vector3(0, 0, 0),
    bounds: Bounds(min: Vector3(1.7, 0, 0.7), max: Vector3(2.3, 0.9, 1.3)),
    surfaces: [],
  );

  final table = SpatialComponent(
    id: 'table-01',
    position: Vector3(2, 0, 0),
    rotation: Vector3(0, 0, 0),
    bounds: Bounds(min: Vector3(1.2, 0, -0.6), max: Vector3(2.8, 0.75, 0.6)),
    surfaces: [],
  );

  // Create relationships
  final boxOnShelf = SpatialRelationship(
    subjectId: 'box-001',
    relation: SpatialRelationType.on,
    objectId: 'shelf-01',
    metadata: {'surfaceId': 'top-surface'},
  );

  final chairAtTable = SpatialRelationship(
    subjectId: 'chair-01',
    relation: SpatialRelationType.adjacentTo,
    objectId: 'table-01',
    metadata: {'anchorId': 'seat-position'},
  );

  // Create spatial world with relationships
  final world = SpatialWorld(
    components: {
      'shelf-01': shelf,
      'box-001': box,
      'chair-01': chair,
      'table-01': table,
    },
    relationships: [boxOnShelf, chairAtTable],
  );

  print('✓ Created spatial world with ${world.components.length} components');
  print('✓ Added ${world.relationships.length} relationships\n');

  // Create query object
  final query = SpatialRelationQuery(world);

  // Demo 1: Query by relation type and object
  print('=== Demo 1: What is ON the shelf? ===');
  final itemsOnShelf = query.findByRelationAndObject(
    SpatialRelationType.on,
    'shelf-01',
  );
  for (final item in itemsOnShelf) {
    print('  - ${item.subjectId} is ${item.relation.name} ${item.objectId}');
  }

  // Demo 2: Get subjects related to an object
  print('\n=== Demo 2: What is ADJACENT_TO the table? ===');
  final adjacentToTable = query.getSubjectsRelatedTo(
    SpatialRelationType.adjacentTo,
    'table-01',
  );
  print('  Entities adjacent to table-01: $adjacentToTable');

  // Demo 3: Check if relationship exists
  print('\n=== Demo 3: Does box-001 have an ON relationship with shelf-01? ===');
  final hasRelation = query.hasRelationship(
    subjectId: 'box-001',
    relation: SpatialRelationType.on,
    objectId: 'shelf-01',
  );
  print('  Result: ${hasRelation ? "YES" : "NO"}');

  // Demo 4: Get all active relationships
  print('\n=== Demo 4: All Active Relationships ===');
  final active = query.activeRelationships;
  for (final rel in active) {
    print('  - ${rel.subjectId} ${rel.relation.name} ${rel.objectId}');
  }

  // Demo 5: Group by relation type
  print('\n=== Demo 5: Relationships Grouped by Type ===');
  final grouped = query.groupByRelationType();
  grouped.forEach((type, relations) {
    print('  ${type.name}: ${relations.length} relationship(s)');
    for (final rel in relations) {
      print('    - ${rel.subjectId} → ${rel.objectId}');
    }
  });

  // Demo 6: Inverse relationships
  print('\n=== Demo 6: Inverse Relationships ===');
  final inverse = boxOnShelf.inverse;
  if (inverse != null) {
    print('  Original: ${boxOnShelf.subjectId} ${boxOnShelf.relation.name} ${boxOnShelf.objectId}');
    print('  Inverse:  ${inverse.subjectId} ${inverse.relation.name} ${inverse.objectId}');
  }

  // Demo 7: Relation constraint resolver
  print('\n=== Demo 7: Relation-Specific Constraints ===');
  final resolver = RelationConstraintResolver();
  
  final onConstraints = resolver.resolve(SpatialRelationType.on);
  print('  ON constraints: ${onConstraints.map((c) => c.runtimeType).join(", ")}');
  
  final adjacentConstraints = resolver.resolve(SpatialRelationType.adjacentTo);
  print('  ADJACENT_TO constraints: ${adjacentConstraints.map((c) => c.runtimeType).join(", ")}');
  
  final insideConstraints = resolver.resolve(SpatialRelationType.inside);
  print('  INSIDE constraints: ${insideConstraints.map((c) => c.runtimeType).join(", ")}');

  // Demo 8: Relationship lifecycle
  print('\n=== Demo 8: Relationship Lifecycle ===');
  final proposedRel = boxOnShelf.copyWith(state: SpatialRelationState.proposed);
  print('  Proposed relationship state: ${proposedRel.state}');
  
  final activeRel = proposedRel.copyWith(state: SpatialRelationState.active);
  print('  After validation: ${activeRel.state}');
  
  final invalidRel = activeRel.copyWith(state: SpatialRelationState.invalid);
  print('  During movement: ${invalidRel.state}');
  
  final brokenRel = invalidRel.copyWith(state: SpatialRelationState.broken);
  print('  If support removed: ${brokenRel.state}');

  // Demo 9: Multi-domain examples
  print('\n=== Demo 9: Multi-Domain Relationships ===');
  
  // Warehouse
  final cargoOnPallet = SpatialRelationship(
    subjectId: 'cargo-123',
    relation: SpatialRelationType.stackedOn,
    objectId: 'pallet-04',
  );
  print('  Warehouse: ${cargoOnPallet.subjectId} ${cargoOnPallet.relation.name} ${cargoOnPallet.objectId}');
  
  // Restaurant
  final plateOnTable = SpatialRelationship(
    subjectId: 'plate-07',
    relation: SpatialRelationType.on,
    objectId: 'table-03',
  );
  print('  Restaurant: ${plateOnTable.subjectId} ${plateOnTable.relation.name} ${plateOnTable.relation.name} ${plateOnTable.objectId}');
  
  // Factory
  final sensorAttachedToMachine = SpatialRelationship(
    subjectId: 'sensor-15',
    relation: SpatialRelationType.attachedTo,
    objectId: 'machine-08',
  );
  print('  Factory: ${sensorAttachedToMachine.subjectId} ${sensorAttachedToMachine.relation.name} ${sensorAttachedToMachine.objectId}');
  
  // Port
  final containerInShip = SpatialRelationship(
    subjectId: 'container-456',
    relation: SpatialRelationType.inside,
    objectId: 'ship-hold-02',
  );
  print('  Port: ${containerInShip.subjectId} ${containerInShip.relation.name} ${containerInShip.objectId}');

  // Demo 10: Placement request with semantic relation
  print('\n=== Demo 10: Semantic Placement Request ===');
  final placementRequest = PlacementRequest(
    subjectId: 'new-box',
    relation: SpatialRelationType.on,
    targetId: 'shelf-01',
    preferredAnchorId: 'top-surface',
    createRelationship: true,
  );
  print('  Place "${placementRequest.subjectId}"');
  print('  Relation: ${placementRequest.relation.name}');
  print('  Target: ${placementRequest.targetId}');
  print('  Anchor: ${placementRequest.preferredAnchorId}');
  print('  Auto-create relationship: ${placementRequest.createRelationship}');

  print('\n=== Demo Complete ===');
  print('Step 12 successfully demonstrates semantic spatial relations!');
}
