Absolutely. **Step 5.5A is where we turn the spatial idea into actual code.**

The goal for this step is deliberately narrow:

> Build the minimum generic spatial kernel that can determine whether an object can be placed on/in/near another object, find a sensible position, and return a placement proposal.

We will **not** build a full physics engine yet.

---

# Step 5.5A — Spatial Kernel

Our first real vertical slice will be:

```text
Cargo Box
    ↓ drag/drop
Rack Shelf
    ↓
PlacementEngine
    ├── geometry
    ├── collision
    ├── clearance
    ├── support
    ├── bounds
    └── scoring
    ↓
PlacementResult
    ↓
TwinCommand(move)
    ↓
TwinRuntime
```

The first test case:

```text
┌─────────────────────────────┐
│           RACK              │
│                             │
│   ┌───────────────┐         │
│   │    CARGO      │ ← place │
│   └───────────────┘         │
│────────── SHELF ────────────│
│                             │
└─────────────────────────────┘
```

---

# 5.5A.1 Create the spatial folder

I'd structure it like this:

```text
lib/
├── domain/
│   ├── core/
│   ├── interaction/
│   ├── scene/
│   │
│   └── spatial/
│       ├── bounds.dart
│       ├── transform.dart
│       ├── collision_shape.dart
│       ├── spatial_model.dart
│       ├── spatial_relation.dart
│       ├── spatial_anchor.dart
│       ├── placement_surface.dart
│       ├── placement_request.dart
│       └── placement_result.dart
│
└── application/
    └── spatial/
        ├── collision_detector.dart
        ├── placement_candidate.dart
        ├── placement_strategy.dart
        ├── placement_engine.dart
        └── surface_placement_strategy.dart
```

The separation is intentional:

```text
domain/spatial
    ↓
pure concepts/data

application/spatial
    ↓
algorithms/behavior
```

---

# 5.5A.2 `Bounds`

Start with axis-aligned bounding boxes.

Create:

```text
lib/domain/spatial/bounds.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

class Bounds {
  final Vector3 min;
  final Vector3 max;

  const Bounds({
    required this.min,
    required this.max,
  });

  Vector3 get size => max - min;

  Vector3 get center => (min + max) * 0.5;

  double get width => max.x - min.x;

  double get height => max.y - min.y;

  double get depth => max.z - min.z;

  double get volume =>
      width * height * depth;

  bool contains(Vector3 point) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y &&
        point.z >= min.z &&
        point.z <= max.z;
  }

  bool intersects(Bounds other) {
    return min.x <= other.max.x &&
        max.x >= other.min.x &&
        min.y <= other.max.y &&
        max.y >= other.min.y &&
        min.z <= other.max.z &&
        max.z >= other.min.z;
  }

  Bounds translated(Vector3 offset) {
    return Bounds(
      min: min + offset,
      max: max + offset,
    );
  }
}
```

This is our first collision primitive.

---

# 5.5A.3 Add clearance

Collision isn't enough.

Two objects can technically not intersect but still be too close.

Add:

```dart
Bounds expanded(double amount) {
  final expansion = Vector3.all(amount);

  return Bounds(
    min: min - expansion,
    max: max + expansion,
  );
}
```

So:

```dart
cargoBounds
    .expanded(0.1)
```

means:

> Treat the cargo as 10 cm larger for clearance checking.

Now:

```dart
cargoBounds
    .expanded(clearance)
    .intersects(otherBounds)
```

becomes our basic clearance test.

---

# 5.5A.4 `CollisionShape`

Now don't assume every object is a box.

Create:

