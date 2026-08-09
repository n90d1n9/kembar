import 'package:vector_math/vector_math_64.dart';

import '../digital_twin_core.dart';

/// Demonstrates Step 11: Neighbor-Aware Packing & Placement.
///
/// This example shows how the system moves from:
/// "Can this object physically fit here?"
/// to:
/// "Given everything already around it, where would a human/operator logically put it?"
///
/// Key features demonstrated:
/// - Neighbor analysis (finding nearby entities and their relationships)
/// - Neighbor-aware candidate generation (placing objects adjacent to existing ones)
/// - Pattern-based scoring (alignment, spacing, orientation)
/// - Domain-agnostic behavior (works for warehouse, restaurant, port, etc.)
void main() async {
  print('=== Step 11: Neighbor-Aware Packing & Placement Demo ===\n');

  // Create a spatial world
  final world = SpatialWorld();

  // Example 1: Warehouse shelf packing
  print('--- Example 1: Warehouse Shelf Packing ---\n');

  // Create a shelf surface
  final shelfId = 'shelf-001';
  world.addComponent(
    shelfId,
    SpatialComponent(
      id: shelfId,
      localBounds: const Bounds(min: Vector3(-2, 0, -0.5), max: Vector3(2, 0.1, 0.5)),
      position: Vector3(0, 0.5, 0),
      rotation: Vector3.zero(),
      surface: PlacementSurface(
        id: 'shelf-surface-001',
        bounds: const Bounds(min: Vector3(-2, 0.05, -0.5), max: Vector3(2, 0.1, 0.5)),
      ),
    ),
  );
  print('✓ Created shelf: $shelfId');

  // Place cargo boxes in a row [A][B][C]
  final cargoIds = <String>[];
  for (var i = 0; i < 3; i++) {
    final cargoId = 'cargo-${String.fromCharCode(65 + i)}'; // A, B, C
    final x = -1.0 + (i * 1.0); // Positions: -1.0, 0.0, 1.0

    world.addComponent(
      cargoId,
      SpatialComponent(
        id: cargoId,
        localBounds: const Bounds(min: Vector3(-0.4, 0, -0.3), max: Vector3(0.4, 0.5, 0.3)),
        position: Vector3(x, 0.75, 0),
        rotation: Vector3.zero(),
      ),
    );
    cargoIds.add(cargoId);
    print('✓ Placed cargo $cargoId at x=$x');
  }

  // Analyze neighbors for cargo-C
  final analyzer = const NeighborAnalyzer(nearbyDistance: 2.0);
  final neighbors = analyzer.findNeighbors('cargo-C', world);

  print('\n📊 Neighbors of cargo-C:');
  for (final neighbor in neighbors) {
    print('   - ${neighbor.entityId}: ${neighbor.direction} (distance: ${neighbor.distance.toStringAsFixed(3)})');
  }

  // Now try to place cargo-D using neighbor-aware placement
  final cargoD = SpatialComponent(
    id: 'cargo-D',
    localBounds: const Bounds(min: Vector3(-0.4, 0, -0.3), max: Vector3(0.4, 0.5, 0.3)),
    position: Vector3(2.5, 0.75, 0), // User's initial guess (far right)
    rotation: Vector3.zero(),
  );

  world.addComponent('cargo-D', cargoD);

  // Create placement request
  final request = PlacementRequest(
    subjectId: 'cargo-D',
    relation: SpatialRelation.on,
    targetId: shelfId,
    preferredPosition: Vector3(2.5, 0.75, 0),
  );

  // Create engine with neighbor-aware generator and scorer
  final engine = PlacementEngine(
    candidateGenerator: CompositeCandidateGenerator.defaultSet(neighborSpacing: 0.05),
    constraints: [
      CollisionConstraint(),
      ClearanceConstraint(clearance: 0.01),
      SurfaceFitConstraint(),
      SupportConstraint(),
    ],
    scorer: CompositePlacementScorer.defaultSet(
      desiredSpacing: 0.05,
      preferAlignment: true,
      preferSameOrientation: true,
    ),
  );

  final result = engine.findPlacement(request, world);

  print('\n🎯 Placement Result for cargo-D:');
  if (result.valid) {
    print('   ✓ Valid placement found!');
    print('   Position: (${result.position.x.toStringAsFixed(3)}, ${result.position.y.toStringAsFixed(3)}, ${result.position.z.toStringAsFixed(3)})');
    print('   Score: ${result.score.toStringAsFixed(3)}');
    print('   Expected: Should snap to right of cargo-C at x≈2.0');

    // Verify it's in the expected position (right of cargo-C)
    final expectedX = 2.0; // cargo-C is at x=1.0, half-width=0.4, spacing=0.05, cargo-D half-width=0.4
    final actualX = result.position.x;
    final diff = (actualX - expectedX).abs();

    if (diff < 0.1) {
      print('   ✅ SUCCESS: Cargo-D placed adjacent to cargo-C with proper alignment!');
    } else {
      print('   ⚠️  Warning: Placement not perfectly aligned (diff=$diff)');
    }
  } else {
    print('   ✗ No valid placement found');
    print('   Reasons: ${result.reasons.join(", ")}');
  }

  // Example 2: Restaurant table seating
  print('\n\n--- Example 2: Restaurant Table Seating ---\n');

  final world2 = SpatialWorld();

  // Create a table
  final tableId = 'table-001';
  world2.addComponent(
    tableId,
    SpatialComponent(
      id: tableId,
      localBounds: const Bounds(min: Vector3(-0.6, 0, -0.6), max: Vector3(0.6, 0.75, 0.6)),
      position: Vector3(0, 0.375, 0),
      rotation: Vector3.zero(),
      anchors: [
        SpatialAnchor(id: 'seat-1', position: Vector3(0, 0, -0.8), type: 'seat'),
        SpatialAnchor(id: 'seat-2', position: Vector3(0.8, 0, 0), type: 'seat'),
        SpatialAnchor(id: 'seat-3', position: Vector3(0, 0, 0.8), type: 'seat'),
        SpatialAnchor(id: 'seat-4', position: Vector3(-0.8, 0, 0), type: 'seat'),
      ],
    ),
  );
  print('✓ Created table: $tableId with 4 seat anchors');

  // Place chairs at anchors
  for (var i = 0; i < 3; i++) {
    final chairId = 'chair-${i + 1}';
    final anchor = world2.getComponent(tableId)?.anchors[i];
    if (anchor != null) {
      world2.addComponent(
        chairId,
        SpatialComponent(
          id: chairId,
          localBounds: const Bounds(min: Vector3(-0.25, 0, -0.25), max: Vector3(0.25, 0.45, 0.25)),
          position: anchor.position + Vector3(0, 0.225, 0),
          rotation: Vector3(0, i * 90 * (Math.pi / 180), 0),
        ),
      );
      print('✓ Placed $chairId at anchor ${anchor.id}');
    }
  }

  // Try to place chair-4 using neighbor-aware placement
  final chair4 = SpatialComponent(
    id: 'chair-4',
    localBounds: const Bounds(min: Vector3(-0.25, 0, -0.25), max: Vector3(0.25, 0.45, 0.25)),
    position: Vector3(0, 0.225, 1.5), // User's initial guess (too far)
    rotation: Vector3(0, Math.pi, 0),
  );

  world2.addComponent('chair-4', chair4);

  final request2 = PlacementRequest(
    subjectId: 'chair-4',
    relation: SpatialRelation.adjacent,
    targetId: tableId,
    preferredPosition: Vector3(0, 0.225, 1.5),
  );

  final engine2 = PlacementEngine(
    candidateGenerator: CompositeCandidateGenerator.defaultSet(neighborSpacing: 0.1),
    constraints: [
      CollisionConstraint(),
      ClearanceConstraint(clearance: 0.05),
    ],
    scorer: CompositePlacementScorer.defaultSet(
      desiredSpacing: 0.1,
      preferAlignment: true,
      preferSameOrientation: false, // Chairs face table, not same direction
    ),
  );

  final result2 = engine2.findPlacement(request2, world2);

  print('\n🎯 Placement Result for chair-4:');
  if (result2.valid) {
    print('   ✓ Valid placement found!');
    print('   Position: (${result2.position.x.toStringAsFixed(3)}, ${result2.position.y.toStringAsFixed(3)}, ${result2.position.z.toStringAsFixed(3)})');
    print('   Score: ${result2.score.toStringAsFixed(3)}');
    print('   Expected: Should snap to remaining anchor at (0, 0, 0.8)');

    // Check if it's near the expected anchor position
    final expectedZ = 0.8;
    final actualZ = result2.position.z;
    final diffZ = (actualZ - expectedZ).abs();

    if (diffZ < 0.2) {
      print('   ✅ SUCCESS: Chair-4 placed at remaining seat position!');
    } else {
      print('   ⚠️  Warning: Chair not at expected position (diffZ=$diffZ)');
    }
  } else {
    print('   ✗ No valid placement found');
    print('   Reasons: ${result2.reasons.join(", ")}');
  }

  // Example 3: Stacking demonstration
  print('\n\n--- Example 3: Vertical Stacking ---\n');

  final world3 = SpatialWorld();

  // Place box-A on floor
  world3.addComponent(
    'box-A',
    SpatialComponent(
      id: 'box-A',
      localBounds: const Bounds(min: Vector3(-0.3, 0, -0.3), max: Vector3(0.3, 0.3, 0.3)),
      position: Vector3(0, 0.15, 0),
      rotation: Vector3.zero(),
    ),
  );
  print('✓ Placed box-A on floor');

  // Try to stack box-B on top of box-A
  final boxB = SpatialComponent(
    id: 'box-B',
    localBounds: const Bounds(min: Vector3(-0.3, 0, -0.3), max: Vector3(0.3, 0.3, 0.3)),
    position: Vector3(0.5, 0.15, 0), // User's initial guess (beside, not on top)
    rotation: Vector3.zero(),
  );

  world3.addComponent('box-B', boxB);

  final request3 = PlacementRequest(
    subjectId: 'box-B',
    relation: SpatialRelation.above,
    targetId: 'box-A',
    preferredPosition: Vector3(0.5, 0.15, 0),
  );

  final engine3 = PlacementEngine(
    candidateGenerator: CompositeCandidateGenerator.defaultSet(neighborSpacing: 0.01),
    constraints: [
      CollisionConstraint(),
      ClearanceConstraint(clearance: 0.01),
      SupportConstraint(),
    ],
    scorer: NeighborPatternScorer(
      desiredSpacing: 0.01,
      preferAlignment: true,
      preferSameOrientation: true,
    ),
  );

  final result3 = engine3.findPlacement(request3, world3);

  print('\n🎯 Placement Result for box-B (stacking):');
  if (result3.valid) {
    print('   ✓ Valid placement found!');
    print('   Position: (${result3.position.x.toStringAsFixed(3)}, ${result3.position.y.toStringAsFixed(3)}, ${result3.position.z.toStringAsFixed(3)})');
    print('   Expected Y: ≈0.45 (on top of box-A which is 0.3m tall)');

    if (result3.position.y > 0.4 && result3.position.y < 0.5) {
      print('   ✅ SUCCESS: Box-B stacked on top of box-A!');
    } else {
      print('   ⚠️  Warning: Box-B not properly stacked (y=${result3.position.y})');
    }
  } else {
    print('   ✗ No valid placement found');
    print('   Reasons: ${result3.reasons.join(", ")}');
  }

  print('\n=== Demo Complete ===');
  print('\nKey Takeaways:');
  print('1. Neighbor-aware placement produces human-like arrangements');
  print('2. System prefers aligned, evenly-spaced configurations');
  print('3. Works across domains (warehouse, restaurant, stacking) without domain-specific code');
  print('4. Candidate generation + constraints + scoring = intelligent placement');
}
