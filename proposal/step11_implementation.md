# Step 11 Implementation: Neighbor-Aware Packing & Placement

## Overview

Step 11 implements **Neighbor-Aware Packing & Placement**, transforming the system from asking:

> "Can this object physically fit here?"

to:

> **"Given everything already around it, where would a human/operator logically put it?"**

This is critical for supporting warehouses, restaurants, factories, offices, retail, logistics, and construction domains with human-like placement behavior.

## Architecture

### Pipeline Flow

```
PlacementRequest
       │
       ▼
Candidate Generation (Surface + Anchor + Neighbor)
       │
       ▼
 ┌───────────────────┐
 │ Neighbor Analyzer │ ← New!
 └─────────┬─────────┘
           │
           ▼
 Constraint Evaluation
           │
           ▼
 Candidate Scoring (Proximity + Alignment + Orientation + Spacing)
           │
           ▼
     Best Placement
```

## New Components

### 1. Spatial Neighbor Model

**File:** `lib/application/spatial/neighbors/spatial_neighbor.dart`

Defines semantic spatial relationships:

```dart
enum NeighborDirection {
  left, right, front, back, above, below, overlapping, nearby,
}

class SpatialNeighbor {
  final String entityId;
  final NeighborDirection direction;
  final double distance;        // Bounds-to-bounds distance
  final Vector3 offset;
}
```

### 2. Neighbor Analyzer

**File:** `lib/application/spatial/neighbors/neighbor_analyzer.dart`

Analyzes spatial relationships between entities:

- **Bounds-to-bounds distance** (more accurate than center-to-center)
- **Direction classification** (left/right/front/back/above/below)
- **Distance-based filtering** (only consider nearby neighbors)
- **Sorted results** (closest first)

Key methods:
- `findNeighbors(entityId, world)` - Find all neighbors within range
- `findNeighborsInDirection(...)` - Filter by direction
- `findClosestNeighborInDirection(...)` - Get closest in specific direction

### 3. Neighbor Candidate Generator

**File:** `lib/application/spatial/candidates/neighbor_candidate_generator.dart`

Generates placement candidates adjacent to existing objects:

- **Right/Left/Front/Back** positions
- **Above** position (for stacking)
- Configurable spacing
- Metadata tracking (neighbor ID, direction)

Produces candidates like:
```
[A] → generates [candidate-right], [candidate-left], 
      [candidate-front], [candidate-back], [candidate-above]
```

### 4. Neighbor Pattern Scorer

**File:** `lib/application/spatial/scoring/neighbor_pattern_scorer.dart`

Scores candidates based on human-like preferences:

- **Proximity score**: Closer is better (but not too close)
- **Alignment score**: Prefer same row/column alignment
- **Orientation score**: Prefer same rotation
- **Spacing consistency**: Prefer uniform gaps

Configurable parameters:
- `desiredSpacing`: Target gap between objects (default: 0.05m)
- `spacingTolerance`: Acceptable variation (default: 0.02m)
- `preferAlignment`: Enable alignment scoring
- `preferSameOrientation`: Enable orientation scoring

### 5. Updated Composite Generators

**File:** `lib/application/spatial/candidates/composite_candidate_generator.dart`

Added factory constructor for easy setup:

```dart
factory CompositeCandidateGenerator.defaultSet({
  double neighborSpacing = 0.05,
})
```

Now includes:
- SurfaceCandidateGenerator
- AnchorCandidateGenerator
- NeighborCandidateGenerator ← **New!**

**File:** `lib/application/spatial/scoring/composite_placement_scorer.dart`

Added factory constructor:

```dart
factory CompositePlacementScorer.defaultSet({
  double desiredSpacing = 0.05,
  bool preferAlignment = true,
  bool preferSameOrientation = true,
})
```

Now includes:
- DistanceScorer
- AnchorPreferenceScorer
- NeighborPatternScorer ← **New!**

## Key Concepts

### Bounds-to-Bounds Distance

Unlike center-to-center distance, bounds-to-bounds correctly handles:

```
A: 2m wide, center at 0
B: 0.5m wide, center at 1.2

Center-to-center: 1.2m
Bounds-to-bounds: 0.2m (actual gap)
```

Implementation:
```dart
double _axisDistance(double minA, double maxA, double minB, double maxB) {
  if (maxA < minB) return minB - maxA;  // Gap
  if (maxB < minA) return minA - maxB;  // Gap
  return 0;  // Overlapping
}
```

