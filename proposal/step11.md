Absolutely. **Step 5.5A.3 = Neighbor-Aware Packing & Placement.**

This is where the system moves from:

> "Can this object physically fit here?"

to:

> **"Given everything already around it, where would a human/operator logically put it?"**

That distinction is very important for your goal of supporting warehouses, restaurants, factories, offices, retail, logistics, construction, etc.

---

# 5.5A.3 — Neighbor-Aware Packing

Our pipeline now becomes:

```text
PlacementRequest
       │
       ▼
Candidate Generation
       │
       ▼
 ┌───────────────────┐
 │ Spatial Relations │
 │ / Neighbors       │
 └─────────┬─────────┘
           │
           ▼
 Constraint Evaluation
           │
           ▼
 Candidate Scoring
           │
           ▼
     Best Placement
```

The new piece is:

```text
NeighborAnalyzer
```

---

# 5.5A.3.1 What "neighbor-aware" actually means

Suppose we have:

```text
┌──────────────────────────────┐
│                              │
│ [A] [B] [C]                 │
│                              │
└──────────────────────────────┘
```

and the user adds `D`.

A naive system might choose:

```text
[A] [B] [C]       [D]
```

at some arbitrary empty point.

A human would probably choose:

```text
[A] [B] [C] [D]
```

because:

* same row
* same orientation
* similar spacing
* adjacent
* easy to understand
* makes efficient use of space

So now we need to understand **relationships between objects**, not merely collision.

---

# 5.5A.3.2 Create `SpatialNeighbor`

Create:

```text
lib/application/spatial/neighbors/spatial_neighbor.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

enum NeighborDirection {
  left,
  right,
  front,
  back,
  above,
  below,
  overlapping,
  nearby,
}

class SpatialNeighbor {
  final String entityId;

  final NeighborDirection direction;

  final double distance;

  final Vector3 offset;

  const SpatialNeighbor({
    required this.entityId,
    required this.direction,
    required this.distance,
    required this.offset,
  });
}
```

This gives us a semantic description:

```text
cargo-002
    right of
cargo-001
    distance = 0.1m
```

instead of merely:

```text
position = (4.2, 1.0, 2.7)
```

---

# 5.5A.3.3 Create `NeighborAnalyzer`

```text
lib/application/spatial/neighbors/neighbor_analyzer.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import '../spatial_world.dart';
import 'spatial_neighbor.dart';

class NeighborAnalyzer {
  final double nearbyDistance;

  const NeighborAnalyzer({
    this.nearbyDistance = 2.0,
  });

  List<SpatialNeighbor> findNeighbors(
    String entityId,
    SpatialWorld world,
  ) {
    final subject =
        world.component(entityId);

    if (subject == null) {
      return const [];
    }

    final result =
        <SpatialNeighbor>[];

    for (final entry
        in world.components.entries) {
      if (entry.key == entityId) {
        continue;
      }

      final other = entry.value;

      final offset =
          other.position - subject.position;

      final distance =
          offset.length;

      if (distance > nearbyDistance) {
        continue;
      }

      result.add(
        SpatialNeighbor(
          entityId: entry.key,
          direction: _direction(offset),
          distance: distance,
          offset: offset,
        ),
      );
    }

    result.sort(
      (a, b) =>
          a.distance.compareTo(b.distance),
    );

    return result;
  }

  NeighborDirection _direction(
    Vector3 offset,
  ) {
    final absX = offset.x.abs();
    final absY = offset.y.abs();
    final absZ = offset.z.abs();

    if (absY > absX && absY > absZ) {
      return offset.y > 0
          ? NeighborDirection.above
          : NeighborDirection.below;
    }

    if (absX > absZ) {
      return offset.x > 0
          ? NeighborDirection.right
          : NeighborDirection.left;
    }

    if (absZ > 0) {
      return offset.z > 0
          ? NeighborDirection.front
          : NeighborDirection.back;
    }

    return NeighborDirection.overlapping;
  }
}
```

This is intentionally simple for now.

---

# 5.5A.3.4 But position alone isn't enough

Imagine:

```text
A: 2m wide
B: 0.5m wide
```

Their centers might be:

```text
A center = 0
B center = 1.2
```

But that doesn't tell us whether they're actually adjacent.