```text
lib/domain/spatial/collision_shape.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import 'bounds.dart';

sealed class CollisionShape {
  const CollisionShape();

  Bounds boundsAt(Vector3 position);
}

class BoxCollisionShape extends CollisionShape {
  final Vector3 size;

  const BoxCollisionShape({
    required this.size,
  });

  @override
  Bounds boundsAt(Vector3 position) {
    final half = size * 0.5;

    return Bounds(
      min: position - half,
      max: position + half,
    );
  }
}

class SphereCollisionShape extends CollisionShape {
  final double radius;

  const SphereCollisionShape({
    required this.radius,
  });

  @override
  Bounds boundsAt(Vector3 position) {
    final r = Vector3.all(radius);

    return Bounds(
      min: position - r,
      max: position + r,
    );
  }
}
```

Notice something important:

We can now have:

```text
visual mesh
      ≠
collision shape
```

That is essential for performance.

---

# 5.5A.5 `SpatialModel`

Create:

```text
lib/domain/spatial/spatial_model.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import 'bounds.dart';
import 'collision_shape.dart';

class SpatialModel {
  final Vector3 position;

  final Vector3 rotation;

  final CollisionShape collisionShape;

  final Bounds localBounds;

  final String? parentId;

  const SpatialModel({
    required this.position,
    required this.collisionShape,
    required this.localBounds,
    this.rotation = Vector3.zero(),
    this.parentId,
  });

  Bounds get worldBounds {
    return collisionShape.boundsAt(position);
  }

  SpatialModel copyWith({
    Vector3? position,
    Vector3? rotation,
    CollisionShape? collisionShape,
    Bounds? localBounds,
    String? parentId,
  }) {
    return SpatialModel(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      collisionShape:
          collisionShape ?? this.collisionShape,
      localBounds:
          localBounds ?? this.localBounds,
      parentId: parentId ?? this.parentId,
    );
  }
}
```

For now rotation is stored but **not incorporated into AABB collision**.

That's deliberate.

We'll add oriented bounds later.

---

# 5.5A.6 Spatial relationships

Create:

```text
lib/domain/spatial/spatial_relation.dart
```

```dart
enum SpatialRelationType {
  inside,
  contains,

  on,
  supports,

  adjacentTo,

  near,
  far,

  overlaps,
  intersects,

  leftOf,
  rightOf,

  above,
  below,

  inFrontOf,
  behind,

  attachedTo,
  connectedTo,
}
```

Now your platform can represent:

```text
cargo → inside → rack
plate → on → table
chair → adjacentTo → table
table → inside → room
```

without knowing anything about warehouses or restaurants.

---

# 5.5A.7 `SpatialAnchor`

Create:

```text
lib/domain/spatial/spatial_anchor.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

enum SpatialAnchorType {
  placement,
  storage,
  seat,
  workstation,
  entrance,
  exit,
  connection,
}

class SpatialAnchor {
  final String id;

  final String hostEntityId;

  final Vector3 localPosition;

  final Vector3 rotation;

  final SpatialAnchorType type;

  const SpatialAnchor({
    required this.id,
    required this.hostEntityId,
    required this.localPosition,
    required this.type,
    this.rotation = Vector3.zero(),
  });

  Vector3 worldPosition(
    Vector3 hostPosition,
  ) {
    return hostPosition + localPosition;
  }
}
```

Example:

```text
rack
 ├── shelf-01
 ├── shelf-02
 └── shelf-03
```

Each shelf can eventually expose an anchor.

---

# 5.5A.8 Placement surfaces

Create:

```text
lib/domain/spatial/placement_surface.dart
```

```dart
import 'bounds.dart';

enum PlacementSurfaceType {
  horizontal,
  vertical,
  freeform,
}

class PlacementSurface {
  final String id;

  final String hostEntityId;

  final PlacementSurfaceType type;

  final Bounds bounds;

  final double height;

  const PlacementSurface({
    required this.id,
    required this.hostEntityId,
    required this.type,
    required this.bounds,
    required this.height,
  });
}
```

For a rack:

```text
rack
 ├── shelf-01
 ├── shelf-02
 └── shelf-03
```

each shelf can be a `PlacementSurface`.

For a table:

```text
table
 └── top
```

For a room:

```text
room
 └── floor
```

---

# 5.5A.9 Placement request

Create:

