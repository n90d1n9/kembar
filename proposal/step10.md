Yes. **Step 5.5A.2 = Candidate Sampling & Intelligent Snapping.**

In 5.5A.1 we made placement *correct*. Now we make it **feel intelligent**.

The target is:

> Given a user's drop position, generate multiple plausible positions, reject impossible ones, then choose the best valid position.

This is the layer that eventually makes the platform feel more like a game/editor than a raw 3D viewer.

---

# 5.5A.2 — Candidate Sampling & Intelligent Snapping

## 1. The new architecture

We're upgrading:

```text
Drop Position
     │
     ▼
Candidate Generator
     │
     ├── preferred position
     ├── grid positions
     ├── surface center
     ├── edges
     ├── corners
     ├── anchors
     └── neighboring objects
             │
             ▼
       Constraint Engine
             │
       ┌─────┼──────┐
       ▼     ▼      ▼
   collision fit  support
             │
             ▼
       Candidate Scorer
             │
             ▼
       Best Placement
```

The important conceptual separation is:

```text
Generate possibilities
        ≠
Determine validity
        ≠
Choose best possibility
```

Don't combine these three.

---

# 5.5A.2.1 Create a candidate generator interface

Create:

```text
lib/application/spatial/candidates/candidate_generator.dart
```

```dart
import '../placement_candidate.dart';
import '../spatial_world.dart';
import '../../../domain/spatial/placement_request.dart';

abstract interface class CandidateGenerator {
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

Now we can have multiple candidate-generation strategies.

---

# 5.5A.2.2 Surface candidate generator

Rename/refactor our existing strategy into:

```text
surface_candidate_generator.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import '../../../domain/spatial/placement_request.dart';
import '../../../domain/spatial/placement_surface.dart';
import '../placement_candidate.dart';
import '../spatial_world.dart';
import 'candidate_generator.dart';

class SurfaceCandidateGenerator
    implements CandidateGenerator {
  const SurfaceCandidateGenerator();

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(request.subjectId);

    if (subject == null) {
      return const [];
    }

    final candidates =
        <PlacementCandidate>[];

    for (final surface
        in _surfacesForTarget(
      request.targetId,
      world,
    )) {
      if (surface.type !=
          PlacementSurfaceType.horizontal) {
        continue;
      }

      candidates.addAll(
        _generateForSurface(
          subject,
          surface,
          request,
        ),
      );
    }

    return candidates;
  }

  List<PlacementCandidate>
      _generateForSurface(
    dynamic subject,
    PlacementSurface surface,
    PlacementRequest request,
  ) {
    final points = <Vector3>[];

    final preferred =
        request.preferredPosition;

    if (preferred != null) {
      points.add(
        _projectToSurface(
          preferred,
          surface,
        ),
      );
    }

    points.add(
      surface.bounds.center,
    );

    return points
        .map(
          (position) =>
              PlacementCandidate(
            position: position,
            surfaceId: surface.id,
          ),
        )
        .toList();
  }

  Vector3 _projectToSurface(
    Vector3 point,
    PlacementSurface surface,
  ) {
    return Vector3(
      point.x,
      surface.height,
      point.z,
    );
  }

  List<PlacementSurface>
      _surfacesForTarget(
    String targetId,
    SpatialWorld world,
  ) {
    return world
        .component(targetId)
        ?.surfaces ??
        const [];
  }
}
```

For now I used `dynamic` only to keep this snippet focused. Replace it with your actual `SpatialComponent` type in the project.

---

# 5.5A.2.3 But we have a problem

This candidate:

```text
position.y = surface.height
```

is not the object's final position.

Remember:

```text
surface = y = 1.5
cargo height = 0.5
```

The cargo center should be:

```text
1.5 + 0.25
= 1.75
```

So candidate generation needs to understand the subject's dimensions.

Add:

```dart
double _surfaceCenterY(
  SpatialComponent subject,
  PlacementSurface surface,
) {
  return surface.height +
      subject.localBounds.height / 2;
}
```

Then:

```dart
Vector3 _projectToSurface(
  Vector3 point,
  SpatialComponent subject,
  PlacementSurface surface,
) {
  return Vector3(
    point.x,
    _surfaceCenterY(
      subject,
      surface,
    ),
    point.z,
  );
}
```

This is our first **dimension-aware snapping**.

---

# 5.5A.2.4 Generate a grid

Now let's make placement considerably smarter.

For a shelf:

```text
┌─────────────────────────────┐
│                             │
│  •    •    •    •    •     │
│                             │
│  •    •    •    •    •     │
│                             │
│  •    •    •    •    •     │
│                             │
└─────────────────────────────┘
```

We don't need an infinitely fine grid.

Create a configurable sampler:

```text
grid_candidate_generator.dart
```

```dart
class GridSamplingConfig {
  final double spacing;

