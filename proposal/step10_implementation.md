# Step 10 Implementation: Candidate Sampling & Intelligent Snapping

## Overview

Step 10 transforms the placement system from a simple "find any valid position" approach into an **intelligent, game-like placement experience**. The system now:

1. Generates multiple candidate positions (not just one)
2. Uses smart sampling strategies (grid, edges, corners, anchors)
3. Calculates usable bounds to prevent object overhang
4. Scores candidates to select the best option
5. Provides debugging visibility through source tracking

This makes the digital twin platform feel more like a sophisticated editor/game than a raw 3D viewer.

## Architecture

### Three-Stage Pipeline

```
PlacementRequest
      │
      ▼
┌──────────────────┐
│ CandidateGenerator│ → Generate 20-50 possible positions
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   Constraints    │ → Filter invalid positions
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│     Scorer       │ → Choose best valid position
└────────┬─────────┘
         │
         ▼
    Best Placement
```

**Key Principle:** Generation ≠ Validation ≠ Selection

Don't combine these three concerns. Each has a distinct responsibility.

## New Components

### 1. Candidate Generator Interface

**File:** `lib/application/spatial/candidates/candidate_generator.dart`

```dart
abstract interface class CandidateGenerator {
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

This interface allows multiple generation strategies to be composed.

### 2. Surface Candidate Generator

**File:** `lib/application/spatial/candidates/surface_candidate_generator.dart`

Generates candidates at:
- User's preferred position (clamped to usable bounds)
- Local grid around preferred position (~25 points)
- Surface center
- Edge midpoints (4 points)
- Corners (4 points)

**Key Innovation: Usable Bounds**

Instead of sampling against the raw surface bounds, we calculate a shrunken "usable bounds" region that accounts for the object's dimensions:

```dart
Bounds _usableBounds(surface, subject) {
  final halfWidth = subject.localBounds.width / 2;
  final halfDepth = subject.localBounds.depth / 2;
  
  return Bounds(
    min: Vector3(
      surface.bounds.min.x + halfWidth,
      ...,
      surface.bounds.min.z + halfDepth,
    ),
    max: Vector3(
      surface.bounds.max.x - halfWidth,
      ...,
      surface.bounds.max.z - halfDepth,
    ),
  );
}
```

This prevents the object from hanging off the edge when its center is placed at the surface boundary.

**Local Grid Sampling**

Instead of sampling the entire surface (which could generate millions of points for large surfaces), we sample only a local region around the user's intent:

```dart
List<Vector3> _localGridPoints({
  required Vector3 center,
  required double radius, // e.g., 1.0 meter
  ...
})
```

This keeps candidate counts reasonable (~35 per surface).

### 3. Anchor Candidate Generator

**File:** `lib/application/spatial/candidates/anchor_candidate_generator.dart`

Generates candidates directly from predefined spatial anchors:
- Chair positions around a table
- Storage slots in a warehouse rack
- Equipment mounting points
- Door/window frames

```dart
class AnchorCandidateGenerator implements CandidateGenerator {
  List<PlacementCandidate> generate(request, world) {
    return target.anchors.map((anchor) => 
      PlacementCandidate(
        position: worldAnchorPosition(target, anchor),
        anchorId: anchor.id,
        source: CandidateSource.anchor,
      )
    ).toList();
  }
}
```

### 4. Composite Candidate Generator

**File:** `lib/application/spatial/candidates/composite_candidate_generator.dart`

Combines multiple generators and deduplicates results:

```dart
final generator = CompositeCandidateGenerator(
  generators: [
    SurfaceCandidateGenerator(),
    AnchorCandidateGenerator(),
  ],
);
```

### 5. Placement Scorer Interface

**File:** `lib/application/spatial/scoring/placement_scorer.dart`

```dart
abstract interface class PlacementScorer {
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

### 6. Distance Scorer

**File:** `lib/application/spatial/scoring/distance_scorer.dart`

Prefers candidates closer to the user's preferred position:

```dart
double score(candidate, request, world) {
  final distance = candidate.position.distanceTo(preferred);
  return 1.0 / (1.0 + distance);
}
```

### 7. Anchor Preference Scorer

**File:** `lib/application/spatial/scoring/anchor_preference_scorer.dart`

Gives bonus points to anchor-based placements:

```dart
double score(candidate, request, world) {
  return candidate.anchorId != null ? 1.0 : 0.0;
}
```

### 8. Composite Placement Scorer

**File:** `lib/application/spatial/scoring/composite_placement_scorer.dart`

Combines multiple scorers by summing their scores.

### 9. Updated PlacementCandidate

**File:** `lib/application/spatial/placement_candidate.dart`

Added `CandidateSource` enum and `source` field for debugging:

```dart
enum CandidateSource {
  preferred,
  grid,
  center,
  edge,
  corner,
  anchor,
  neighbor,
}

class PlacementCandidate {
  final CandidateSource source;
  ...
}
```

### 10. Refactored PlacementEngine

**File:** `lib/application/spatial/placement_engine.dart`

Now uses the three-stage architecture:

```dart
class PlacementEngine {
  final CandidateGenerator candidateGenerator;
  final List<PlacementConstraint> constraints;
  final PlacementScorer scorer;

  PlacementResult findPlacement(request, world) {
    final candidates = candidateGenerator.generate(request, world);
    
    for (final candidate in candidates) {
      // Evaluate constraints
      final failures = constraints.evaluate(candidate);
      if (failures.isNotEmpty) continue;
      
      // Score the candidate
      final score = scorer.score(candidate);
      
      // Track best
      if (best == null || score > best.score) {
        best = result;
      }
    }
    
    return best;
  }
}
```

## Example Usage

```dart
// Configure the engine
final candidateGenerator = CompositeCandidateGenerator(
  generators: [
    SurfaceCandidateGenerator(),
    AnchorCandidateGenerator(),
  ],
);

final scorer = CompositePlacementScorer(
  scorers: [
    DistanceScorer(),
    AnchorPreferenceScorer(),
  ],
);

final engine = PlacementEngine(
  candidateGenerator: candidateGenerator,
  constraints: [
    CollisionConstraint(detector),
    ClearanceConstraint(detector, clearance: 0.1),
    SurfaceFitConstraint(),
    SupportConstraint(),
  ],
  scorer: scorer,
);

// Find placement
final result = engine.findPlacement(request, world);
```

## Candidate Count Example

For a typical shelf placement with preferred position:

```
preferred          1
local grid        ~25
center             1
edges              4
corners            4
-------------------
total             ~35 candidates
```

This is completely reasonable for real-time interaction.

## Domain Agnosticism

The same system works for:

### Warehouse
- Shelves with storage slots (anchors)
- Floor placement (surface with grid)
- Pallet positioning (edge/corner candidates)

### Restaurant
- Tables with chair anchors (4 per table)
- Counter placement (surface)
- Decor items (grid sampling)

### Port Terminal
- Container stacks (grid on terminal surface)
- Crane mounting points (anchors)
- Vehicle parking (grid with clearance)

### Parking Lot
- Parking spaces (anchors or surface regions)
- Entry/exit gates (specific positions)
- Obstacles (exclusion zones via constraints)

No domain-specific placement logic is needed!

## Performance Considerations

Current approach:
```
35 candidates × 100 objects = 3,500 collision tests
```

This is fine for small-to-medium scenes.

For large scenes (10,000+ objects), future optimization will need:
- Spatial indexing (BVH, Octree, R-tree, grid hash)
- Early-out optimization
- Candidate pruning before full constraint evaluation

**But don't implement that yet.** First get the behavior correct, then optimize.

## What's NOT Included (Yet)

Deliberately postponed:
- ❌ AI-powered placement suggestions
- ❌ Physics simulation
- ❌ Path planning for reaching placements
- ❌ Full spatial indexing
- ❌ Machine learning models
- ❌ NavMesh for accessibility
- ❌ OBB (oriented bounding box) collision
- ❌ Deformable objects

These will come in later steps. The current foundation is solid.

## Testing

Run the demo:
```bash
dart run example/step10_candidate_sampling_demo.dart
```

Expected output shows:
- Multiple candidates generated
- Constraint filtering
- Scoring breakdown
- Best candidate selection
- Source attribution

## Next Steps

Step 5.5A.3 should address **neighbor-aware packing**:
- How to place objects rationally next to each other?
- Pattern recognition (rows, columns, grids)
- Occupancy tracking
- Alignment heuristics
- Packing density optimization

This moves from "collision-free placement" to "intelligent spatial reasoning."

## Summary

Step 10 establishes a clean, extensible architecture for intelligent placement:

✅ **Generation** - Multiple strategies (surface, grid, anchors)
✅ **Validation** - Pluggable constraint system
✅ **Selection** - Composable scoring
✅ **Debugging** - Source tracking for candidates
✅ **Domain Agnostic** - Works for any domain
✅ **Performant** - Local sampling keeps counts reasonable

The platform now feels like a sophisticated editor rather than a raw 3D viewer.