```text
lib/domain/spatial/placement_request.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import 'spatial_relation.dart';

class PlacementRequest {
  final String subjectId;

  final String targetId;

  final SpatialRelationType relation;

  final Vector3? preferredPosition;

  final double clearance;

  const PlacementRequest({
    required this.subjectId,
    required this.targetId,
    required this.relation,
    this.preferredPosition,
    this.clearance = 0,
  });
}
```

Example:

```dart
PlacementRequest(
  subjectId: 'cargo-001',
  targetId: 'rack-001',
  relation: SpatialRelationType.on,
  preferredPosition: Vector3(4, 2, 3),
  clearance: 0.1,
);
```

---

# 5.5A.10 Placement candidate

Create:

```text
lib/application/spatial/placement_candidate.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

class PlacementCandidate {
  final Vector3 position;

  final Vector3 rotation;

  final String? surfaceId;

  final String? anchorId;

  const PlacementCandidate({
    required this.position,
    this.rotation = Vector3.zero(),
    this.surfaceId,
    this.anchorId,
  });
}
```

Now the placement engine can generate several possible positions.

---

# 5.5A.11 Placement result

Create:

```text
lib/domain/spatial/placement_result.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

class PlacementResult {
  final bool valid;

  final Vector3? position;

  final Vector3? rotation;

  final String? surfaceId;

  final String? anchorId;

  final double score;

  final List<String> reasons;

  const PlacementResult({
    required this.valid,
    this.position,
    this.rotation,
    this.surfaceId,
    this.anchorId,
    this.score = 0,
    this.reasons = const [],
  });

  const PlacementResult.invalid(
    String reason,
  ) : valid = false,
       position = null,
       rotation = null,
       surfaceId = null,
       anchorId = null,
       score = 0,
       reasons = [reason];
}
```

This is much better than:

```text
bool canPlace
```

because the caller needs to know **why** and **where**.

---

# 5.5A.12 Collision detector

Create:

```text
lib/application/spatial/collision_detector.dart
```

```dart
import '../../domain/spatial/bounds.dart';

class CollisionDetector {
  const CollisionDetector();

  bool intersects(
    Bounds a,
    Bounds b, {
    double clearance = 0,
  }) {
    return a
        .expanded(clearance)
        .intersects(b);
  }
}
```

Later this becomes more sophisticated.

For now:

```text
AABB + clearance
```

is enough to get the architecture working.

---

# 5.5A.13 Create a generic spatial world

We need the placement engine to inspect the current world.

Create:

```text
lib/application/spatial/spatial_world.dart
```

```dart
import '../../domain/spatial/spatial_model.dart';
import '../../domain/spatial/placement_surface.dart';

class SpatialWorld {
  final Map<String, SpatialModel> models;

  final Map<String, List<PlacementSurface>> surfaces;

  const SpatialWorld({
    this.models = const {},
    this.surfaces = const {},
  });

  SpatialModel? model(
    String entityId,
  ) {
    return models[entityId];
  }

  List<PlacementSurface> surfacesFor(
    String entityId,
  ) {
    return surfaces[entityId] ?? const [];
  }
}
```

This is our spatial query layer.

---

# 5.5A.14 First placement strategy: on surface

Create:

```text
lib/application/spatial/surface_placement_strategy.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/spatial_relation.dart';
import '../../domain/spatial/placement_surface.dart';
import 'placement_candidate.dart';
import 'spatial_world.dart';

class SurfacePlacementStrategy {
  const SurfacePlacementStrategy();

  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.model(request.subjectId);

    if (subject == null) {
      return const [];
    }

    final surfaces =
        world.surfacesFor(request.targetId);

    final candidates = <PlacementCandidate>[];

    for (final surface in surfaces) {
      if (surface.type !=
          PlacementSurfaceType.horizontal) {
        continue;
      }

      final center =
          surface.bounds.center;

      final y =
          surface.height +
          subject.localBounds.height / 2;

      candidates.add(
        PlacementCandidate(
          position: Vector3(
            center.x,
            y,
            center.z,
          ),
          surfaceId: surface.id,
        ),
      );
    }

    return candidates;
  }
}
```