  final int maxColumns;

  final int maxRows;

  const GridSamplingConfig({
    this.spacing = 0.25,
    this.maxColumns = 20,
    this.maxRows = 20,
  });
}
```

Then:

```dart
List<Vector3> _gridPoints(
  Bounds bounds,
  double y,
  GridSamplingConfig config,
) {
  final points = <Vector3>[];

  var columns = 0;

  for (
    double x = bounds.min.x;
    x <= bounds.max.x;
    x += config.spacing
  ) {
    if (columns >= config.maxColumns) {
      break;
    }

    var rows = 0;

    for (
      double z = bounds.min.z;
      z <= bounds.max.z;
      z += config.spacing
    ) {
      if (rows >= config.maxRows) {
        break;
      }

      points.add(
        Vector3(x, y, z),
      );

      rows++;
    }

    columns++;
  }

  return points;
}
```

But there is another important improvement.

---

# 5.5A.2.5 Don't sample the entire surface blindly

Suppose:

```text
warehouse floor
100m × 100m
```

A 10cm grid would create:

```text
1,000 × 1,000
= 1,000,000 candidates
```

That's terrible.

Instead:

> Candidate generation should be local around the user's intent.

So we introduce:

```dart
class SamplingRegion {
  final double radius;

  const SamplingRegion({
    this.radius = 2.0,
  });
}
```

Then:

```text
user drop
    X
    │
    ▼

     ┌─────────────┐
     │  sampling   │
     │    region   │
     │      X      │
     └─────────────┘

only evaluate nearby candidates
```

This will become extremely important for large digital twins.

---

# 5.5A.2.6 Local grid sampling

```dart
List<Vector3> _localGridPoints({
  required Vector3 center,
  required Bounds surfaceBounds,
  required double y,
  required double spacing,
  required double radius,
}) {
  final points = <Vector3>[];

  final minX = center.x - radius;
  final maxX = center.x + radius;

  final minZ = center.z - radius;
  final maxZ = center.z + radius;

  for (
    double x = minX;
    x <= maxX;
    x += spacing
  ) {
    for (
      double z = minZ;
      z <= maxZ;
      z += spacing
    ) {
      if (x < surfaceBounds.min.x ||
          x > surfaceBounds.max.x ||
          z < surfaceBounds.min.z ||
          z > surfaceBounds.max.z) {
        continue;
      }

      points.add(
        Vector3(x, y, z),
      );
    }
  }

  return points;
}
```

Now a drop only examines a local neighborhood.

---

# 5.5A.2.7 Add edge candidates

Grid alone isn't enough.

Suppose a restaurant table is:

```text
┌──────────────────────┐
│                      │
│          X           │
│                      │
└──────────────────────┘
```

A chair might need to be near the edge rather than centered.

So generate:

```text
┌──────────────────────┐
│  •                •  │
│                      │
│                      │
│  •                •  │
└──────────────────────┘
```

For a surface:

```dart
List<Vector3> _edgePoints(
  Bounds bounds,
  double y,
) {
  final xMid =
      (bounds.min.x + bounds.max.x) / 2;

  final zMid =
      (bounds.min.z + bounds.max.z) / 2;

  return [
    Vector3(bounds.min.x, y, zMid),
    Vector3(bounds.max.x, y, zMid),
    Vector3(xMid, y, bounds.min.z),
    Vector3(xMid, y, bounds.max.z),
  ];
}
```

Then corners:

```dart
List<Vector3> _cornerPoints(
  Bounds bounds,
  double y,
) {
  return [
    Vector3(bounds.min.x, y, bounds.min.z),
    Vector3(bounds.min.x, y, bounds.max.z),
    Vector3(bounds.max.x, y, bounds.min.z),
    Vector3(bounds.max.x, y, bounds.max.z),
  ];
}
```

---

# 5.5A.2.8 But edge positions need object dimensions

This is critical.

Suppose the surface is:

```text
2m × 2m
```

and cargo is:

```text
0.5m × 0.5m
```

We cannot place its center exactly at:

```text
surface.min.x
```

because half the cargo would hang off the surface.

Instead:

```text
surface edge
│
│ ← half object width
│
┌────── cargo
```

So define:

```dart
Bounds usableBoundsFor(
  PlacementSurface surface,
  SpatialComponent subject,
) {
  final halfWidth =
      subject.localBounds.width / 2;

  final halfDepth =
      subject.localBounds.depth / 2;

  return Bounds(
    min: Vector3(
      surface.bounds.min.x +
          halfWidth,
      surface.bounds.min.y,
      surface.bounds.min.z +
          halfDepth,
    ),
    max: Vector3(
      surface.bounds.max.x -
          halfWidth,
      surface.bounds.max.y,
      surface.bounds.max.z -
          halfDepth,
    ),
  );
}
```

This is a **very important upgrade**.

We're no longer sampling possible object centers against the raw surface.

We're sampling against the **usable center region**.

---

# 5.5A.2.9 Visualizing the difference

Raw surface:

```text
┌────────────────────────┐
│                        │
│                        │
│                        │
└────────────────────────┘
```

Usable center region:

```text
  half object size
       ↓
  ┌──────────────────┐
  │ ┌──────────────┐ │
  │ │              │ │
  │ │ valid center │ │
  │ │    region    │ │
  │ │              │ │
  │ └──────────────┘ │
  └──────────────────┘