### Human-Like "Tidiness"

The scorer encodes preferences for:
- **Aligned** arrangements (same row/column)
- **Uniform** spacing (consistent gaps)
- **Organized** orientation (facing same direction)
- **Symmetrical** patterns
- **Efficient** packing

This produces surprisingly human-like placement without domain-specific code.

### Domain Agnosticism

The engine knows nothing about:
- Cargo vs chairs vs products
- Warehouses vs restaurants vs ports

It only understands:
- **Spatial patterns** (linear, grid, stack, perimeter)
- **Relationships** (ON, INSIDE, ADJACENT_TO, ABOVE)
- **Capabilities** (canSupport, canBeContained, canBeStacked)

## Usage Examples

### Warehouse Shelf Packing

```dart
// Existing: [A][B][C] on shelf
// User drags D near shelf

final engine = PlacementEngine(
  candidateGenerator: CompositeCandidateGenerator.defaultSet(),
  constraints: [
    CollisionConstraint(),
    SurfaceFitConstraint(),
    SupportConstraint(),
  ],
  scorer: CompositePlacementScorer.defaultSet(
    preferAlignment: true,
    preferSameOrientation: true,
  ),
);

// Result: [A][B][C][D] - automatically aligned!
```

### Restaurant Table Seating

```dart
// Existing: table with 3 chairs
//          [Chair]
//             ↑
//   [Chair] TABLE [Chair]

// User drags 4th chair near table

final engine = PlacementEngine(
  candidateGenerator: CompositeCandidateGenerator.defaultSet(neighborSpacing: 0.1),
  constraints: [CollisionConstraint(), ClearanceConstraint(clearance: 0.05)],
  scorer: CompositePlacementScorer.defaultSet(
    preferSameOrientation: false, // Chairs face table, not each other
  ),
);

// Result: Chair snaps to remaining seat position
//          [Chair]
//             ↑
//   [Chair] TABLE [Chair]
//             ↓
//          [Chair] ← New!
```

### Vertical Stacking

```dart
// Existing: [Box-A] on floor
// User drags Box-B nearby

final engine = PlacementEngine(
  candidateGenerator: CompositeCandidateGenerator.defaultSet(),
  constraints: [
    CollisionConstraint(),
    SupportConstraint(), // Must be supported
  ],
  scorer: NeighborPatternScorer(
    desiredSpacing: 0.01,
    preferAlignment: true,
  ),
);

// Result: Box-B stacks on top of Box-A
//   [Box-B]
//   [Box-A]
```

## Example Output

Run the demo:
```bash
dart run example/step11_neighbor_aware_placement_demo.dart
```

Expected output:
```
=== Step 11: Neighbor-Aware Packing & Placement Demo ===

--- Example 1: Warehouse Shelf Packing ---

✓ Created shelf: shelf-001
✓ Placed cargo-A at x=-1.0
✓ Placed cargo-B at x=0.0
✓ Placed cargo-C at x=1.0

📊 Neighbors of cargo-C:
   - cargo-B: left (distance: 0.200)
   - cargo-A: left (distance: 1.200)
   - shelf-001: below (distance: 0.650)

🎯 Placement Result for cargo-D:
   ✓ Valid placement found!
   Position: (2.000, 0.750, 0.000)
   Score: 3.842
   Expected: Should snap to right of cargo-C at x≈2.0
   ✅ SUCCESS: Cargo-D placed adjacent to cargo-C with proper alignment!


--- Example 2: Restaurant Table Seating ---

✓ Created table: table-001 with 4 seat anchors
✓ Placed chair-1 at anchor seat-1
✓ Placed chair-2 at anchor seat-2
✓ Placed chair-3 at anchor seat-3

🎯 Placement Result for chair-4:
   ✓ Valid placement found!
   Position: (0.000, 0.225, 0.800)
   Score: 2.951
   Expected: Should snap to remaining anchor at (0, 0, 0.8)
   ✅ SUCCESS: Chair-4 placed at remaining seat position!


--- Example 3: Vertical Stacking ---

✓ Placed box-A on floor

🎯 Placement Result for box-B (stacking):
   ✓ Valid placement found!
   Position: (0.000, 0.450, 0.000)
   Expected Y: ≈0.45 (on top of box-A which is 0.3m tall)
   ✅ SUCCESS: Box-B stacked on top of box-A!

=== Demo Complete ===

Key Takeaways:
1. Neighbor-aware placement produces human-like arrangements
2. System prefers aligned, evenly-spaced configurations
3. Works across domains (warehouse, restaurant, stacking) without domain-specific code
4. Candidate generation + constraints + scoring = intelligent placement
```

