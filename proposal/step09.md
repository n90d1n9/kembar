Great. **Step 5.5A.1 = implementation hardening + connecting the spatial layer to the actual Twin state.**

The goal now is to stop treating `SpatialWorld` as something manually constructed and make it a **derived spatial projection of your existing digital-twin state**.

The key architecture becomes:

```text
TwinState
   │
   ├── entities
   │      └── SpatialComponent
   │
   ▼
SpatialWorldBuilder
   │
   ▼
SpatialWorld
   │
   ▼
PlacementEngine
```

And importantly:

```text
TwinState = source of truth
SpatialWorld = derived/query representation
SceneGraph = rendering representation
```

---

# 5.5A.1.1 First, clean up the folder structure

Let's tighten what we created in 5.5A:

```text
lib/
├── domain/
│   ├── twin/
│   │   ├── twin_entity.dart
│   │   ├── twin_state.dart
│   │   └── ...
│   │
│   └── spatial/
│       ├── bounds.dart
│       ├── collision_shape.dart
│       ├── spatial_component.dart
│       ├── spatial_relation.dart
│       ├── spatial_anchor.dart
│       ├── placement_surface.dart
│       ├── placement_request.dart
│       └── placement_result.dart
│
├── application/
│   └── spatial/
│       ├── spatial_world.dart
│       ├── spatial_world_builder.dart
│       ├── collision_detector.dart
│       ├── placement_candidate.dart
│       ├── placement_strategy.dart
│       ├── surface_placement_strategy.dart
│       └── placement_engine.dart
│
└── infrastructure/
    └── ...
```

The important addition is:

```text
spatial_component.dart
spatial_world_builder.dart
```

---

# 5.5A.1.2 Create `SpatialComponent`

This should be the component attached to a generic `TwinEntity`.

```text
lib/domain/spatial/spatial_component.dart
```

```dart
import 'package:vector_math/vector_math_64.dart';

import 'bounds.dart';
import 'collision_shape.dart';
import 'placement_surface.dart';
import 'spatial_anchor.dart';

class SpatialComponent {
  final Vector3 position;

  final Vector3 rotation;

  final Vector3 scale;

  final CollisionShape collisionShape;

  final Bounds localBounds;

  final List<PlacementSurface> surfaces;

  final List<SpatialAnchor> anchors;

  final String? parentId;

  const SpatialComponent({
    required this.position,
    required this.collisionShape,
    required this.localBounds,
    this.rotation = Vector3.zero(),
    this.scale = Vector3.all(1),
    this.surfaces = const [],
    this.anchors = const [],
    this.parentId,
  });

  Bounds get worldBounds {
    return collisionShape.boundsAt(position);
  }

  SpatialComponent copyWith({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    CollisionShape? collisionShape,
    Bounds? localBounds,
    List<PlacementSurface>? surfaces,
    List<SpatialAnchor>? anchors,
    String? parentId,
  }) {
    return SpatialComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      collisionShape:
          collisionShape ?? this.collisionShape,
      localBounds:
          localBounds ?? this.localBounds,
      surfaces:
          surfaces ?? this.surfaces,
      anchors:
          anchors ?? this.anchors,
      parentId: parentId ?? this.parentId,
    );
  }
}
```

Now spatial information is a **component**, not something special about warehouses.

---

# 5.5A.1.3 Connect it to `TwinEntity`

Assuming your entity architecture has something similar to:

```dart
class TwinEntity {
  final String id;
  final String type;
  final Map<String, dynamic> components;
}
```

I'd move toward typed components.

For example:

```dart
class TwinEntity {
  final String id;

  final String type;

  final Map<Type, Object> components;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
  });

  T? component<T>() {
    return components[T] as T?;
  }

  TwinEntity withComponent<T>(
    T component,
  ) {
    return TwinEntity(
      id: id,
      type: type,
      components: {
        ...components,
        T: component,
      },
    );
  }
}
```

Then:

```dart
final spatial =
    entity.component<SpatialComponent>();
```

This is much safer than:

```dart
entity.data['position']
```

---

# 5.5A.1.4 Why this matters

Now the platform doesn't care what the entity is.

For example:

```text
TwinEntity
id = cargo-001
type = cargo
SpatialComponent
```