```

This one change prevents a huge number of bad placements.

---

# 5.5A.2.10 Create `SurfaceCandidateGenerator` properly

Now let's combine:

```text
preferred
center
grid
edges
corners
```

```dart
class SurfaceCandidateGenerator
    implements CandidateGenerator {
  final GridSamplingConfig grid;

  const SurfaceCandidateGenerator({
    this.grid =
        const GridSamplingConfig(),
  });

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(
      request.subjectId,
    );

    if (subject == null) {
      return const [];
    }

    final candidates =
        <PlacementCandidate>[];

    final surfaces =
        world.component(
              request.targetId,
            )
            ?.surfaces ??
        const [];

    for (final surface in surfaces) {
      if (surface.type !=
          PlacementSurfaceType.horizontal) {
        continue;
      }

      candidates.addAll(
        _generateForSurface(
          subject,
          surface,
          request,
        ),
      );
    }

    return _deduplicate(candidates);
  }

  List<PlacementCandidate>
      _generateForSurface(
    SpatialComponent subject,
    PlacementSurface surface,
    PlacementRequest request,
  ) {
    final usable =
        _usableBounds(
      surface,
      subject,
    );

    final y =
        surface.height +
        subject.localBounds.height / 2;

    final points = <Vector3>[];

    final preferred =
        request.preferredPosition;

    if (preferred != null) {
      points.add(
        _clamp(
          preferred,
          usable,
          y,
        ),
      );

      points.addAll(
        _localGridPoints(
          center: preferred,
          bounds: usable,
          y: y,
          spacing: grid.spacing,
          radius: 1.0,
        ),
      );
    }

    points.add(
      Vector3(
        usable.center.x,
        y,
        usable.center.z,
      ),
    );

    points.addAll(
      _edgePoints(
        usable,
        y,
      ),
    );

    points.addAll(
      _cornerPoints(
        usable,
        y,
      ),
    );

    return points
        .map(
          (point) =>
              PlacementCandidate(
            position: point,
            surfaceId: surface.id,
          ),
        )
        .toList();
  }

  Bounds _usableBounds(
    PlacementSurface surface,
    SpatialComponent subject,
  ) {
    final halfWidth =
        subject.localBounds.width / 2;

    final halfDepth =
        subject.localBounds.depth / 2;

    return Bounds(
      min: Vector3(
        surface.bounds.min.x +
            halfWidth,
        surface.bounds.min.y,
        surface.bounds.min.z +
            halfDepth,
      ),
      max: Vector3(
        surface.bounds.max.x -
            halfWidth,
        surface.bounds.max.y,
        surface.bounds.max.z -
            halfDepth,
      ),
    );
  }

  Vector3 _clamp(
    Vector3 point,
    Bounds bounds,
    double y,
  ) {
    return Vector3(
      point.x.clamp(
        bounds.min.x,
        bounds.max.x,
      ),
      y,
      point.z.clamp(
        bounds.min.z,
        bounds.max.z,
      ),
    );
  }

  List<Vector3> _localGridPoints({
    required Vector3 center,
    required Bounds bounds,
    required double y,
    required double spacing,
    required double radius,
  }) {
    final points = <Vector3>[];

    for (
      double x = center.x - radius;
      x <= center.x + radius;
      x += spacing
    ) {
      for (
        double z = center.z - radius;
        z <= center.z + radius;
        z += spacing
      ) {
        if (x < bounds.min.x ||
            x > bounds.max.x ||
            z < bounds.min.z ||
            z > bounds.max.z) {
          continue;
        }

        points.add(
          Vector3(x, y, z),
        );
      }
    }

    return points;
  }

  List<Vector3> _edgePoints(
    Bounds bounds,
    double y,
  ) {
    final xMid =
        (bounds.min.x + bounds.max.x) / 2;

    final zMid =
        (bounds.min.z + bounds.max.z) / 2;

    return [
      Vector3(bounds.min.x, y, zMid),
      Vector3(bounds.max.x, y, zMid),
      Vector3(xMid, y, bounds.min.z),
      Vector3(xMid, y, bounds.max.z),
    ];
  }

  List<Vector3> _cornerPoints(
    Bounds bounds,
    double y,
  ) {
    return [
      Vector3(bounds.min.x, y, bounds.min.z),
      Vector3(bounds.min.x, y, bounds.max.z),
      Vector3(bounds.max.x, y, bounds.min.z),
      Vector3(bounds.max.x, y, bounds.max.z),
    ];
  }

  List<PlacementCandidate> _deduplicate(
    List<PlacementCandidate> candidates,
  ) {
    final result =
        <PlacementCandidate>[];

    for (final candidate in candidates) {
      final exists = result.any(
        (existing) =>
            existing.position
                .distanceTo(
              candidate.position,
            ) <
            0.001,
      );

      if (!exists) {
        result.add(candidate);
      }
    }

    return result;
  }
}
```

This is our first real candidate generator.

---

# 5.5A.2.11 Candidate count

For a small shelf we might now have:

```text
preferred       1
local grid     ~25
center          1
edges           4
corners         4
------------------
               ~35 candidates
