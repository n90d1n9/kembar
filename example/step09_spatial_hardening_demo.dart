import 'package:vector_math/vector_math_64.dart';

import '../lib/domain/twin/twin_entity.dart';
import '../lib/domain/twin/twin_state.dart';
import '../lib/domain/spatial/spatial_component.dart';
import '../lib/domain/spatial/collision_shape.dart';
import '../lib/domain/spatial/bounds.dart';
import '../lib/domain/spatial/placement_surface.dart';
import '../lib/domain/spatial/placement_request.dart';
import '../lib/domain/spatial/spatial_relation.dart';
import '../lib/application/spatial/spatial_world.dart';
import '../lib/application/spatial/spatial_world_builder.dart';
import '../lib/application/spatial/placement_engine.dart';
import '../lib/application/spatial/surface_placement_strategy.dart';
import '../lib/application/spatial/collision_detector.dart';
import '../lib/application/spatial/constraints/collision_constraint.dart';
import '../lib/application/spatial/constraints/clearance_constraint.dart';
import '../lib/application/spatial/constraints/surface_fit_constraint.dart';
import '../lib/application/spatial/constraints/support_constraint.dart';

void main() {
  print('=== Step 09: Spatial Layer Hardening Demo ===\n');

  // 1. Create twin entities with spatial components
  print('1. Creating twin entities with SpatialComponents...\n');

  // Create a shelf entity
  final shelf = TwinEntity(
    id: 'shelf-001',
    type: 'storage',
    components: {
      SpatialComponent: SpatialComponent(
        position: Vector3(0, 0, 0),
        collisionShape: const BoxCollisionShape(size: Vector3(2, 1, 1)),
        localBounds: const Bounds(min: Vector3(-1, -0.5, -0.5), max: Vector3(1, 0.5, 0.5)),
        surfaces: [
          const PlacementSurface(
            id: 'shelf-top',
            hostEntityId: 'shelf-001',
            type: PlacementSurfaceType.horizontal,
            bounds: Bounds(min: Vector3(-1, 0.5, -0.5), max: Vector3(1, 0.5, 0.5)),
            height: 0.5,
          ),
        ],
      ),
    },
  );

  // Create a cargo entity
  final cargo = TwinEntity(
    id: 'cargo-001',
    type: 'container',
    components: {
      SpatialComponent: SpatialComponent(
        position: Vector3(5, 2, 5), // Starting position above shelf
        collisionShape: const BoxCollisionShape(size: Vector3(0.5, 0.5, 0.5)),
        localBounds: const Bounds(min: Vector3(-0.25, -0.25, -0.25), max: Vector3(0.25, 0.25, 0.25)),
      ),
    },
  );

  // Create another cargo that's already on the shelf (to test collision)
  final cargo2 = TwinEntity(
    id: 'cargo-002',
    type: 'container',
    components: {
      SpatialComponent: SpatialComponent(
        position: Vector3(0, 1, 0), // Already placed on shelf
        collisionShape: const BoxCollisionShape(size: Vector3(0.5, 0.5, 0.5)),
        localBounds: const Bounds(min: Vector3(-0.25, -0.25, -0.25), max: Vector3(0.25, 0.25, 0.25)),
      ),
    },
  );

  print('✓ Created shelf: ${shelf.id}');
  print('✓ Created cargo: ${cargo.id}');
  print('✓ Created cargo2: ${cargo2.id}\n');

  // 2. Create TwinState (source of truth)
  print('2. Creating TwinState (source of truth)...\n');
  final state = TwinState(
    entities: {
      shelf.id: shelf,
      cargo.id: cargo,
      cargo2.id: cargo2,
    },
  );
  print('✓ TwinState created with ${state.entities.length} entities\n');

  // 3. Build SpatialWorld from TwinState
  print('3. Building SpatialWorld from TwinState...\n');
  final builder = const SpatialWorldBuilder();
  final world = builder.build(state);
  print('✓ SpatialWorld built with ${world.entityIds.length} spatial entities');
  print('  Entity IDs: ${world.entityIds}\n');

  // 4. Configure placement engine with constraints
  print('4. Configuring PlacementEngine with constraints...\n');
  final collisionDetector = const CollisionDetector();
  final placementEngine = PlacementEngine(
    surfaceStrategy: const SurfacePlacementStrategy(),
    constraints: [
      CollisionConstraint(collisionDetector),
      ClearanceConstraint(collisionDetector),
      const SurfaceFitConstraint(),
      const SupportConstraint(),
    ],
  );
  print('✓ PlacementEngine configured with 4 constraints:');
  print('  - CollisionConstraint');
  print('  - ClearanceConstraint');
  print('  - SurfaceFitConstraint');
  print('  - SupportConstraint\n');

  // 5. Test Case 1: Valid placement on empty part of shelf
  print('5. Test Case 1: Valid placement on empty part of shelf\n');
  final request1 = PlacementRequest(
    subjectId: cargo.id,
    targetId: shelf.id,
    relation: SpatialRelationType.on,
    clearance: 0.1,
    preferredPosition: Vector3(0.8, 1, 0), // Right side of shelf (empty)
  );

  final result1 = placementEngine.findPlacement(request1, world);
  print('Result: ${result1.valid ? "✓ VALID" : "✗ INVALID"}');
  if (result1.valid) {
    print('  Position: ${result1.position}');
    print('  Score: ${result1.score.toStringAsFixed(3)}');
  }
  print('  Reasons: ${result1.reasons}\n');

  // 6. Test Case 2: Invalid placement due to collision
  print('6. Test Case 2: Invalid placement due to collision\n');
  final request2 = PlacementRequest(
    subjectId: cargo.id,
    targetId: shelf.id,
    relation: SpatialRelationType.on,
    clearance: 0.1,
    preferredPosition: Vector3(0, 1, 0), // Where cargo2 already is
  );

  final result2 = placementEngine.findPlacement(request2, world);
  print('Result: ${result2.valid ? "✓ VALID" : "✗ INVALID"}');
  if (!result2.valid) {
    print('  Reason: ${result2.reasons.first}');
  }
  print('  Reasons: ${result2.reasons}\n');

  // 7. Test Case 3: Unsupported placement (floating)
  print('7. Test Case 3: Testing support constraint directly\n');
  // This would be caught by the SupportConstraint when candidate is generated
  // The surface strategy should generate candidates at the correct height
  print('  Note: SurfacePlacementStrategy generates candidates at surface height,');
  print('  so unsupported placements are filtered during candidate generation.\n');

  // 8. Demonstrate domain-agnostic architecture
  print('8. Demonstrating domain-agnostic architecture...\n');
  
  // Create a restaurant table (different domain, same spatial component)
  final restaurantTable = TwinEntity(
    id: 'table-001',
    type: 'furniture',
    components: {
      SpatialComponent: SpatialComponent(
        position: Vector3(10, 0, 10),
        collisionShape: const BoxCollisionShape(size: Vector3(1.5, 0.8, 1.5)),
        localBounds: const Bounds(min: Vector3(-0.75, -0.4, -0.75), max: Vector3(0.75, 0.4, 0.75)),
        surfaces: [
          const PlacementSurface(
            id: 'table-top',
            hostEntityId: 'table-001',
            type: PlacementSurfaceType.horizontal,
            bounds: Bounds(min: Vector3(-0.75, 0.4, -0.75), max: Vector3(0.75, 0.4, 0.75)),
            height: 0.8,
          ),
        ],
      ),
    },
  );

  // Create a chair (can be placed on floor or at table)
  final chair = TwinEntity(
    id: 'chair-001',
    type: 'furniture',
    components: {
      SpatialComponent: SpatialComponent(
        position: Vector3(12, 2, 12),
        collisionShape: const BoxCollisionShape(size: Vector3(0.5, 0.8, 0.5)),
        localBounds: const Bounds(min: Vector3(-0.25, -0.4, -0.25), max: Vector3(0.25, 0.4, 0.25)),
      ),
    },
  );

  print('✓ Created restaurant table: ${restaurantTable.id} (type: ${restaurantTable.type})');
  print('✓ Created chair: ${chair.id} (type: ${chair.type})');
  print('  Both use the same SpatialComponent structure!');
  print('  The PlacementEngine knows nothing about "restaurants" or "warehouses".\n');

  // 9. Show the architecture flow
  print('9. Architecture Flow:\n');
  print('   TwinState (source of truth)');
  print('         ↓');
  print('   SpatialWorldBuilder');
  print('         ↓');
  print('   SpatialWorld (derived representation)');
  print('         ↓');
  print('   PlacementEngine');
  print('         ↓');
  print('   Constraints (Collision, Clearance, Fit, Support)');
  print('         ↓');
  print('   PlacementResult');
  print('         ↓');
  print('   TwinCommand → TwinState update → Rebuild SpatialWorld\n');

  print('=== Demo Complete ===');
  print('\nKey Achievements:');
  print('✓ SpatialComponent as reusable domain-level abstraction');
  print('✓ TwinEntity with typed components (not domain-specific fields)');
  print('✓ TwinState as single source of truth');
  print('✓ SpatialWorld as derived representation (not authoritative)');
  print('✓ SpatialWorldBuilder connects TwinState → SpatialWorld');
  print('✓ PlacementEngine uses pluggable constraints');
  print('✓ Collision vs Clearance separation');
  print('✓ Domain-agnostic architecture (works for any domain)');
}