or:

```text
TwinEntity
id = chair-001
type = chair
SpatialComponent
```

or:

```text
TwinEntity
id = robot-001
type = robot
SpatialComponent
```

The spatial engine sees:

```text
SpatialComponent
```

not:

```text
Cargo
Chair
Robot
```

That is one of the central requirements for your agnostic architecture.

---

# 5.5A.1.5 Now fix `SpatialWorld`

Our previous version:

```dart
class SpatialWorld {
  final Map<String, SpatialModel> models;
  final Map<String, List<PlacementSurface>> surfaces;
}
```

is too fragmented.

Let's make the spatial world itself richer.

```dart
import '../../domain/spatial/spatial_component.dart';

class SpatialWorld {
  final Map<String, SpatialComponent> components;

  const SpatialWorld({
    this.components = const {},
  });

  SpatialComponent? component(
    String entityId,
  ) {
    return components[entityId];
  }

  List<SpatialComponent> get all =>
      components.values.toList();

  List<PlacementSurface> surfacesFor(
    String entityId,
  ) {
    return component(entityId)?.surfaces ??
        const [];
  }
}
```

Now the source of spatial truth inside the projection is simply:

```text
entityId → SpatialComponent
```

---

# 5.5A.1.6 Create `SpatialWorldBuilder`

This is the critical connection.

Create:

```text
lib/application/spatial/spatial_world_builder.dart
```

```dart
import '../../domain/twin/twin_state.dart';
import '../../domain/spatial/spatial_component.dart';
import 'spatial_world.dart';

class SpatialWorldBuilder {
  const SpatialWorldBuilder();

  SpatialWorld build(
    TwinState state,
  ) {
    final components =
        <String, SpatialComponent>{};

    for (final entity in state.entities.values) {
      final spatial =
          entity.component<SpatialComponent>();

      if (spatial == null) {
        continue;
      }

      components[entity.id] = spatial;
    }

    return SpatialWorld(
      components: components,
    );
  }
}
```

Now:

```text
TwinState
   ↓
SpatialWorldBuilder
   ↓
SpatialWorld
```

---

# 5.5A.1.7 This creates an important rule

Don't do this:

```dart
spatialWorld.move(
  cargoId,
  newPosition,
);
```

The spatial world shouldn't become authoritative.

Instead:

```text
User
 ↓
PlacementEngine
 ↓
PlacementResult
 ↓
TwinCommand
 ↓
TwinRuntime
 ↓
TwinState updated
 ↓
SpatialWorld rebuilt
```

So the flow is:

```text
                    ┌──────────────┐
                    │   TwinState  │
                    └──────┬───────┘
                           │
                           ▼
                  SpatialWorldBuilder
                           │
                           ▼
                    SpatialWorld
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
                    ┌──────────────┐
                    │   TwinState  │
                    │    update    │
                    └──────────────┘
```

This avoids two sources of truth.

---

# 5.5A.1.8 Fix `Bounds`

Our original `Bounds` should become slightly more robust.

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

  bool contains(
    Vector3 point,
  ) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y &&
        point.z >= min.z &&
        point.z <= max.z;
  }

  bool intersects(
    Bounds other,
  ) {
    return min.x < other.max.x &&
        max.x > other.min.x &&
        min.y < other.max.y &&
        max.y > other.min.y &&
        min.z < other.max.z &&
        max.z > other.min.z;
  }

  Bounds expanded(
    double amount,
  ) {
    final expansion =
        Vector3.all(amount);

    return Bounds(
      min: min - expansion,
      max: max + expansion,
    );
  }

  Bounds translated(
    Vector3 offset,
  ) {
    return Bounds(
      min: min + offset,
      max: max + offset,
    );
  }
}
```

Notice I changed:

```text
<=
>=
```

to:

```text
<
>
```

for intersection.

Why?

Two boxes that merely touch should generally **not be classified as penetrating each other**.

For example:

```text
cargo
┌─────┐
│     │
└─────┘
─────── shelf
```

Touching is valid support.

Intersection should mean actual overlap.

That's an important distinction.

---

# 5.5A.1.9 Separate collision from clearance

This is another cleanup.

Don't do:

```dart
intersects(
  expanded(clearance)
)
```

inside the fundamental collision detector.

Instead:

```dart
class CollisionDetector {
  const CollisionDetector();

