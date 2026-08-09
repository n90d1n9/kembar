# Step 09 Implementation: Spatial Layer Hardening

## Overview

Step 09 implements the critical architectural improvement of connecting the spatial layer to the actual Twin state, making `SpatialWorld` a **derived spatial projection** of the digital twin state rather than a manually constructed separate system.

## Key Architecture Changes

### Before (Step 08)
```
SpatialWorld (manually constructed, separate from twin state)
    ↓
PlacementEngine
```

### After (Step 09)
```
TwinState (source of truth)
   │
   └── entities
        └── SpatialComponent
             │
             ▼
      SpatialWorldBuilder
             │
             ▼
      SpatialWorld (derived/query representation)
             │
             ▼
      PlacementEngine
             │
             ▼
      PlacementResult
             │
             ▼
      TwinCommand
             │
             ▼
      TwinState updated (loop closes)
```

## Files Created/Modified

### New Domain Files

1. **`lib/domain/twin/twin_entity.dart`**
   - Generic entity with typed components
   - Component-based architecture (not domain-specific fields)
   - Methods: `component<T>()`, `withComponent<T>()`, `hasComponent<T>()`

2. **`lib/domain/twin/twin_state.dart`**
   - Complete state of digital twin at a point in time
   - Source of truth for entire system
   - Methods: `entity()`, `withEntity()`, `entitiesWithComponent<T>()`

3. **`lib/domain/spatial/spatial_component.dart`**
   - Reusable spatial component for any entity type
   - Contains: position, rotation, scale, collisionShape, bounds, surfaces, anchors
   - Domain-agnostic (works for port, parking, restaurant, warehouse, etc.)

### Updated Domain Files

4. **`lib/domain/spatial/bounds.dart`**
   - Fixed intersection logic to use strict inequality (`<` and `>`)
   - Touching boxes are NOT considered intersecting (important for support)
   - Added documentation explaining the distinction

5. **`lib/application/spatial/collision_detector.dart`**
   - Separated collision detection from clearance checking
   - Two distinct methods: `intersects()` and `violatesClearance()`
   - Important for constraint engine design

### New Application Files

6. **`lib/application/spatial/spatial_world_builder.dart`**
   - Critical connection between TwinState and SpatialWorld
   - Builds SpatialWorld by extracting SpatialComponents from entities
   - Methods: `build()`, `buildByType()`, `buildWithComponents<T>()`

7. **`lib/application/spatial/spatial_world.dart`** (updated)
   - Changed from `Map<String, dynamic>` to `Map<String, SpatialComponent>`
   - Now strongly typed
   - Added convenience methods: `all`, `allSurfaces`, `hasEntity()`, `entityIds`

8. **`lib/application/spatial/constraints/placement_constraint.dart`**
   - Abstract interface for pluggable constraints
   - Supports hard vs soft constraints (via `isHard` getter)
   - Returns `PlacementConstraintResult` with satisfaction status and reason

9. **`lib/application/spatial/constraints/collision_constraint.dart`**
   - Checks for collisions with other entities
   - Uses CollisionDetector
   - Returns detailed failure reasons

10. **`lib/application/spatial/constraints/clearance_constraint.dart`**
    - Checks for clearance violations (safety margin)
    - Separate from collision constraint
    - Configurable clearance distance

11. **`lib/application/spatial/constraints/surface_fit_constraint.dart`**
    - Checks if object fits within surface bounds
    - Validates X and Z dimensions

12. **`lib/application/spatial/constraints/support_constraint.dart`**
    - Checks if object is properly supported by surface
    - Validates Y position matches surface height (with tolerance)

### Updated Application Files

13. **`lib/application/spatial/placement_engine.dart`**
    - Refactored to use constraint-based approach
    - Removed hardcoded collision checks
    - Now accepts `List<PlacementConstraint>` instead of individual detectors
    - Much cleaner and more extensible

### Example File

14. **`example/step09_spatial_hardening_demo.dart`**
    - Comprehensive demonstration of new architecture
    - Shows TwinState → SpatialWorld flow
    - Tests valid and invalid placements
    - Demonstrates domain-agnostic design with warehouse and restaurant examples

## Key Architectural Improvements

### 1. Single Source of Truth
- **TwinState** is now the authoritative source
- **SpatialWorld** is derived, not authoritative
- Prevents state divergence

### 2. Component-Based Entity Design
- Entities have typed components, not fixed fields
- Same `SpatialComponent` works for any domain
- True platform-agnostic architecture

### 3. Pluggable Constraint System
- Constraints are independent, testable units
- Easy to add new constraints without modifying engine
- Supports hard vs soft constraints (future enhancement)

### 4. Separation of Concerns
- Collision ≠ Clearance (different concepts)
- Builder pattern for world construction
- Engine only handles evaluation, not state management

### 5. Domain Agnosticism
The PlacementEngine knows nothing about:
- Warehouses
- Restaurants  
- Ports
- Parking lots
- Chairs, tables, cargo, shelves

It only understands:
- `SpatialComponent`
- `PlacementRequest`
- `PlacementConstraint`

Domain specificity comes from data/configuration, not code.

## Test Cases Covered

1. **Valid placement** - Cargo on empty shelf space ✓
2. **Collision detection** - Cargo cannot occupy same space as another ✓
3. **Support validation** - Surface strategy generates candidates at correct height ✓
4. **Cross-domain compatibility** - Same system works for warehouse and restaurant ✓

## Usage Example

```dart
// 1. Create entities with spatial components
final shelf = TwinEntity(
  id: 'shelf-001',
  type: 'storage',
  components: {
    SpatialComponent: SpatialComponent(
      position: Vector3(0, 0, 0),
      collisionShape: BoxCollisionShape(size: Vector3(2, 1, 1)),
      // ...
    ),
  },
);

// 2. Create TwinState (source of truth)
final state = TwinState(entities: {'shelf-001': shelf});

// 3. Build SpatialWorld from state
final world = SpatialWorldBuilder().build(state);

// 4. Configure engine with constraints
final engine = PlacementEngine(
  surfaceStrategy: SurfacePlacementStrategy(),
  constraints: [
    CollisionConstraint(detector),
    ClearanceConstraint(detector),
    SurfaceFitConstraint(),
    SupportConstraint(),
  ],
);

// 5. Find valid placement
final result = engine.findPlacement(request, world);
```

## Next Steps (Step 10+)

- Candidate sampling improvements (grid, anchors, edges)
- Intelligent snapping behavior
- Soft constraint scoring system
- Additional constraint types (capacity, accessibility, etc.)
- Integration with simulation layer
- Real-time interaction handling

## Conclusion

Step 09 establishes the proper architectural foundation where:
- TwinState is the single source of truth
- SpatialWorld is a derived projection
- PlacementEngine uses pluggable constraints
- The system is truly domain-agnostic

This enables building digital twins for ANY domain (port, parking, restaurant, warehouse, factory, etc.) using the same spatial reasoning engine.