```

That's completely reasonable.

And importantly:

```text
35 candidates
×
5 constraints
```

is much cheaper than simulating physics for everything.

---

# 5.5A.2.12 Add anchor candidates

Now we use the `SpatialAnchor` abstraction we created earlier.

Imagine:

```text
restaurant table
   │
   ├── seat-anchor-1
   ├── seat-anchor-2
   ├── seat-anchor-3
   └── seat-anchor-4
```

or:

```text
warehouse rack
   │
   ├── slot-A
   ├── slot-B
   └── slot-C
```

We should be able to generate candidates directly from those.

Create:

```text
anchor_candidate_generator.dart
```

```dart
class AnchorCandidateGenerator
    implements CandidateGenerator {
  const AnchorCandidateGenerator();

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final target =
        world.component(
      request.targetId,
    );

    if (target == null) {
      return const [];
    }

    return target.anchors
        .map(
          (anchor) =>
              PlacementCandidate(
            position:
                anchor.localPosition,
            rotation:
                anchor.rotation,
            anchorId: anchor.id,
          ),
        )
        .toList();
  }
}
```

But there's an issue.

`localPosition` isn't world position.

We need to account for the host's transform.

---

# 5.5A.2.13 World-space anchor

For now:

```dart
Vector3 worldAnchorPosition(
  SpatialComponent host,
  SpatialAnchor anchor,
) {
  return host.position +
      anchor.localPosition;
}
```

Then:

```dart
position:
    worldAnchorPosition(
      target,
      anchor,
    ),