This gives us our first actual snap behavior.

---

# 5.5A.15 But center-only isn't enough

Suppose the shelf is:

```text
2m wide
```

and the cargo is:

```text
0.5m wide
```

The center is valid.

But if the user drops near the left edge, we'd like the object to remain near that position if possible.

So add candidate generation around the preferred position.

```dart
Vector3 _clampToSurface(
  Vector3 preferred,
  PlacementSurface surface,
  double halfWidth,
  double halfDepth,
) {
  final minX =
      surface.bounds.min.x + halfWidth;

  final maxX =
      surface.bounds.max.x - halfWidth;

  final minZ =
      surface.bounds.min.z + halfDepth;

  final maxZ =
      surface.bounds.max.z - halfDepth;

  return Vector3(
    preferred.x.clamp(minX, maxX),
    surface.height,
    preferred.z.clamp(minZ, maxZ),
  );
}
```

Then:

```text
user drops here
        ↓
   ┌───────────────┐
   │      X        │
   │               │
   └───────────────┘
        ↓
candidate stays near X
```

rather than always snapping to center.

---

# 5.5A.16 Generate several candidates

I'd generate:

```text
center
preferred
preferred + small offsets
corners
grid points
anchors
```

For example:

```dart
List<Vector3> _candidatePoints(
  PlacementSurface surface,
  Vector3? preferred,
) {
  final center = surface.bounds.center;

  final points = <Vector3>[
    center,
  ];

  if (preferred != null) {
    points.add(preferred);

    points.add(
      preferred + Vector3(0.1, 0, 0),
    );

    points.add(
      preferred + Vector3(-0.1, 0, 0),
    );

    points.add(
      preferred + Vector3(0, 0, 0.1),
    );

    points.add(
      preferred + Vector3(0, 0, -0.1),
    );
  }

  return points;
}
```

Later we'll replace this with a proper spatial sampling strategy.

---

# 5.5A.17 The placement engine

Now the important piece.

Create:

```text
lib/application/spatial/placement_engine.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/placement_result.dart';
import '../../domain/spatial/spatial_relation.dart';
import 'collision_detector.dart';
import 'placement_candidate.dart';
import 'surface_placement_strategy.dart';
import 'spatial_world.dart';

class PlacementEngine {
  final CollisionDetector collisionDetector;

  final SurfacePlacementStrategy surfaceStrategy;

  const PlacementEngine({
    required this.collisionDetector,
    required this.surfaceStrategy,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.model(request.subjectId);

    if (subject == null) {
      return const PlacementResult.invalid(
        'Subject does not exist',
      );
    }

    final target =
        world.model(request.targetId);

    if (target == null) {
      return const PlacementResult.invalid(
        'Target does not exist',
      );
    }

    final candidates =
        _generateCandidates(
      request,
      world,
    );

    if (candidates.isEmpty) {
      return const PlacementResult.invalid(
        'No placement candidates',
      );
    }

    PlacementResult? best;

    for (final candidate in candidates) {
      final result =
          _evaluateCandidate(
        candidate,
        request,
        world,
      );

      if (!result.valid) {
        continue;
      }

      if (best == null ||
          result.score > best.score) {
        best = result;
      }
    }

    return best ??
        const PlacementResult.invalid(
          'No valid placement found',
        );
  }

  List<PlacementCandidate> _generateCandidates(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    switch (request.relation) {
      case SpatialRelationType.on:
      case SpatialRelationType.supports:
        return surfaceStrategy.generate(
          request,
          world,
        );

      default:
        return const [];
    }
  }

  PlacementResult _evaluateCandidate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.model(request.subjectId)!;

    final candidateBounds =
        subject.collisionShape
            .boundsAt(candidate.position);

    final surface =
        candidate.surfaceId == null
            ? null
            : _findSurface(
                candidate.surfaceId!,
                world,
              );

    if (surface == null) {
      return const PlacementResult.invalid(
        'Surface does not exist',
      );
    }

    if (!_fitsSurface(
      candidateBounds,
      surface!,
    )) {
      return const PlacementResult.invalid(
        'Object does not fit on surface',
      );
    }

    if (_collides(
      candidateBounds,
      request,
      world,
    )) {
      return const PlacementResult.invalid(
        'Placement causes collision',
      );
    }

    final score = _score(
      candidate,
      request,
    );

    return PlacementResult(
      valid: true,
      position: candidate.position,
      rotation: candidate.rotation,
      surfaceId: candidate.surfaceId,
      anchorId: candidate.anchorId,
      score: score,
      reasons: const [
        'fits surface',
        'no collision',
        'supported',
      ],
    );
  }

  bool _fitsSurface(
    dynamic objectBounds,
    dynamic surface,
  ) {
    return objectBounds.min.x >=
            surface.bounds.min.x &&
        objectBounds.max.x <=
            surface.bounds.max.x &&
        objectBounds.min.z >=
            surface.bounds.min.z &&
        objectBounds.max.z <=
            surface.bounds.max.z;
  }

  bool _collides(
    dynamic candidateBounds,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    for (final entry
        in world.models.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final bounds =
          entry.value.worldBounds;

      if (collisionDetector.intersects(
        candidateBounds,
        bounds,
        clearance: request.clearance,
      )) {
        return true;
      }
    }

    return false;
  }

  double _score(
    PlacementCandidate candidate,
    PlacementRequest request,
  ) {
    if (request.preferredPosition == null) {
      return 1;
    }

    final distance =
        candidate.position.distanceTo(
      request.preferredPosition!,
    );

    return 1 / (1 + distance);
  }

  dynamic _findSurface(
    String id,
    SpatialWorld world,
  ) {
    for (final surfaces
        in world.surfaces.values) {
      for (final surface in surfaces) {
        if (surface.id == id) {
          return surface;
        }
      }
    }

    return null;
  }
}
```

There are a couple of things I'd clean up immediately before committing this code.

Specifically, don't use `dynamic` here.

Use the actual types:

```dart
bool _fitsSurface(
  Bounds objectBounds,
  PlacementSurface surface,
)
```

and:

```dart
PlacementSurface? _findSurface(...)
```

That gives us proper compile-time safety.

---

# 5.5A.18 The important algorithm

We now have:

```text
PlacementRequest
       │
       ▼
Generate candidates
       │
       ├── center
       ├── preferred
       ├── nearby
       └── anchors
       │
       ▼
For each candidate
       │
       ├── fits surface?
       │
       ├── collision?
       │
       ├── clearance?
       │
       ├── support?
       │
       ▼
      score
       │
       ▼
best valid candidate
```

This is the heart of the system.

---

# 5.5A.19 First real warehouse example

Let's create:

```text
rack-001
```

with:

```text
position = (0, 0, 0)
size = (2, 3, 1)
```

and shelf:

```text
shelf-001
bounds:
x = -1 → +1
z = -0.5 → +0.5
height = 1.5
```

Cargo:

```text
cargo-001
size = (0.5, 0.5, 0.5)
```

Then:

```text
cargo
half-height = 0.25

shelf height = 1.5

cargo center y = 1.5 + 0.25
              = 1.75
```

So the placement becomes:

```text
cargo.position.y = 1.75
```

That's already much more meaningful than:

```text
cargo.position.y = 1.5
```

because the object is actually sitting **on** the surface rather than intersecting it.

---

# 5.5A.20 Collision example

Suppose another cargo is already here:

```text
cargo-002
position = (0, 1.75, 0)
size = (0.5, 0.5, 0.5)
```

New cargo wants:

```text
position = (0, 1.75, 0)
```

Their bounds overlap.

Therefore:

```text
PlacementResult
    valid = false
    reason = "Placement causes collision"
```