We need **bounds-to-bounds distance**.

So add:

```dart
double distanceBetweenBounds(
  Bounds a,
  Bounds b,
) {
  final dx = _axisDistance(
    a.min.x,
    a.max.x,
    b.min.x,
    b.max.x,
  );

  final dy = _axisDistance(
    a.min.y,
    a.max.y,
    b.min.y,
    b.max.y,
  );

  final dz = _axisDistance(
    a.min.z,
    a.max.z,
    b.min.z,
    b.max.z,
  );

  return Vector3(
    dx,
    dy,
    dz,
  ).length;
}

double _axisDistance(
  double minA,
  double maxA,
  double minB,
  double maxB,
) {
  if (maxA < minB) {
    return minB - maxA;
  }

  if (maxB < minA) {
    return minA - maxB;
  }

  return 0;
}
```

Now:

```text
touching objects
distance = 0
```

while:

```text
10cm gap
distance = 0.1
```

This is much more useful for packing.

---

# 5.5A.3.5 Introduce `NeighborRelation`

Eventually we want more semantic information.

```dart
enum NeighborRelation {
  adjacent,
  near,
  leftOf,
  rightOf,
  inFrontOf,
  behind,
  above,
  below,
  aligned,
  sameRow,
  sameColumn,
}
```

A pair of objects might have:

```text
A
│
├── rightOf B
├── adjacentTo B
├── alignedWith B
└── sameRowAs B
```

This is where the system starts becoming a **spatial reasoning engine**.

---

# 5.5A.3.6 Create a `NeighborPattern`

Now we need to describe what kind of arrangement we want.

```dart
class NeighborPattern {
  final double desiredSpacing;

  final double spacingTolerance;

  final bool preferAlignment;

  final bool preferSameOrientation;

  const NeighborPattern({
    this.desiredSpacing = 0.05,
    this.spacingTolerance = 0.02,
    this.preferAlignment = true,
    this.preferSameOrientation = true,
  });
}
```

This is deliberately generic.

For a warehouse:

```text
desiredSpacing = 0.05
```

For restaurant chairs:

```text
desiredSpacing = 0.10
```

For products on a retail shelf:

```text
desiredSpacing = 0.01
```

For parked vehicles:

```text
desiredSpacing = 0.50
```

The engine doesn't know what the objects are.

---

# 5.5A.3.7 Generate neighbor-based candidates

Create:

```text
neighbor_candidate_generator.dart
```

The idea is:

```text
existing object
      │
      ▼
measure its bounds
      │
      ▼
expand by desired gap
      │
      ▼
create candidate beside it
```

For example:

```text
[A]
```

becomes:

```text
[A] [candidate]
```

---

# 5.5A.3.8 Adjacent candidate generation

```dart
List<PlacementCandidate>
generateAdjacentCandidates({
  required SpatialComponent subject,
  required SpatialComponent neighbor,
  required String neighborId,
  required double spacing,
}) {
  final result =
      <PlacementCandidate>[];

  final neighborBounds =
      neighbor.worldBounds;

  final subjectHalfWidth =
      subject.localBounds.width / 2;

  final subjectHalfDepth =
      subject.localBounds.depth / 2;

  // Right
  result.add(
    PlacementCandidate(
      position: Vector3(
        neighborBounds.max.x +
            subjectHalfWidth +
            spacing,
        subject.position.y,
        neighbor.position.z,
      ),
      source: CandidateSource.neighbor,
    ),
  );

  // Left
  result.add(
    PlacementCandidate(
      position: Vector3(
        neighborBounds.min.x -
            subjectHalfWidth -
            spacing,
        subject.position.y,
        neighbor.position.z,
      ),
      source: CandidateSource.neighbor,
    ),
  );

  // Front
  result.add(
    PlacementCandidate(
      position: Vector3(
        neighbor.position.x,
        subject.position.y,
        neighborBounds.max.z +
            subjectHalfDepth +
            spacing,
      ),
      source: CandidateSource.neighbor,
    ),
  );

  // Back
  result.add(
    PlacementCandidate(
      position: Vector3(
        neighbor.position.x,
        subject.position.y,
        neighborBounds.min.z -
            subjectHalfDepth -
            spacing,
      ),
      source: CandidateSource.neighbor,
    ),
  );

  return result;
}
```