```

This works for translation.

Later we'll add:

```text
rotation
scale
parent transforms
```

through a proper transform hierarchy.

---

# 5.5A.2.14 Combine candidate generators

Now the engine shouldn't know:

```text surface
anchor
grid
```

Instead:

```dart
class CompositeCandidateGenerator
    implements CandidateGenerator {
  final List<CandidateGenerator>
      generators;

  const CompositeCandidateGenerator({
    required this.generators,
  });

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final candidates =
        <PlacementCandidate>[];

    for (final generator
        in generators) {
      candidates.addAll(
        generator.generate(
          request,
          world,
        ),
      );
    }

    return _deduplicate(candidates);
  }

  List<PlacementCandidate> _deduplicate(
    List<PlacementCandidate> candidates,
  ) {
    final result =
        <PlacementCandidate>[];

    for (final candidate in candidates) {
      final duplicate = result.any(
        (existing) =>
            existing.position
                .distanceTo(
              candidate.position,
            ) <
            0.001,
      );

      if (!duplicate) {
        result.add(candidate);
      }
    }

    return result;
  }
}
```

Then:

```dart
final candidateGenerator =
    CompositeCandidateGenerator(
  generators: [
    const SurfaceCandidateGenerator(),
    const AnchorCandidateGenerator(),
  ],
);
```

Now the engine simply asks:

```text
"Give me possible positions."
```

---

# 5.5A.2.15 Now introduce scoring properly

Previously:

```dart
1 / (1 + distance)
```

That's a good start, but not enough.

We eventually want:

```text
Score =
    distance
  + alignment
  + preferred anchor
  + stability
  + accessibility
  + semantic preference