The engine then tries another candidate:

```text
x = 0.6
```

If that fits:

```text
valid = true
score = ...
```

This is the beginning of actual spatial reasoning.

---

# 5.5A.21 Clearance example

Suppose cargo width is:

```text
0.5m
```

and we require:

```text
0.1m clearance
```

Then collision checking effectively treats it as:

```text
0.7m
```

wide.

So two boxes cannot be packed arbitrarily tightly.

Later, clearance can be directional:

```text
front clearance
back clearance
left clearance
right clearance
top clearance
```

which becomes useful for:

```text
doors
machines
maintenance access
chairs
walkways
forklifts
```

---

# 5.5A.22 Support is different from collision

This is an important distinction.

An object can be:

```text
not colliding
```

but still:

```text
not supported
```

Example:

```text
       cargo
         □

         ↓

     20cm gap

──────────────
     shelf
```

No collision.

But invalid placement.

So eventually we need:

```text
SupportConstraint
```

For Step 5.5A, implement the simple version:

```text
object bottom ≈ surface height
```

with a tolerance.

```dart
bool isSupported(
  Bounds objectBounds,
  double surfaceHeight,
) {
  const tolerance = 0.01;

  return (objectBounds.min.y -
          surfaceHeight)
      .abs() <= tolerance;
}
```

Now the placement engine validates:

```text
collision = false
+
support = true
```

---

# 5.5A.23 Add support to `PlacementEngine`

Inside candidate evaluation:

```dart
if (!isSupported(
  candidateBounds,
  surface.height,
)) {
  return const PlacementResult.invalid(
    'Object is not supported by surface',
  );
}
```

Now our result reasons become:

```text
valid

fits surface
no collision
supported
```

That's much more meaningful.

---

# 5.5A.24 Don't confuse containment and support

This is another important abstraction.

For:

```text
cargo → rack
```

the relation might be:

```text
inside
```

while support may come from:

```text
rack.shelf-02
```

So:

```text
Cargo
 └── inside Rack
       │
       └── supported by Shelf 02
```

For:

```text
plate → table
```

it's:

```text
Plate
 └── on Table
       │
       └── supported by Table.top
```

This is why we need **both relations and surfaces**.

---

# 5.5A.25 First test

Create:

```text
test/application/spatial/placement_engine_test.dart
```

Test:

```dart
test(
  'places cargo on rack shelf',
  () {
    final cargo = SpatialModel(
      position: Vector3(0, 0, 0),
      collisionShape:
          const BoxCollisionShape(
        size: Vector3(0.5, 0.5, 0.5),
      ),
      localBounds: Bounds(
        min: Vector3(-0.25, -0.25, -0.25),
        max: Vector3(0.25, 0.25, 0.25),
      ),
    );

    final rack = SpatialModel(
      position: Vector3.zero(),
      collisionShape:
          const BoxCollisionShape(
        size: Vector3(2, 3, 1),
      ),
      localBounds: Bounds(
        min: Vector3(-1, 0, -0.5),
        max: Vector3(1, 3, 0.5),
      ),
    );

    final shelf = PlacementSurface(
      id: 'shelf-01',
      hostEntityId: 'rack-01',
      type: PlacementSurfaceType.horizontal,
      bounds: Bounds(
        min: Vector3(-1, 1.5, -0.5),
        max: Vector3(1, 1.5, 0.5),
      ),
      height: 1.5,
    );

    final world = SpatialWorld(
      models: {
        'cargo-01': cargo,
        'rack-01': rack,
      },
      surfaces: {
        'rack-01': [
          shelf,
        ],
      },
    );

    final engine = PlacementEngine(
      collisionDetector:
          const CollisionDetector(),
      surfaceStrategy:
          const SurfacePlacementStrategy(),
    );

    final result =
        engine.findPlacement(
      const PlacementRequest(
        subjectId: 'cargo-01',
        targetId: 'rack-01',
        relation: SpatialRelationType.on,
      ),
      world,
    );

    expect(result.valid, true);

    expect(
      result.position!.y,
      1.75,
    );

    expect(
      result.surfaceId,
      'shelf-01',
    );
  },
);
```