## Architectural Principles

### 1. Generate Many, Filter Ruthlessly

Candidate generation is allowed to be redundant. The scorer eliminates bad candidates.

```
Generate 35 candidates
   ↓
Constraints filter to 12 valid
   ↓
Scorer picks best 1
```

### 2. Separation of Concerns

- **Candidate generators**: Suggest plausible positions (cheap)
- **Constraints**: Enforce hard rules (collision, support, etc.)
- **Scorers**: Encode soft preferences (alignment, tidiness)

### 3. No Domain Knowledge in Engine

Avoid:
```dart
if (entity.type == 'chair') { ... }  // ❌ Bad!
```

Instead use capabilities:
```dart
class SpatialCapabilities {
  final bool canSupport;
  final bool canBeContained;
  final bool canBeStacked;
  // ...
}
```

### 4. Semantic Relations Over Coordinates

Move from:
```
position = (4.2, 1.0, 2.7)
```

To:
```
cargo-004 is RIGHT_OF cargo-003
            distance = 0.05m
            aligned = true
```

## Future Enhancements

### 5.5A.4: Semantic Spatial Relations

Implement explicit relation types:
- ON, INSIDE, ADJACENT_TO
- ATTACHED_TO, STACKED_ON
- CONTAINED_BY, NEAR

These should drive different candidate generators and constraints automatically.

### Spatial Capabilities

Add to entities:
```dart
class SpatialCapabilities {
  final bool canContain;
  final bool canSupport;
  final bool canBeContained;
  final bool canBeStacked;
  final bool canAttach;
}
```

### Packing Patterns

Enum for common arrangements:
```dart
enum PackingPatternType {
  free, linear, grid, stack, radial, perimeter, anchored,
}
```

### Weighted Scoring

Allow fine-tuned control:
```dart
WeightedScorer([
  (DistanceScorer(), 0.5),
  (AnchorPreferenceScorer(), 0.3),
  (NeighborPatternScorer(), 0.2),
])
```

## Files Created/Modified

### New Files (7)
1. `lib/application/spatial/neighbors/spatial_neighbor.dart`
2. `lib/application/spatial/neighbors/neighbor_analyzer.dart`
3. `lib/application/spatial/candidates/neighbor_candidate_generator.dart`
4. `lib/application/spatial/scoring/neighbor_pattern_scorer.dart`
5. `example/step11_neighbor_aware_placement_demo.dart`
6. `proposal/step11_implementation.md` (this file)

### Modified Files (3)
1. `lib/application/spatial/candidates/composite_candidate_generator.dart`
   - Added `defaultSet()` factory
   - Integrated NeighborCandidateGenerator

2. `lib/application/spatial/scoring/composite_placement_scorer.dart`
   - Added `defaultSet()` factory
   - Integrated NeighborPatternScorer

3. `lib/digital_twin_core.dart`
   - Exported new neighbor, candidate, and scorer classes

## Testing

### Manual Testing
```bash
dart run example/step11_neighbor_aware_placement_demo.dart
```

### What to Verify
- ✓ Warehouse cargo aligns in neat rows
- ✓ Restaurant chairs snap to table anchors
- ✓ Boxes stack vertically when appropriate
- ✓ Invalid placements are rejected by constraints
- ✓ Multiple valid options are scored and best is chosen

## Conclusion

Step 11 transforms the placement system from a simple collision checker into an **intelligent spatial reasoning engine** that produces human-like arrangements. The system now understands:

- **Proximity**: Objects should be near their neighbors
- **Alignment**: Objects should form neat rows/columns
- **Orientation**: Objects should face consistent directions
- **Spacing**: Gaps should be uniform
- **Stacking**: Objects can be placed above others

All while remaining completely **domain-agnostic** - the same engine works for warehouses, restaurants, ports, parking lots, factories, and more without any domain-specific code in the core placement logic.

This is a critical step toward the goal of a **platform-agnostic digital twin framework** that feels intuitive and game-like to use.