  bool intersects(
    Bounds a,
    Bounds b,
  ) {
    return a.intersects(b);
  }

  bool violatesClearance(
    Bounds a,
    Bounds b,
    double clearance,
  ) {
    return a
        .expanded(clearance)
        .intersects(b);
  }
}
```

Now:

```text
collision
```

and:

```text
clearance violation
```

are different concepts.

That's important for the later constraint engine.

---

# 5.5A.1.10 Create a real `PlacementConstraint`

Instead of hardcoding:

```dart
if collision...
if support...
if fit...
```

inside `PlacementEngine`, introduce:

```text
lib/application/spatial/constraints/
```

Then:

```dart
abstract interface class PlacementConstraint {
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

And:

```dart
class PlacementConstraintResult {
  final bool satisfied;

  final String reason;

  const PlacementConstraintResult({
    required this.satisfied,
    required this.reason,
  });
}
```

This is a major architectural improvement.

---

# 5.5A.1.11 Collision constraint

```dart
class CollisionConstraint
    implements PlacementConstraint {
  final CollisionDetector detector;

  const CollisionConstraint(
    this.detector,
  );

  @override
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(request.subjectId);

    if (subject == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Subject not found',
      );
    }

    final candidateBounds =
        subject.collisionShape.boundsAt(
      candidate.position,
    );

    for (final entry
        in world.components.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      final otherBounds =
          entry.value.worldBounds;

      if (detector.intersects(
        candidateBounds,
        otherBounds,
      )) {
        return const PlacementConstraintResult(
          satisfied: false,
          reason: 'Collision detected',
        );
      }
    }

    return const PlacementConstraintResult(
      satisfied: true,
      reason: 'No collision',
    );
  }
}
```

Now collision is a pluggable constraint.

---

# 5.5A.1.12 Clearance constraint

```dart
class ClearanceConstraint
    implements PlacementConstraint {
  final CollisionDetector detector;

  const ClearanceConstraint(
    this.detector,
  );

  @override
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(request.subjectId);

    if (subject == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Subject not found',
      );
    }

    final candidateBounds =
        subject.collisionShape.boundsAt(
      candidate.position,
    );

    for (final entry
        in world.components.entries) {
      if (entry.key == request.subjectId) {
        continue;
      }

      if (detector.violatesClearance(
        candidateBounds,
        entry.value.worldBounds,
        request.clearance,
      )) {
        return const PlacementConstraintResult(
          satisfied: false,
          reason: 'Clearance violated',
        );
      }
    }

    return const PlacementConstraintResult(
      satisfied: true,
      reason: 'Clearance satisfied',
    );
  }
}
```

Now we have:

```text
CollisionConstraint
ClearanceConstraint
```

as independent units.

---

# 5.5A.1.13 Add surface-fit constraint

```dart
class SurfaceFitConstraint
    implements PlacementConstraint {
  const SurfaceFitConstraint();

  @override
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(request.subjectId);

    if (subject == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Subject not found',
      );
    }

    if (candidate.surfaceId == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'No surface selected',
      );
    }

    final surface =
        _findSurface(
      candidate.surfaceId!,
      world,
    );

    if (surface == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Surface not found',
      );
    }

    final bounds =
        subject.collisionShape.boundsAt(
      candidate.position,
    );

    final fits =
        bounds.min.x >=
            surface.bounds.min.x &&
        bounds.max.x <=
            surface.bounds.max.x &&
        bounds.min.z >=
            surface.bounds.min.z &&
        bounds.max.z <=
            surface.bounds.max.z;

    return PlacementConstraintResult(
      satisfied: fits,
      reason: fits
          ? 'Fits surface'
          : 'Does not fit surface',
    );
  }

  PlacementSurface? _findSurface(
    String id,
    SpatialWorld world,
  ) {
    for (final component
        in world.components.values) {
      for (final surface
          in component.surfaces) {
        if (surface.id == id) {
          return surface;
        }
      }
    }

    return null;
  }
}
```

---

# 5.5A.1.14 Add support constraint

```dart
class SupportConstraint
    implements PlacementConstraint {
  const SupportConstraint();

  @override
  PlacementConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(request.subjectId);

    if (subject == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Subject not found',
      );
    }

    if (candidate.surfaceId == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'No supporting surface',
      );
    }

    final surface =
        _findSurface(
      candidate.surfaceId!,
      world,
    );

    if (surface == null) {
      return const PlacementConstraintResult(
        satisfied: false,
        reason: 'Surface not found',
      );
    }

    final bounds =
        subject.collisionShape.boundsAt(
      candidate.position,
    );

    const tolerance = 0.01;

    final supported =
        (bounds.min.y -
                surface.height)
            .abs() <= tolerance;

    return PlacementConstraintResult(
      satisfied: supported,
      reason: supported
          ? 'Supported by surface'
          : 'Not supported by surface',
    );
  }

  PlacementSurface? _findSurface(
    String id,
    SpatialWorld world,
  ) {
    for (final component
        in world.components.values) {
      for (final surface
          in component.surfaces) {
        if (surface.id == id) {
          return surface;
        }
      }
    }

    return null;
  }
}
```

---

# 5.5A.1.15 Now the PlacementEngine becomes much cleaner

Instead of:

```text
giant PlacementEngine
```

we get:

```dart
class PlacementEngine {
  final List<PlacementConstraint> constraints;

  final SurfacePlacementStrategy
      surfaceStrategy;

  const PlacementEngine({
    required this.constraints,
    required this.surfaceStrategy,
  });

  PlacementResult findPlacement(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final candidates =
        _generateCandidates(
      request,
      world,
    );

    PlacementResult? best;

    for (final candidate in candidates) {
      final results =
          constraints.map(
        (constraint) =>
            constraint.evaluate(
          candidate,
          request,
          world,
        ),
      );

      final failures = results
          .where(
            (result) => !result.satisfied,
          )
          .toList();

      if (failures.isNotEmpty) {
        continue;
      }

      final score =
          _scoreCandidate(
        candidate,
        request,
      );

      final result = PlacementResult(
        valid: true,
        position: candidate.position,
        rotation: candidate.rotation,
        surfaceId: candidate.surfaceId,
        anchorId: candidate.anchorId,
        score: score,
        reasons: results
            .map((r) => r.reason)
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

  List<PlacementCandidate>
      _generateCandidates(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    switch (request.relation) {
      case SpatialRelationType.on:
        return surfaceStrategy.generate(
          request,
          world,
        );

      default:
        return const [];
    }
  }

  double _scoreCandidate(
    PlacementCandidate candidate,
    PlacementRequest request,
  ) {
    final preferred =
        request.preferredPosition;

    if (preferred == null) {
      return 1.0;
    }

    final distance =
        candidate.position.distanceTo(
      preferred,
    );

    return 1.0 / (1.0 + distance);
  }
}
```

That's much better.

---

# 5.5A.1.16 Configure the engine

Now the engine becomes composable:

```dart
final collisionDetector =
    const CollisionDetector();

final placementEngine =
    PlacementEngine(
  surfaceStrategy:
      const SurfacePlacementStrategy(),
  constraints: [
    CollisionConstraint(
      collisionDetector,
    ),
    ClearanceConstraint(
      collisionDetector,
    ),
    const SurfaceFitConstraint(),
    const SupportConstraint(),
  ],
);
```

This is the architecture we want.

Later we can simply add:

```dart
CapacityConstraint(...)
```

or:

```dart
AccessibilityConstraint(...)
```

without rewriting the engine.

---

# 5.5A.1.17 Hard vs soft constraints

We're also now in a good position to introduce this distinction.

Eventually:

```dart
abstract interface class PlacementConstraint {
  bool get isHard;

  PlacementConstraintResult evaluate(...);
}
```

Hard:

```text
collision
outside surface
unsupported
occupied slot
capacity exceeded
```

Soft:

```text
distance
alignment
preferred orientation
symmetry
```

The engine can then do:

```text
hard constraint fails
       ↓
reject

soft constraint fails
       ↓
reduce score
```

**Don't implement the full soft constraint system yet.**

But design the interfaces so we can add it without breaking today's code.

---

# 5.5A.1.18 The first proper test suite

We now want four tests.

### Test 1 — valid placement

```text
cargo → empty shelf
```

Expected:

```text
valid = true
```

### Test 2 — collision

```text
cargo → occupied location
```

Expected:

```text
valid = false
```

### Test 3 — outside shelf

```text
large cargo → small shelf
```

Expected:

```text
valid = false
```

### Test 4 — unsupported

```text
cargo floating above shelf
```

Expected:

```text
valid = false
```

This gives us the minimum trustworthy spatial kernel.

---

# 5.5A.1.19 Most important test: state → world

We should also test the architecture itself.

```text
TwinState
    ↓
SpatialWorldBuilder
    ↓
SpatialWorld
```

For example:

```dart
test(
  'builds spatial world from twin state',
  () {
    final entity =
        TwinEntity(
      id: 'cargo-001',
      type: 'cargo',
      components: {
        SpatialComponent: cargoSpatial,
      },
    );

    final state = TwinState(
      entities: {
        entity.id: entity,
      },
    );

    final world =
        const SpatialWorldBuilder()
            .build(state);

    expect(
      world.component('cargo-001'),
      isNotNull,
    );
  },
);
```

That test is actually more architecturally important than it looks.

It confirms:

```text
TwinState
```

is the source of truth.

---

# 5.5A.1.20 One thing I'd change from our earlier implementation

Earlier we had:

```dart
class SpatialModel
```

I would **not keep both**:

```text
SpatialModel
SpatialComponent
```

They're too similar.

For your architecture, use:

```text
SpatialComponent
```

as the domain-level spatial representation.

Then:

```text
SpatialWorld
```

contains those components for spatial querying.

So remove:

```text
spatial_model.dart
```

unless later we discover we need a distinct runtime projection type.

This keeps the model simpler.

---

# 5.5A.1.21 The resulting architecture

After this step, your spatial subsystem should conceptually be:

```text
                 TWIN DOMAIN
                     │
                     ▼
                TwinEntity
                     │
                     ├── Identity
                     ├── Properties
                     ├── Behavior
                     └── SpatialComponent
                              │
               ┌──────────────┼───────────────┐
               ▼              ▼               ▼
            Bounds        Collision       Surfaces
                              Shape          │
                                             ▼
                                          Anchors
                     │
                     ▼
                TwinState
                     │
                     ▼
             SpatialWorldBuilder
                     │
                     ▼
                SpatialWorld
                     │
                     ▼
             PlacementEngine
                     │
             ┌───────┼─────────┐
             ▼       ▼         ▼
         Candidate  Constraints Score
                     │
             ┌───────┼─────────────┐
             ▼       ▼       ▼     ▼
          Collision Support Fit Clearance
                     │
                     ▼
              PlacementResult
                     │
                     ▼
                TwinCommand
```

This is now a **real platform-level abstraction**, rather than a warehouse feature.

---

# 5.5A.1.22 What we have achieved

At the end of 5.5A.1, the system can conceptually do:

```text
Any Entity
    │
    ▼
SpatialComponent
    │
    ▼
SpatialWorld
    │
    ▼
PlacementRequest
    │
    ▼
Candidate generation
    │
    ▼
Constraint evaluation
    │
    ├── collision
    ├── clearance
    ├── support
    └── surface fit
    │
    ▼
PlacementResult
```

And importantly, the engine has **zero knowledge of**:

```text
warehouse
restaurant
cargo
chair
table
rack
room
factory
```

Those become data/schema later.

---

# Next: 5.5A.2 — Candidate Sampling & Intelligent Snapping

The next step is where it gets much more interesting.

Right now our candidate generation is basically:

```text
center of shelf
preferred position
small offsets
```

That's too primitive.

We should make the engine capable of:

```text
                 Drop position
                      │
                      ▼
              ┌───────────────┐
              │ surface query │
              └───────┬───────┘
                      ▼
             generate candidates
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       grid       anchors      edges
          │           │           │
          └───────────┼───────────┘
                      ▼
                 constraints
                      │
                      ▼
                  scoring
                      │
                      ▼
             BEST VALID POSITION
```

That is what will make dragging cargo onto shelves, placing chairs around tables, putting products on shelves, etc. feel **game-like and intelligent rather than merely collision-aware**.