```

But don't hardcode those into the engine.

Create:

```text
scoring/
placement_scorer.dart
```

```dart
abstract interface class PlacementScorer {
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

---

# 5.5A.2.16 Distance scorer

```dart
class DistanceScorer
    implements PlacementScorer {
  const DistanceScorer();

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final preferred =
        request.preferredPosition;

    if (preferred == null) {
      return 0;
    }

    final distance =
        candidate.position.distanceTo(
      preferred,
    );

    return 1.0 /
        (1.0 + distance);
  }
}
```

---

# 5.5A.2.17 Anchor preference scorer

```dart
class AnchorPreferenceScorer
    implements PlacementScorer {
  const AnchorPreferenceScorer();

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    if (candidate.anchorId == null) {
      return 0;
    }

    return 1.0;
  }
}
```

This looks trivial now.

Later the anchor can contain:

```text
priority
capacity
semantic role
preferred object types
orientation
```

For example:

```text
slot-A
preferred:
  cargo.small
```

and:

```text
slot-B
preferred:
  cargo.large
```

---

# 5.5A.2.18 Composite scorer

```dart
class CompositePlacementScorer
    implements PlacementScorer {
  final List<PlacementScorer>
      scorers;

  const CompositePlacementScorer({
    required this.scorers,
  });

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    var total = 0.0;

    for (final scorer in scorers) {
      total += scorer.score(
        candidate,
        request,
        world,
      );
    }

    return total;
  }
}
```

Later we should upgrade this to weighted scoring:

```text
distance × 0.5
anchor × 0.3
alignment × 0.2
```

We'll do that in a later step.

---

# 5.5A.2.19 Update PlacementEngine

Now:

```dart
class PlacementEngine {
  final CandidateGenerator
      candidateGenerator;

  final List<PlacementConstraint>
      constraints;

  final PlacementScorer scorer;

  const PlacementEngine({
    required this.candidateGenerator,
    required this.constraints,
    required this.scorer,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final candidates =
        candidateGenerator.generate(
      request,
      world,
    );

    PlacementResult? best;

    for (final candidate
        in candidates) {
      final evaluations =
          constraints.map(
        (constraint) =>
            constraint.evaluate(
          candidate,
          request,
          world,
        ),
      );

      final failed =
          evaluations.any(
        (result) => !result.satisfied,
      );

      if (failed) {
        continue;
      }

      final score =
          scorer.score(
        candidate,
        request,
        world,
      );

      final result = PlacementResult(
        valid: true,
        position: candidate.position,
        rotation: candidate.rotation,
        surfaceId: candidate.surfaceId,
        anchorId: candidate.anchorId,
        score: score,
        reasons: evaluations
            .map(
              (result) => result.reason,
            )
            .toList(),
      );

      if (best == null ||
          result.score > best.score) {
        best = result;
      }
    }

    return best ??
        const PlacementResult.invalid(
          'No valid placement',
        );
  }
}
```

Now the architecture is really clean:

```text
PlacementEngine
   │
   ├── CandidateGenerator
   │
   ├── Constraints
   │
   └── Scorer
```

---

# 5.5A.2.20 Example configuration

```dart
final candidateGenerator =
    CompositeCandidateGenerator(
  generators: [
    const SurfaceCandidateGenerator(),
    const AnchorCandidateGenerator(),
  ],
);

final scorer =
    CompositePlacementScorer(
  scorers: [
    const DistanceScorer(),
    const AnchorPreferenceScorer(),
  ],
);

final engine = PlacementEngine(
  candidateGenerator:
      candidateGenerator,
  constraints: [
    CollisionConstraint(
      const CollisionDetector(),
    ),
    ClearanceConstraint(
      const CollisionDetector(),
    ),
    const SurfaceFitConstraint(),
    const SupportConstraint(),
  ],
  scorer: scorer,
);
```

This is now an extensible spatial reasoning pipeline.

---

# 5.5A.2.21 What happens when cargo is dragged?

Suppose:

```text
Shelf
┌─────────────────────────────┐
│                             │
│                X            │ ← mouse
│                             │
└─────────────────────────────┘
```

The system generates:

```text
Candidate 1
    preferred position
    ↓
    collision

Candidate 2
    nearby left
    ↓
    collision

Candidate 3
    nearby right
    ↓
    valid
    score = 0.92

Candidate 4
    shelf center
    ↓
    valid
    score = 0.67
```

Result:

```text
Candidate 3 wins
```

So the cargo snaps to:

```text
                □
                ↑
              best
```

rather than simply:

```text
mouse position
```

---

# 5.5A.2.22 This is the beginning of "intelligent placement"

Notice we're not using AI yet.

We are using:

```text
geometry
+
constraints
+
search
+
scoring
```

That's actually the correct foundation.

AI should eventually help with:

```text
"What is probably the best place?"
```

But deterministic spatial reasoning should still answer:

```text
"Is this physically/logically valid?"
```

So later:

```text
AI suggestion
      ↓
CandidateGenerator
      ↓
ConstraintEngine
      ↓
Scorer
      ↓
valid placement
```

AI does not get to bypass the constraints.

---

# 5.5A.2.23 The same system for a restaurant

Consider:

```text
Table
┌─────────────────┐
│                 │
│                 │
└─────────────────┘
```

You define four anchors:

```text
      chair
        ↑
        A1

chair ← table → chair
 A2              A3

        ↓
        A4
      chair
```

Then:

```text
PlacementRequest(
  subjectId: chair,
  targetId: table,
  relation: adjacentTo,
)
```

The candidate generator can produce:

```text
A1
A2
A3
A4
```

Constraints check:

```text
collision?
clearance?
accessible?
already occupied?
```

Scoring determines:

```text
closest valid anchor
```

No restaurant-specific placement engine.

---

# 5.5A.2.24 Warehouse example

Same machinery:

```text
Rack
├── slot-01
├── slot-02
├── slot-03
└── slot-04
```

Each slot is an anchor.

Cargo:

```text
cargo-001
```

Request:

```text
inside rack
```

Candidate generation:

```text
slot-01
slot-02
slot-03
slot-04
```

Constraints:

```text
size fits?
occupied?
weight capacity?
hazard compatibility?
```

Scoring:

```text
nearest
+
preferred zone
+
FIFO rule
```

Again, same kernel.

---

# 5.5A.2.25 One important improvement: candidate metadata

Right now `PlacementCandidate` only has:

```text
position
rotation
surfaceId
anchorId
```

Let's add a reason/source.

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
```

Then:

```dart
class PlacementCandidate {
  final Vector3 position;

  final Vector3 rotation;

  final String? surfaceId;

  final String? anchorId;

  final CandidateSource source;

  const PlacementCandidate({
    required this.position,
    required this.source,
    this.rotation = Vector3.zero(),
    this.surfaceId,
    this.anchorId,
  });
}
```

Now debugging becomes much easier.

You can say:

```text
Best candidate:
source = anchor
score = 1.42
```

rather than wondering where it came from.

---

# 5.5A.2.26 Candidate ranking visualization

This will eventually be useful in your editor/debug mode.

Imagine:

```text
        shelf

