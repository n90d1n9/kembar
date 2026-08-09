import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:digital_twin_core/digital_twin_core.dart';

/// Demonstration of Step 10: Candidate Sampling & Intelligent Snapping
///
/// This example shows how the placement system now generates multiple
/// candidate positions, validates them through constraints, and selects
/// the best one using scoring - making placement feel intelligent rather
/// than just collision-free.
void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('Step 10: Candidate Sampling & Intelligent Snapping Demo');
  print('═══════════════════════════════════════════════════════════\n');

  // Create a simple warehouse scenario
  final twinState = _createWarehouseScenario();
  print('✓ Created warehouse digital twin\n');

  // Build spatial world from twin state
  final builder = SpatialWorldBuilder();
  final spatialWorld = builder.build(twinState);
  print('✓ Built spatial world with ${spatialWorld.components.length} components\n');

  // Configure the placement engine with candidate generation and scoring
  final candidateGenerator = CompositeCandidateGenerator(
    generators: [
      const SurfaceCandidateGenerator(),
      const AnchorCandidateGenerator(),
    ],
  );

  final scorer = CompositePlacementScorer(
    scorers: [
      const DistanceScorer(),
      const AnchorPreferenceScorer(),
    ],
  );

  final engine = PlacementEngine(
    candidateGenerator: candidateGenerator,
    constraints: [
      CollisionConstraint(const CollisionDetector()),
      ClearanceConstraint(const CollisionDetector(), clearance: 0.1),
      const SurfaceFitConstraint(),
      const SupportConstraint(),
    ],
    scorer: scorer,
  );

  print('═══════════════════════════════════════════════════════════');
  print('Test 1: Placing a box on shelf with preferred position');
  print('═══════════════════════════════════════════════════════════\n');

  final boxId = 'box-003';
  final shelfId = 'shelf-A';

  // User clicks near the right side of the shelf
  final preferredPosition = vm.Vector3(4.5, 1.75, 0.5);

  final request = PlacementRequest(
    subjectId: boxId,
    targetId: shelfId,
    relation: SpatialRelationType.on,
    preferredPosition: preferredPosition,
  );

  print('User wants to place $boxId on $shelfId');
  print('Preferred position: ${preferredPosition.toStringAsFixed(2)}\n');

  // Generate candidates
  final candidates = candidateGenerator.generate(request, spatialWorld);
  print('Generated ${candidates.length} candidate positions:');
  
  for (var i = 0; i < candidates.length; i++) {
    final c = candidates[i];
    print('  ${i + 1}. ${c.position.toStringAsFixed(2)} [${c.source}]');
  }
  print('');

  // Find best placement
  final result = engine.findPlacement(request, spatialWorld);

  if (result.valid) {
    print('✅ SUCCESS: Found valid placement!');
    print('   Position: ${result.position!.toStringAsFixed(2)}');
    print('   Score: ${result.score.toStringAsFixed(3)}');
    print('   Surface: ${result.surfaceId}');
    
    // Show which candidate was selected
    final selectedIdx = candidates.indexWhere(
      (c) => c.position.distanceTo(result.position!) < 0.001,
    );
    if (selectedIdx >= 0) {
      print('   Source: ${candidates[selectedIdx].source}');
    }
  } else {
    print('❌ FAILED: ${result.reasons.first}');
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('Test 2: Placing chair at table anchor point');
  print('═══════════════════════════════════════════════════════════\n');

  final chairId = 'chair-001';
  final tableId = 'table-001';

  final chairRequest = PlacementRequest(
    subjectId: chairId,
    targetId: tableId,
    relation: SpatialRelationType.adjacent,
  );

  print('Placing $chairId at $tableId (using anchors)\n');

  final chairCandidates = candidateGenerator.generate(chairRequest, spatialWorld);
  print('Generated ${chairCandidates.length} anchor-based candidates:');
  
  for (var i = 0; i < chairCandidates.length; i++) {
    final c = chairCandidates[i];
    if (c.anchorId != null) {
      print('  ${i + 1}. ${c.position.toStringAsFixed(2)} [anchor: ${c.anchorId}]');
    }
  }
  print('');

  final chairResult = engine.findPlacement(chairRequest, spatialWorld);

  if (chairResult.valid) {
    print('✅ SUCCESS: Chair placed at optimal position!');
    print('   Position: ${chairResult.position!.toStringAsFixed(2)}');
    print('   Score: ${chairResult.score.toStringAsFixed(3)}');
    print('   Anchor: ${chairResult.anchorId}');
  } else {
    print('❌ FAILED: ${chairResult.reasons.first}');
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('Test 3: Comparing candidate scores');
  print('═══════════════════════════════════════════════════════════\n');

  // Show detailed scoring breakdown
  print('Detailed scoring for all valid candidates:\n');
  
  var validCount = 0;
  for (final candidate in candidates) {
    // Check constraints
    final evaluations = engine.constraints.map(
      (constraint) => constraint.evaluate(candidate, request, spatialWorld),
    );

    final failures = evaluations.where((result) => !result.satisfied).toList();

    if (failures.isNotEmpty) {
      continue; // Skip invalid candidates
    }

    validCount++;
    final score = scorer.score(candidate, request, spatialWorld);
    
    print('Candidate ${validCount}:');
    print('  Position: ${candidate.position.toStringAsFixed(2)}');
    print('  Source: ${candidate.source}');
    print('  Score: ${score.toStringAsFixed(3)}');
    
    // Breakdown score components
    final distanceScore = const DistanceScorer().score(candidate, request, spatialWorld);
    final anchorScore = const AnchorPreferenceScorer().score(candidate, request, spatialWorld);
    print('    - Distance: ${distanceScore.toStringAsFixed(3)}');
    print('    - Anchor: ${anchorScore.toStringAsFixed(3)}');
    print('');
  }

  print('═══════════════════════════════════════════════════════════');
  print('Demo Complete!');
  print('═══════════════════════════════════════════════════════════');
  print('\nKey achievements of Step 10:');
  print('✓ Multiple candidate generation (surface, grid, anchors)');
  print('✓ Usable bounds calculation (prevents overhang)');
  print('✓ Local grid sampling around user intent');
  print('✓ Edge and corner candidate generation');
  print('✓ Composite scoring system');
  print('✓ Source tracking for debugging');
  print('✓ Domain-agnostic architecture\n');
}

TwinState _createWarehouseScenario() {
  final entities = <TwinEntity>[];

  // Create a shelf unit
  final shelf = TwinEntity(
    id: 'shelf-A',
    name: 'Shelf Unit A',
    components: {
      'spatial': SpatialComponent(
        id: 'shelf-A',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(5, 2, 1),
        ),
        position: vm.Vector3(0, 0, 0),
        rotation: vm.Vector3(0, 0, 0),
        surfaces: [
          PlacementSurface(
            id: 'shelf-A-top',
            type: PlacementSurfaceType.horizontal,
            bounds: Bounds(
              min: vm.Vector3(0, 1.5, 0),
              max: vm.Vector3(5, 1.5, 1),
            ),
            height: 1.5,
          ),
        ],
        anchors: [],
      ),
    },
  );

  // Create some boxes already on the shelf
  final box1 = TwinEntity(
    id: 'box-001',
    name: 'Box 1',
    components: {
      'spatial': SpatialComponent(
        id: 'box-001',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(0.5, 0.5, 0.5),
        ),
        position: vm.Vector3(0.5, 1.75, 0.25),
        rotation: vm.Vector3(0, 0, 0),
      ),
    },
  );

  final box2 = TwinEntity(
    id: 'box-002',
    name: 'Box 2',
    components: {
      'spatial': SpatialComponent(
        id: 'box-002',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(0.5, 0.5, 0.5),
        ),
        position: vm.Vector3(1.5, 1.75, 0.25),
        rotation: vm.Vector3(0, 0, 0),
      ),
    },
  );

  // Create a new box to place
  final box3 = TwinEntity(
    id: 'box-003',
    name: 'Box 3',
    components: {
      'spatial': SpatialComponent(
        id: 'box-003',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(0.5, 0.5, 0.5),
        ),
        position: vm.Vector3(-1, 0, 0), // Not yet placed
        rotation: vm.Vector3(0, 0, 0),
      ),
    },
  );

  // Create a restaurant table with chair anchors
  final table = TwinEntity(
    id: 'table-001',
    name: 'Restaurant Table',
    components: {
      'spatial': SpatialComponent(
        id: 'table-001',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(1.5, 0.75, 1.5),
        ),
        position: vm.Vector3(10, 0, 0),
        rotation: vm.Vector3(0, 0, 0),
        surfaces: [],
        anchors: [
          SpatialAnchor(
            id: 'seat-north',
            localPosition: vm.Vector3(0.75, 0, 1.5),
            rotation: vm.Vector3(0, 3.14159 / 2, 0),
          ),
          SpatialAnchor(
            id: 'seat-south',
            localPosition: vm.Vector3(0.75, 0, -0.5),
            rotation: vm.Vector3(0, -3.14159 / 2, 0),
          ),
          SpatialAnchor(
            id: 'seat-east',
            localPosition: vm.Vector3(1.5, 0, 0.75),
            rotation: vm.Vector3(0, 3.14159, 0),
          ),
          SpatialAnchor(
            id: 'seat-west',
            localPosition: vm.Vector3(-0.5, 0, 0.75),
            rotation: vm.Vector3(0, 0, 0),
          ),
        ],
      ),
    },
  );

  // Create a chair
  final chair = TwinEntity(
    id: 'chair-001',
    name: 'Chair',
    components: {
      'spatial': SpatialComponent(
        id: 'chair-001',
        localBounds: Bounds(
          min: vm.Vector3(0, 0, 0),
          max: vm.Vector3(0.5, 0.8, 0.5),
        ),
        position: vm.Vector3(-1, 0, 0),
        rotation: vm.Vector3(0, 0, 0),
      ),
    },
  );

  entities.addAll([shelf, box1, box2, box3, table, chair]);

  return TwinState(
    id: 'warehouse-scenario-001',
    name: 'Warehouse Scenario',
    timestamp: DateTime.now(),
    entities: entities,
  );
}