This creates:

```text
        ↑ front

          [candidate]
               ↑
             [A]
               ↓
          [candidate]

left ← [A] → right
```

---

# 5.5A.3.9 But this has a serious problem

Suppose:

```text
[A] [B] [C]
```

We place `D`.

If we independently generate around A, B, C:

```text
around A:
    left
    right

around B:
    left
    right

around C:
    left
    right
```

we may get duplicate or conflicting candidates.

That's okay.

**Candidate generation is allowed to be redundant.**

The scorer will determine which one is best.

This is actually a useful principle:

> Generate many plausible candidates cheaply; let constraints and scoring eliminate the bad ones.

---

# 5.5A.3.10 Neighbor scorer

Now the interesting part.

Create:

```text
neighbor_scorer.dart
```

```dart
class NeighborScorer
    implements PlacementScorer {
  final NeighborAnalyzer analyzer;

  const NeighborScorer(
    this.analyzer,
  );

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    var score = 0.0;

    final subject =
        world.component(
      request.subjectId,
    );

    if (subject == null) {
      return 0;
    }

    for (final entry
        in world.components.entries) {
      if (entry.key ==
          request.subjectId) {
        continue;
      }

      final neighbor =
          entry.value;

      final distance =
          candidate.position.distanceTo(
        neighbor.position,
      );

      if (distance > 2.0) {
        continue;
      }

      score +=
          1.0 / (1.0 + distance);
    }

    return score;
  }
}
```

This gives a basic preference:

```text
closer to existing objects
        ↓
higher score
```

But that's not enough.

We don't want:

```text
[ A ][ B ][ C ]
        ↓
       [D]
```

simply because D is close.

We want D to be close **in the right direction**.

---

# 5.5A.3.11 Add alignment scoring

Suppose:

```text
[A] [B] [C]
```

Their centers are:

```text
A = (0,0)
B = (1,0)
C = (2,0)
```

Candidate:

```text
D = (3,0)
```

Excellent.

But:

```text
D = (3,0.7)
```

should be worse.

So:

```dart
double alignmentScore(
  Vector3 candidate,
  Vector3 neighbor,
) {
  final delta =
      candidate - neighbor;

  final lateralOffset =
      delta.z.abs();

  return 1.0 /
      (1.0 + lateralOffset);
}
```

For another axis:

```dart
double rowAlignmentScore(
  Vector3 candidate,
  Vector3 neighbor,
) {
  final offset =
      (candidate.z - neighbor.z).abs();

  return 1.0 /
      (1.0 + offset);
}
```

Now:

```text
same row
    ↓
high score
```

---

# 5.5A.3.12 Add orientation alignment

If:

```text
A → 0°
B → 0°
C → 0°
```

then:

```text
D → 0°
```

should be preferred.

If:

```text
D → 37°
```

it should score lower.

```dart
double orientationScore(
  Vector3 candidateRotation,
  Vector3 neighborRotation,
) {
  final difference =
      (candidateRotation.y -
              neighborRotation.y)
          .abs();

  return 1.0 /
      (1.0 + difference);
}
```

This will become more sophisticated when we support quaternions.

---

# 5.5A.3.13 Composite neighbor score

Now:

```dart
class NeighborPatternScorer
    implements PlacementScorer {
  final NeighborPattern pattern;

  const NeighborPatternScorer({
    this.pattern =
        const NeighborPattern(),
  });

  @override
  double score(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(
      request.subjectId,
    );

    if (subject == null) {
      return 0;
    }

    var score = 0.0;

    for (final entry
        in world.components.entries) {
      if (entry.key ==
          request.subjectId) {
        continue;
      }

      final neighbor =
          entry.value;

      final distance =
          candidate.position.distanceTo(
        neighbor.position,
      );

      if (distance > 2.0) {
        continue;
      }

      // Proximity
      score +=
          1.0 / (1.0 + distance);

      // Horizontal alignment
      if (pattern.preferAlignment) {
        final lateral =
            (candidate.position.z -
                    neighbor.position.z)
                .abs();

        score +=
            1.0 / (1.0 + lateral);
      }

      // Orientation
      if (pattern.preferSameOrientation) {
        final rotationDifference =
            (candidate.rotation.y -
                    neighbor.rotation.y)
                .abs();

        score +=
            1.0 /
                (1.0 +
                    rotationDifference);
      }
    }

    return score;
  }
}
```