   ○        ○
       ○
            ● ← selected
   ×        ○
       ×
```

Where:

```text
● = best
○ = valid candidate
× = rejected
```

And if you enable developer mode:

```text
Candidate #17
source: grid
score: 0.84
status: valid

Candidate #18
source: grid
score: 0.72
status: collision

Candidate #19
source: anchor
score: 1.21
status: valid
```

This will become invaluable when debugging placement behavior.

---

# 5.5A.2.27 Add a debug result

Eventually `PlacementResult` should include candidate diagnostics.

I'd extend it later toward:

```dart
class PlacementEvaluation {
  final PlacementCandidate candidate;

  final bool valid;

  final double score;

  final List<String> reasons;

  const PlacementEvaluation({
    required this.candidate,
    required this.valid,
    required this.score,
    required this.reasons,
  });
}
```

Then:

```dart
PlacementResult
 ├── selected
 └── evaluations[]
```

This is useful for:

```text
debugging
analytics
AI training
explainability
```

But I would **not make this mandatory runtime data yet**. Add a debug mode first.

---

# 5.5A.2.28 Performance consideration

We are now doing:

```text
candidate generation
×
collision tests
```

For a small scene:

```text
35 candidates
×
100 objects
= 3,500 tests
```

Fine.

But:

```text
10,000 candidates
×
1,000,000 objects
```

is obviously impossible.

That's why the next spatial optimization eventually needs:

```text
SpatialIndex
```

such as:

```text
BVH
Octree
R-tree
grid hash
```

Then collision queries become:

```text
candidate
   ↓
spatial index
   ↓
nearby objects only
```

instead of:

```text
candidate
   ↓
every object in world
```

**Don't implement that yet.**

First get candidate behavior correct.

---

# 5.5A.2.29 The new mental model

At this point your spatial system is becoming:

```text
              USER INTENT
                  │
                  ▼
          "place this here"
                  │
                  ▼
       ┌────────────────────┐
       │ Candidate Generator│
       └─────────┬──────────┘
                 │
      ┌──────────┼──────────┐
      ▼          ▼          ▼
   preferred   anchors     grid
      │          │          │
      └──────────┼──────────┘
                 ▼
       ┌────────────────────┐
       │ Constraint Engine  │
       └─────────┬──────────┘
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
     collision support   fit
                 │
                 ▼
       ┌────────────────────┐
       │ Placement Scorer   │
       └─────────┬──────────┘
                 ▼
            BEST RESULT
```

That's a very strong foundation.

---

# 5.5A.2.30 What we should **not** add yet

Don't add these yet:

```text
❌ AI placement
❌ physics
❌ path planning
❌ spatial index
❌ machine learning
❌ NavMesh
❌ full OBB collision
❌ deformable objects
```

We're deliberately building this in layers.

The order should be:

```text
5.5A.1
spatial state + constraints
       ↓
5.5A.2
candidate generation + snapping
       ↓
5.5A.3
neighbor-aware packing
       ↓
5.5A.4
anchors + semantic relations
       ↓
5.5A.5
capacity + compatibility
       ↓
5.5A.6
spatial indexing
       ↓
5.5A.7
advanced geometry
       ↓
5.5A.8
simulation interaction
       ↓
AI-assisted placement/prediction
```

---

# The key result of 5.5A.2

You now have a clean three-stage architecture:

```text
                    PlacementRequest
                           │
                           ▼
                 ┌──────────────────┐
                 │ CandidateGenerator│
                 └────────┬─────────┘
                          │
                 20–50 possible poses
                          │
                          ▼
                 ┌──────────────────┐
                 │   Constraints    │
                 └────────┬─────────┘
                          │
                    valid candidates
                          │
                          ▼
                 ┌──────────────────┐
                 │     Scoring      │
                 └────────┬─────────┘
                          │
                          ▼
                   Best Placement
```

And that is exactly the abstraction we need before moving into **neighbor-aware packing**.

### Next: Step 5.5A.3

The next step should solve the more difficult case you originally asked about:

> **"How do I place one object after another rationally?"**

Instead of merely finding an empty point, we'll make the engine understand patterns like:

```text
Rack:
┌─────────────────────────────┐
│ [A][B][C][D]                │
│                             │
│ [E][F]      ← new cargo     │
└─────────────────────────────┘
```

and:

```text
Restaurant:
      chair
        ↓
   ┌──────────┐
   │  table   │
   └──────────┘
 chair      chair
```

That requires **neighbor-aware candidate generation, occupancy, spacing, alignment, and packing heuristics**—the layer that starts turning this from "collision detection" into a genuinely useful **generic spatial reasoning engine**.