This test is important because it proves:

```text
generic cargo
+
generic rack
+
generic surface
=
valid placement
```

No warehouse-specific class exists.

---

# 5.5A.26 Second test: collision rejection

Add another cargo:

```dart
final existingCargo = SpatialModel(
  position: Vector3(0, 1.75, 0),
  collisionShape:
      const BoxCollisionShape(
    size: Vector3(0.5, 0.5, 0.5),
  ),
  localBounds: Bounds(
    min: Vector3(-0.25, -0.25, -0.25),
    max: Vector3(0.25, 0.25, 0.25),
  ),
);
```

Then:

```dart
models: {
  'cargo-01': cargo,
  'cargo-02': existingCargo,
  'rack-01': rack,
},
```

The engine should reject the candidate.

Eventually, after we add candidate sampling:

```text
candidate 1
    ↓ collision
candidate 2
    ↓ valid
```

and automatically move the new cargo to the next rational location.

---

# 5.5A.27 This is where we need to improve the first implementation

The initial engine I showed is intentionally minimal.

For the actual platform, I recommend we evolve it toward:

```text
PlacementEngine
       │
       ├── CandidateGenerator
       │
       ├── ConstraintEvaluator
       │
       ├── CollisionDetector
       │
       ├── SupportDetector
       │
       ├── BoundaryChecker
       │
       └── PlacementScorer
```

Instead of one giant class.

So the next refactor should look like:

```text
application/spatial/

candidate/
    candidate_generator.dart
    surface_candidate_generator.dart
    anchor_candidate_generator.dart

constraints/
    placement_constraint.dart
    collision_constraint.dart
    support_constraint.dart
    boundary_constraint.dart
    clearance_constraint.dart

scoring/
    placement_scorer.dart

engine/
    placement_engine.dart
```

This will scale much better.

---

# 5.5A.28 The really important future abstraction: `SpatialWorld`

Eventually `SpatialWorld` should not be a manually assembled map.

It should be generated from:

```text
TwinState
    ↓
SpatialProjection
    ↓
SpatialWorld
```

So:

```text
TwinEntity
 ├── SpatialComponent
 ├── GeometryComponent
 ├── CapacityComponent
 └── RelationComponent
```

becomes:

```text
SpatialWorld
 ├── models
 ├── surfaces
 ├── anchors
 └── relations
```

That keeps spatial reasoning as a **projection of twin state**, rather than another independent source of truth.

---

# 5.5A.29 Very important: don't store placement truth twice

Avoid:

```text
TwinState:
  cargo.position = X

SpatialWorld:
  cargo.position = Y
```

That will eventually create synchronization nightmares.

Instead:

```text
TwinState
    ↓
spatial projection
    ↓
SpatialWorld
```

So:

```text
TwinState = authoritative
SpatialWorld = derived/query representation
SceneGraph = derived/render representation
```

That's the architecture I recommend.

---

# 5.5A.30 Three levels of spatial truth

You now have:

```text
                    TwinState
                       │
                authoritative
                       │
                       ▼
                 SpatialWorld
                  reasoning
                       │
                       ▼
                  SceneGraph
                   rendering
```

And that gives us a clean rule:

### TwinState

"What is actually true?"

```text
cargo is at position X
cargo is inside rack
cargo is supported by shelf 2
```

### SpatialWorld

"Is X valid?"

```text
collision?
clearance?
capacity?
support?
```

### SceneGraph

"How should I display X?"

```text
mesh
transform
visibility
highlight
animation
```

This separation will become extremely valuable once simulation and AI arrive.

---

# 5.5A.31 How this eventually works with drag

The actual UI interaction becomes:

```text
USER DRAGS CARGO
       │
       ▼
Pointer position
       │
       ▼
Raycast / hit test
       │
       ▼
PlacementRequest
       │
       ▼
PlacementEngine
       │
       ├── candidate
       ├── collision
       ├── clearance
       ├── support
       └── scoring
       │
       ▼
PlacementResult
       │
       ├── valid
       │
       ▼
visual preview
       │
       ▼
USER RELEASES
       │
       ▼
TwinCommand(move)
       │
       ▼
TwinRuntime
```

That gives you the **game-style snapping behavior**.

---

# 5.5A.32 Preview vs commit

This is another architectural rule I strongly recommend.

During drag:

```text
PlacementEngine
```

should be called repeatedly.

But it should **not mutate TwinState**.

Instead:

```text
drag
 ↓
PlacementResult
 ↓
preview
```

Only when released:

```text
drop
 ↓
TwinCommand
 ↓
TwinRuntime
 ↓
TwinState
```

So:

```text
PREVIEW

pointer
 ↓
placement engine
 ↓
ghost object


COMMIT

pointer release
 ↓
placement engine
 ↓
TwinCommand
 ↓
TwinState
```

This avoids polluting the authoritative state with thousands of temporary drag positions.

---

# 5.5A.33 This also gives us undo/redo

Because final placement becomes a command:

```text
TwinCommand
    ↓
TwinEvent
```

we can later have:

```text
Command
 ↓
Event
 ↓
History
```

Then:

```text
Ctrl + Z
```

can undo:

```text
cargo moved
chair moved
table moved
machine moved
```

without special-case UI code.

---

# 5.5A.34 Where this goes next

After this first vertical slice works, I'd expand it in this order:

```text
5.5A.1  AABB geometry
        ↓
5.5A.2  Surface placement
        ↓
5.5A.3  Collision
        ↓
5.5A.4  Clearance
        ↓
5.5A.5  Support
        ↓
5.5A.6  Candidate sampling
        ↓
5.5A.7  Anchors
        ↓
5.5A.8  Containment
        ↓
5.5A.9  Adjacent placement
        ↓
5.5A.10 Capacity
        ↓
5.5A.11 Hard/soft constraints
        ↓
5.5A.12 Spatial indexing
        ↓
5.5A.13 Advanced geometry
```

---

# The target after 5.5A

We want to be able to write something like:

```dart
final result = placementEngine.findPlacement(
  PlacementRequest(
    subjectId: 'cargo-001',
    targetId: 'rack-001',
    relation: SpatialRelationType.on,
    preferredPosition: dropPosition,
    clearance: 0.1,
  ),
  spatialWorld,
);
```

and receive:

```text
PlacementResult
────────────────────────────

valid: true

position:
  x = 0.65
  y = 1.75
  z = -0.10

surface:
  rack-001/shelf-02

score:
  0.94

reasons:
  ✓ fits surface
  ✓ supported
  ✓ no collision
  ✓ clearance satisfied
  ✓ close to requested position
```

Then:

```text
PlacementResult
       ↓
TwinCommand(move)
       ↓
TwinRuntime
       ↓
TwinState
       ↓
SceneGraph
       ↓
3D renderer
```

And the **same exact engine** can later handle:

```text
cargo → rack shelf
plate → table
chair → table
table → room
bed → room
machine → production area
product → shelf
vehicle → parking slot
robot → charging station
```

without creating a new spatial engine for each domain.

## One thing I would *not* implement yet

Don't jump to a full Bullet/PhysX-style physics simulation.

For your platform, we first need:

**semantic placement + deterministic spatial constraints.**

Physics comes later for things like:

```text
gravity
falling
pushing
vehicle dynamics
fluid
deformation
```

Those belong to **Step 7 Simulation**, not the first spatial kernel.

The immediate next sub-step should be **5.5A.1 implementation hardening**: wire `SpatialComponent → SpatialWorld`, replace the temporary `dynamic` types, implement proper candidate sampling, and make the **cargo → rack shelf** example pass both **valid placement and collision-rejection tests** before touching restaurant/table/seat cases.