---

# 5.5A.3.14 But now we hit the next important problem

We are assuming:

```text
all nearby objects should influence placement
```

That's not always correct.

For example:

```text
restaurant:

table
chair
plant
wall
floor
lamp
```

If we're placing a chair, the table matters much more than the plant.

So we need:

```text
neighbor relevance
```

---

# 5.5A.3.15 Add semantic compatibility

We don't want:

```text
chair → nearest plant
```

to dominate placement.

Instead, the system should eventually know:

```text
chair
  prefers:
    table
    desk
    counter
```

while:

```text
cargo
  prefers:
    cargo
    rack
    shelf
    container
```

This should **not** be hardcoded in the spatial engine.

Create a generic relation descriptor:

```dart
class SpatialRelationPreference {
  final String relation;

  final double weight;

  const SpatialRelationPreference({
    required this.relation,
    required this.weight,
  });
}
```

Later this can come from your domain schema.

---

# 5.5A.3.16 Don't make `type == "chair"` inside the engine

Avoid this:

```dart
if (entity.type == 'chair') ...
```

That destroys platform agnosticism.

Instead:

```text
Entity
  │
  ▼
Semantic capabilities
  │
  ├── canBePlaced
  ├── canSupport
  ├── canContain
  ├── canAttach
  └── preferredRelations
```

This is a key design direction for your platform.

---

# 5.5A.3.17 Introduce capabilities

Eventually:

```dart
class SpatialCapabilities {
  final bool canContain;

  final bool canSupport;

  final bool canBeContained;

  final bool canBeStacked;

  final bool canAttach;

  const SpatialCapabilities({
    this.canContain = false,
    this.canSupport = false,
    this.canBeContained = false,
    this.canBeStacked = false,
    this.canAttach = false,
  });
}
```

Now a generic object can declare:

```text
rack:
    canContain = true
    canSupport = true
```

Cargo:

```text
canBeContained = true
canBeStacked = true
```

Chair:

```text
canBePlaced = true
```

Table:

```text
canSupport = true
```

Again, the engine remains generic.

---

# 5.5A.3.18 Packing becomes a generic problem

We can now describe patterns like:

### Linear packing

```text
[A][B][C][D][E]
```

### Grid packing

```text
[A][B][C]
[D][E][F]
[G][H][I]
```

### Stacking

```text
[A]
[B]
[C]
```

### Radial arrangement

```text
       A

   B       C

       D
```

### Perimeter arrangement

```text
   A   A   A
 A           A
 A   TABLE   A
 A           A
   A   A   A
```

### Anchor-based arrangement

```text
table
├── seat
├── seat
├── seat
└── seat
```

The engine doesn't need to know the domain.

It needs to know the **spatial pattern**.

---

# 5.5A.3.19 Introduce `PackingPattern`

```dart
enum PackingPatternType {
  free,
  linear,
  grid,
  stack,
  radial,
  perimeter,
  anchored,
}
```

And:

```dart
class PackingPattern {
  final PackingPatternType type;

  final double spacing;

  final bool alignOrientation;

  const PackingPattern({
    this.type = PackingPatternType.free,
    this.spacing = 0.05,
    this.alignOrientation = true,
  });
}
```

Now your placement request can eventually say:

```text
pattern = linear
```

or:

```text
pattern = grid
```

without knowing whether the objects are:

```text
cargo
chairs
books
products
vehicles
machines
```

---

# 5.5A.3.20 Add a `NeighborCandidateGenerator`

Now:

```dart
class NeighborCandidateGenerator
    implements CandidateGenerator {
  final NeighborAnalyzer analyzer;

  final double spacing;

  const NeighborCandidateGenerator({
    required this.analyzer,
    this.spacing = 0.05,
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

    for (final entry
        in world.components.entries) {
      if (entry.key ==
          request.subjectId) {
        continue;
      }

      final neighbor =
          entry.value;

      candidates.addAll(
        _generateAroundNeighbor(
          subject,
          neighbor,
        ),
      );
    }

    return candidates;
  }

  List<PlacementCandidate>
      _generateAroundNeighbor(
    SpatialComponent subject,
    SpatialComponent neighbor,
  ) {
    final bounds =
        neighbor.worldBounds;

    final halfWidth =
        subject.localBounds.width / 2;

    final halfDepth =
        subject.localBounds.depth / 2;

    final y =
        subject.position.y;

    return [
      PlacementCandidate(
        position: Vector3(
          bounds.max.x +
              halfWidth +
              spacing,
          y,
          neighbor.position.z,
        ),
        source: CandidateSource.neighbor,
      ),
      PlacementCandidate(
        position: Vector3(
          bounds.min.x -
              halfWidth -
              spacing,
          y,
          neighbor.position.z,
        ),
        source: CandidateSource.neighbor,
      ),
      PlacementCandidate(
        position: Vector3(
          neighbor.position.x,
          y,
          bounds.max.z +
              halfDepth +
              spacing,
        ),
        source: CandidateSource.neighbor,
      ),
      PlacementCandidate(
        position: Vector3(
          neighbor.position.x,
          y,
          bounds.min.z -
              halfDepth -
              spacing,
        ),
        source: CandidateSource.neighbor,
      ),
    ];
  }
}
```

---

# 5.5A.3.21 Add it to the composite generator

Now:

```dart
final candidateGenerator =
    CompositeCandidateGenerator(
  generators: [
    const SurfaceCandidateGenerator(),
    const AnchorCandidateGenerator(),
    NeighborCandidateGenerator(
      analyzer:
          const NeighborAnalyzer(),
    ),
  ],
);
```

Now the system can consider:

```text
surface
+
anchors
+
neighbors
```

simultaneously.

---

# 5.5A.3.22 Important: neighbor candidates must still go through constraints

This is absolutely essential.

Suppose:

```text
[A][B][C]
```

and we generate:

```text
[D]
```

next to C.

But there is a wall:

```text
[A][B][C][D]│
```

The neighbor generator says:

```text
valid candidate
```

The collision constraint says:

```text
INVALID
```

So:

```text
candidate generation
```

never guarantees validity.

It only says:

> "This is worth considering."

That's the correct separation.

---

# 5.5A.3.23 Add spacing as a scoring preference

Now consider:

```text
[A]    [B]
```

with a new object.

Two candidates:

```text
[A][X]    [B]
```

and:

```text
[A]    [X][B]
```

Both may be valid.

We want uniform spacing.

Define:

```dart
double spacingScore(
  double actual,
  double desired,
) {
  final error =
      (actual - desired).abs();

  return 1.0 /
      (1.0 + error);
}
```

Then:

```text
actual = 0.05
desired = 0.05

score = 1.0
```

while:

```text
actual = 0.5
desired = 0.05

score ≈ low
```

---

# 5.5A.3.24 Now we can model "tidiness"

This may sound trivial, but it's extremely powerful.

A human doesn't merely avoid collision.

They prefer:

```text
aligned
uniform
accessible
organized
symmetrical
efficient
```

So later we can have:

```text
TidinessScore
```

made from:

```text
alignment
+
spacing consistency
+
orientation consistency
+
packing density
```

This can produce surprisingly human-like placement.

---

# 5.5A.3.25 Example: warehouse shelf

Existing:

```text
┌─────────────────────────────┐
│ [A] [B] [C]                │
└─────────────────────────────┘
```

User drags D here:

```text
                 D
                 ↓
┌─────────────────────────────┐
│ [A] [B] [C]           X     │
└─────────────────────────────┘
```

Candidate generator:

```text
C-right
C-left
B-right
B-left
grid positions
surface center
```

Constraints eliminate:

```text
A collision
B collision
C collision
outside shelf
```

Scorer ranks:

```text
C-right
    proximity       +0.9
    alignment       +0.9
    spacing         +1.0
    orientation     +1.0
    --------------------
    total           3.8
```

Result:

```text
┌─────────────────────────────┐
│ [A] [B] [C] [D]             │
└─────────────────────────────┘
```

That's the behavior we're looking for.

---

# 5.5A.3.26 Example: restaurant

Existing:

```text
        [Chair]
           ↑

[Chair]  TABLE  [Chair]
```

User drags another chair near the table.

Candidates:

```text
table anchor #1
table anchor #2
table anchor #3
table anchor #4
nearby grid positions
```

Constraints:

```text
collision
clearance
surface
accessibility
```

Scoring:

```text
anchor preference
+
distance
+
orientation
+
symmetry
```

Result:

```text
        [Chair]
           ↑

[Chair] TABLE [Chair]

        [Chair]
```

Again, no restaurant code inside the placement engine.

---

# 5.5A.3.27 Example: cargo stacking

Now:

```text
[A]
```

and user wants another cargo.

A stacking generator can produce:

```text
   [B]
   [A]
```

The candidate is:

```dart
PlacementCandidate(
  position: Vector3(
    neighbor.position.x,
    neighbor.worldBounds.max.y +
        subject.localBounds.height / 2,
    neighbor.position.z,
  ),
  source: CandidateSource.neighbor,
)
```

Then constraints determine:

```text
Does B actually fit?
Is A capable of supporting B?
Is weight allowed?
Is stacking allowed?
```

This is where our earlier `SpatialCapabilities` becomes useful.

---

# 5.5A.3.28 The key abstraction we're approaching

We're heading toward:

```text
SpatialRelationship
```

rather than:

```text
if warehouse
if restaurant
if cargo
if chair
```

For example:

```text
ON
INSIDE
ADJACENT_TO
ABOVE
BELOW
ATTACHED_TO
ALIGNED_WITH
STACKED_ON
NEAR
CONTAINED_BY
```

Then:

```text
cargo ON shelf
chair ADJACENT_TO table
product INSIDE cabinet
machine NEAR machine
vehicle INSIDE parking_area
person NEAR workstation
```

All use the same engine.

---

# 5.5A.3.29 One architectural change I'd make now

Our `PlacementRequest` currently probably has:

```dart
targetId
relation
preferredPosition
```

I'd extend it toward:

```dart
class PlacementRequest {
  final String subjectId;

  final String? targetId;

  final SpatialRelationType relation;

  final Vector3? preferredPosition;

  final double clearance;

  final PackingPattern? packingPattern;

  const PlacementRequest({
    required this.subjectId,
    this.targetId,
    required this.relation,
    this.preferredPosition,
    this.clearance = 0,
    this.packingPattern,
  });
}
```

Now a request can say:

```text
Place cargo-004
ON rack-001
using LINEAR packing
```

or:

```text
Place chair-008
ADJACENT_TO table-002
using PERIMETER packing
```

or:

```text
Place product-55
INSIDE cabinet-3
using GRID packing
```

Same request mechanism.

---

# 5.5A.3.30 The architecture after 5.5A.3

We now have:

```text
                         TwinState
                             │
                             ▼
                     SpatialWorld
                             │
                             ▼
                    PlacementRequest
                             │
             ┌───────────────┴───────────────┐
             ▼                               ▼
    Candidate Generators               Neighbor Analyzer
             │                               │
      ┌──────┼───────┐                       │
      ▼      ▼       ▼                       │
   Surface Anchor  Neighbor ◄────────────────┘
      │      │       │
      └──────┼───────┘
             ▼
       Candidate Pool
             │
             ▼
      ┌──────────────┐
      │ Constraints  │
      └──────┬───────┘
             │
             ▼
      Valid Candidates
             │
             ▼
       ┌───────────┐
       │  Scoring  │
       └─────┬─────┘
             │
             ▼
       Best Placement
```

This is becoming a serious reusable spatial engine.

---

# 5.5A.3.31 What we should build next

The next step, **5.5A.4**, should focus on **semantic spatial relations + anchors properly**.

That's important because we're currently using proximity heuristics, but the platform eventually needs to understand the difference between:

```text
ON
```

and:

```text
INSIDE
```

and:

```text
ADJACENT_TO
```

and:

```text
ATTACHED_TO
```

and:

```text
STACKED_ON
```

and:

```text
CONTAINED_BY
```

For example:

```text
warehouse:

cargo
  └── ON → shelf

shelf
  └── INSIDE → rack

rack
  └── INSIDE → warehouse
```

while:

```text
restaurant:

chair
  └── ADJACENT_TO → table

table
  └── INSIDE → dining_area
```

And eventually those relations should drive **different candidate generators and different constraints automatically**.

That is the point where your spatial system starts becoming a **generic semantic spatial reasoning layer**, rather than simply a placement/collision subsystem.
