Absolutely. **Step 5.5A.6 = Spatial Indexing & Incremental Spatial Queries.**

This is the performance layer underneath everything we built in 5.5A.1–5.5A.5.

The key change is:

> **Never let placement/collision logic scan the entire world when it only needs nearby or potentially intersecting objects.**

---

# 5.5A.6 — Spatial Indexing

Our current conceptual pipeline is:

```text
Placement Request
       │
       ▼
Generate candidates
       │
       ▼
Check geometry
       │
       ▼
Check collision
       │
       ▼
Check containment
       │
       ▼
Check capacity
       │
       ▼
Check compatibility
```

The problem appears when the world contains:

```text
10 objects       → trivial
1,000 objects    → okay
100,000 objects  → expensive
1,000,000 objects → unacceptable
```

A collision query such as:

```text
"Does this chair collide with anything?"
```

should **not** mean:

```dart
for (final object in world.objects) {
  checkCollision(chair, object);
}
```

Instead:

```text
Chair
 │
 ▼
Spatial Index
 │
 ▼
Nearby / potentially intersecting objects
 │
 ▼
Exact collision test
```

---

# 5.5A.6.1 The most important architectural distinction

We need two layers:

```text
Broad Phase
```

and:

```text
Narrow Phase
```

### Broad phase

Fast, approximate:

```text
"Which objects COULD possibly collide?"
```

### Narrow phase

Accurate:

```text
"Do these two objects ACTUALLY collide?"
```

So:

```text
                Collision Query
                      │
                      ▼
                Broad Phase
                      │
             possible objects
                      │
                      ▼
                Narrow Phase
                      │
                 exact test
                      │
                      ▼
                 collision?
```

This distinction should become fundamental to your engine.

---

# 5.5A.6.2 Create a generic `SpatialIndex`

Create:

```text
lib/domain/spatial/index/spatial_index.dart
```

```dart
abstract interface class SpatialIndex {
  void insert(
    String entityId,
    Aabb bounds,
  );

  void update(
    String entityId,
    Aabb bounds,
  );

  void remove(
    String entityId,
  );

  List<String> queryAabb(
    Aabb bounds,
  );

  List<String> queryRadius(
    Vector3 center,
    double radius,
  );

  void clear();
}
```

This is intentionally an interface.

The rest of your engine should **not care** whether the implementation is:

```text
Grid
R-tree
BVH
Octree
Quadtree
```

That is extremely important for keeping the platform agnostic.

---

# 5.5A.6.3 Define `Aabb`

Create:

```text
lib/domain/spatial/geometry/aabb.dart
```

```dart
class Aabb {
  final Vector3 min;

  final Vector3 max;

  const Aabb({
    required this.min,
    required this.max,
  });

  Vector3 get center =>
      (min + max) * 0.5;

  Vector3 get size =>
      max - min;

  bool intersects(Aabb other) {
    return
        min.x <= other.max.x &&
        max.x >= other.min.x &&
        min.y <= other.max.y &&
        max.y >= other.min.y &&
        min.z <= other.max.z &&
        max.z >= other.min.z;
  }

  bool contains(Aabb other) {
    return
        min.x <= other.min.x &&
        max.x >= other.max.x &&
        min.y <= other.min.y &&
        max.y >= other.max.y &&
        min.z <= other.min.z &&
        max.z >= other.max.z;
  }
}
```

You may already have a bounds abstraction in your project.

If so, **don't duplicate it**.

Instead, adapt the existing `Bounds` type to provide the same functionality.

---

# 5.5A.6.4 Why AABB?

AABB means:

> Axis-Aligned Bounding Box.

For an object:

```text
        ┌─────────────┐
        │             │
        │   OBJECT    │
        │             │
        └─────────────┘
```

we store:

```text
min = (x1, y1, z1)
max = (x2, y2, z2)
```

It is extremely cheap to test.

But it is only a **broad-phase approximation**.

For example:

```text
AABB
┌──────────────┐
│      ╲       │
│       ╲      │
│        ╲     │
└──────────────┘
```

The actual mesh may not fill the box.

That's okay.

The AABB tells us:

```text
"These two objects are worth checking."
```

not:

```text
"These two objects definitely collide."
```

---

# 5.5A.6.5 Start with a simple grid

For your first implementation, I recommend a **uniform spatial grid**.

Don't start with an octree or BVH.

Why?

Because the grid is:

* simple
* predictable
* easy to debug
* easy to visualize
* fast for dynamic objects
* good for game-style interaction

Architecture:

```text
World
┌───┬───┬───┬───┐
│   │ A │   │   │
├───┼───┼───┼───┤
│ B │   │ C │   │
├───┼───┼───┼───┤
│   │ D │   │ E │
├───┼───┼───┼───┤
└───┴───┴───┴───┘
```

Each object is registered in the cells it overlaps.

---

# 5.5A.6.6 Create `GridSpatialIndex`

```text
lib/infrastructure/spatial/grid_spatial_index.dart
```

```dart
class GridSpatialIndex
    implements SpatialIndex {

  final double cellSize;

  final Map<GridKey, Set<String>>
      cells = {};

  final Map<String, Set<GridKey>>
      entityCells = {};

  GridSpatialIndex({
    required this.cellSize,
  });

  @override
  void insert(
    String entityId,
    Aabb bounds,
  ) {
    final keys =
        _cellsFor(bounds);

    entityCells[entityId] =
        keys;

    for (final key in keys) {
      cells
          .putIfAbsent(
            key,
            () => <String>{},
          )
          .add(entityId);
    }
  }
}
```

---

# 5.5A.6.7 Grid coordinates

Create:

```dart
class GridKey {
  final int x;
  final int y;
  final int z;

  const GridKey(
    this.x,
    this.y,
    this.z,
  );

  @override
  bool operator ==(
    Object other,
  ) {
    return other is GridKey &&
        other.x == x &&
        other.y == y &&
        other.z == z;
  }

  @override
  int get hashCode =>
      Object.hash(x, y, z);
}
```

Convert world position:

```dart
GridKey _keyFor(
  Vector3 position,
) {
  return GridKey(
    (position.x / cellSize).floor(),
    (position.y / cellSize).floor(),
    (position.z / cellSize).floor(),
  );
}
```

---

# 5.5A.6.8 Objects can occupy multiple cells

This is important.

Suppose:

```text
cell size = 1m
```

and object:

```text
3m × 2m × 1m
```

It may cover:

```text
┌───┬───┬───┐
│ X │ X │ X │
├───┼───┼───┤
│ X │ X │ X │
└───┴───┴───┘
```

Therefore `_cellsFor()` should calculate all cells covered by the AABB.

```dart
Set<GridKey> _cellsFor(
  Aabb bounds,
) {
  final minKey =
      _keyFor(bounds.min);

  final maxKey =
      _keyFor(bounds.max);

  final result =
      <GridKey>{};

  for (
    var x = minKey.x;
    x <= maxKey.x;
    x++
  ) {
    for (
      var y = minKey.y;
      y <= maxKey.y;
      y++
    ) {
      for (
        var z = minKey.z;
        z <= maxKey.z;
        z++
      ) {
        result.add(
          GridKey(x, y, z),
        );
      }
    }
  }

  return result;
}
```

---

# 5.5A.6.9 Implement `update`

This is critical for interactive digital twins.

Objects move.

For example:

```text
drag chair
    ↓
position changes
    ↓
bounds changes
    ↓
index must update
```

Implement:

```dart
@override
void update(
  String entityId,
  Aabb bounds,
) {
  remove(entityId);
  insert(entityId, bounds);
}
```

That's the simple implementation.

Later we can optimize it so that we only modify changed cells.

---

# 5.5A.6.10 Implement `remove`

```dart
@override
void remove(
  String entityId,
) {
  final keys =
      entityCells.remove(
        entityId,
      );

  if (keys == null) {
    return;
  }

  for (final key in keys) {
    final bucket =
        cells[key];

    bucket?.remove(
      entityId,
    );

    if (bucket != null &&
        bucket.isEmpty) {
      cells.remove(key);
    }
  }
}
```

Now the index remains consistent.

---

# 5.5A.6.11 Implement AABB query

```dart
@override
List<String> queryAabb(
  Aabb bounds,
) {
  final keys =
      _cellsFor(bounds);

  final result =
      <String>{};

  for (final key in keys) {
    final bucket =
        cells[key];

    if (bucket == null) {
      continue;
    }

    result.addAll(bucket);
  }

  return result.toList();
}
```

Notice something important.

This query returns **potential candidates**, not confirmed intersections.

The next layer must do the exact test.

---

# 5.5A.6.12 The collision engine changes

Previously you may have:

```dart
for (final entity in world.entities) {
  if (collision(entity, candidate)) {
    return true;
  }
}
```

Change it to:

```dart
final candidates =
    spatialIndex.queryAabb(
  candidate.bounds,
);

for (final entityId in candidates) {
  final entity =
      world.component(entityId);

  if (entity == null) {
    continue;
  }

  if (exactCollision(
    candidate,
    entity,
  )) {
    return true;
  }
}
```

Now:

```text
1,000,000 objects
```

doesn't automatically mean:

```text
1,000,000 collision tests
```

---

# 5.5A.6.13 Exclude the subject itself

When an object moves, it will obviously exist in the index.

So:

```dart
if (entityId ==
    request.subjectId) {
  continue;
}
```

Otherwise:

```text
chair
    collides with
chair
```

would always be true.

---

# 5.5A.6.14 Add query filters

We'll soon need:

```text
"find objects near me"
```

but also:

```text
"find only obstacles"
"find only containers"
"find only seats"
"find only vehicles"
```

So don't make the index responsible for semantics.

Instead:

```dart
List<String> queryAabb(
  Aabb bounds, {
  SpatialQueryFilter? filter,
});
```

Create:

```dart
abstract interface class SpatialQueryFilter {
  bool matches(
    String entityId,
  );
}
```

However, I would **not** put domain category logic directly into the grid.

The grid should only know spatial data.

Semantic filtering belongs above it.

---

# 5.5A.6.15 Better architecture

Use:

```text
SpatialIndex
      │
      ▼
candidate IDs
      │
      ▼
SpatialQueryService
      │
      ├── semantic filter
      ├── relation filter
      └── capability filter
```

For example:

```text
query:
    objects within 5m
    that can support cargo
```

becomes:

```text
SpatialIndex
      ↓
nearby objects
      ↓
CapabilityFilter
      ↓
support-capable objects
```

This preserves separation of concerns.

---

# 5.5A.6.16 Create `SpatialQueryService`

```text
lib/application/spatial/spatial_query_service.dart
```

```dart
class SpatialQueryService {
  final SpatialIndex index;

  final SpatialWorld world;

  const SpatialQueryService({
    required this.index,
    required this.world,
  });

  List<SpatialComponent>
      nearby(
    Vector3 center,
    double radius,
  ) {
    final ids =
        index.queryRadius(
      center,
      radius,
    );

    return ids
        .map(world.component)
        .whereType<SpatialComponent>()
        .toList();
  }
}
```

This becomes the public API used by:

* placement
* collision
* selection
* snapping
* AI
* simulation
* interaction
* UI

---

# 5.5A.6.17 Implement radius query

We can first approximate radius with an AABB.

```dart
@override
List<String> queryRadius(
  Vector3 center,
  double radius,
) {
  final bounds = Aabb(
    min: center -
        Vector3.all(radius),
    max: center +
        Vector3.all(radius),
  );

  final candidates =
      queryAabb(bounds);

  return candidates;
}
```

Again:

> This is broad phase.

If exact distance matters:

```dart
distance(entity.center, center)
```

must be checked afterward.

---

# 5.5A.6.18 This distinction will become very important

For:

```text
"nearest restaurant table"
```

the grid can give:

```text
possible nearby tables
```

Then exact distance sorting gives:

```text
1. Table A = 2.1m
2. Table B = 3.4m
3. Table C = 4.0m
```

For:

```text
"nearest suitable rack"
```

we do:

```text
SpatialIndex
     ↓
nearby candidates
     ↓
capacity filter
     ↓
compatibility filter
     ↓
distance score
```

That's already becoming a generalized **spatial reasoning system**.

---

# 5.5A.6.19 Add nearest-neighbor query

We'll eventually need:

```dart
List<String> nearest(
  Vector3 point, {
  int limit = 10,
});
```

Don't initially implement this by scanning the whole world.

Use expanding grid cells:

```text
        ┌───┬───┬───┐
        │   │   │   │
        ├───┼───┼───┤
        │   │ P │   │
        ├───┼───┼───┤
        │   │   │   │
        └───┴───┴───┘
```

Start around the point.

Expand:

```text
radius 1 cell
    ↓
radius 2 cells
    ↓
radius 3 cells
    ↓
...
```

until enough candidates exist.

Then exact distance sorts them.

---

# 5.5A.6.20 But don't build that yet

For this step, the important thing is to establish:

```text
SpatialIndex
```

as an abstraction.

Later, we can replace:

```text
GridSpatialIndex
```

with:

```text
RTreeSpatialIndex
BVHSpatialIndex
OctreeSpatialIndex
GPUSpatialIndex
```

without changing:

```text
PlacementEngine
CollisionEngine
QueryService
```

---

# 5.5A.6.21 Connect the index to `SpatialWorld`

The world should own the spatial index or a spatial subsystem.

I'd recommend:

```dart
class SpatialWorld {
  final Map<String, SpatialComponent>
      entities;

  final RelationshipGraph relationships;

  final SpatialIndex spatialIndex;

  SpatialWorld({
    required this.spatialIndex,
  });
}
```

When adding an object:

```dart
void add(
  SpatialComponent entity,
) {
  entities[entity.id] =
      entity;

  spatialIndex.insert(
    entity.id,
    entity.worldBounds,
  );
}
```

When moving:

```dart
void updateTransform(
  String entityId,
  Transform transform,
) {
  final entity =
      entities[entityId];

  if (entity == null) {
    return;
  }

  entity.transform =
      transform;

  spatialIndex.update(
    entityId,
    entity.worldBounds,
  );
}
```

---

# 5.5A.6.22 This is especially important for dragging

Imagine the user drags a chair:

```text
mouse
 ↓
new position
 ↓
transform update
 ↓
bounds update
 ↓
spatial index update
 ↓
collision query
 ↓
validity
 ↓
visual feedback
```

So every frame:

```text
drag
  ↓
candidate
  ↓
broad phase
  ↓
narrow phase
  ↓
rules
  ↓
green/red preview
```

This is the foundation for the **game-like editor** you wanted.

---

# 5.5A.6.23 Don't update the index unnecessarily

One optimization:

If the object moves but remains in exactly the same grid cells:

```text
old cells == new cells
```

we don't need to rebuild its index entry.

Instead:

```dart
void update(
  String entityId,
  Aabb bounds,
) {
  final newCells =
      _cellsFor(bounds);

  final oldCells =
      entityCells[entityId];

  if (_sameCells(
    oldCells,
    newCells,
  )) {
    return;
  }

  remove(entityId);
  insert(entityId, bounds);
}
```

This becomes valuable for high-frequency simulation.

---

# 5.5A.6.24 Separate static and dynamic objects

This is another major optimization.

Most digital twins contain:

```text
STATIC
building
wall
rack
table
road
machine foundation
```

and:

```text
DYNAMIC
person
vehicle
robot
cargo
chair being dragged
machine state
```

Don't treat them identically.

Architecture:

```text
SpatialWorld
     │
     ├── StaticIndex
     │
     └── DynamicIndex
```

Then collision:

```text
dynamic object
      │
      ├──────────► static index
      │
      └──────────► dynamic index
```

This can greatly reduce update cost.

---

# 5.5A.6.25 Create two index instances

```dart
final staticIndex =
    GridSpatialIndex(
  cellSize: 5,
);

final dynamicIndex =
    GridSpatialIndex(
  cellSize: 2,
);
```

Why different sizes?

Static objects may be large:

```text
building
warehouse
road
```

Dynamic objects may be small:

```text
person
robot
box
```

The ideal cell size depends on object scale.

We will eventually make this configurable per world/layer.

---

# 5.5A.6.26 Don't over-generalize the cell size yet

For the first implementation:

```text
one grid
one cellSize
```

is enough.

After profiling, we can introduce:

```text
static grid
dynamic grid
```

or:

```text
hierarchical spatial index
```

The important thing is not to prematurely build a huge spatial data structure.

---

# 5.5A.6.27 Add a `SpatialLayer`

Eventually your digital twin may have:

```text
terrain
buildings
furniture
people
vehicles
equipment
particles
temporary objects
```

So:

```dart
enum SpatialLayer {
  staticGeometry,
  structures,
  furniture,
  equipment,
  agents,
  vehicles,
  temporary,
}
```

But **don't hardcode those into the core platform**.

Better:

```dart
typedef SpatialLayerId = String;
```

Then:

```text
"static"
"structure"
"furniture"
"vehicle"
```

can be domain-defined.

---

# 5.5A.6.28 Index entry

A more scalable structure is:

```dart
class SpatialIndexEntry {
  final String entityId;

  final Aabb bounds;

  final String layer;

  const SpatialIndexEntry({
    required this.entityId,
    required this.bounds,
    required this.layer,
  });
}
```

Then the index can eventually support:

```text
query AABB
query layer
query nearest
query visibility
query obstacle
```

without mixing semantic definitions into the geometry engine.

---

# 5.5A.6.29 Add spatial queries as first-class concepts

Create:

```dart
sealed class SpatialQuery {
  const SpatialQuery();
}

class AabbQuery extends SpatialQuery {
  final Aabb bounds;

  const AabbQuery(
    this.bounds,
  );
}

class RadiusQuery extends SpatialQuery {
  final Vector3 center;

  final double radius;

  const RadiusQuery({
    required this.center,
    required this.radius,
  });
}
```

Then:

```dart
abstract interface class SpatialIndex {
  List<String> query(
    SpatialQuery query,
  );

  void insert(...);

  void update(...);

  void remove(...);
}
```

This gives you an extensible query system.

Later:

```text
RayQuery
FrustumQuery
NearestQuery
RegionQuery
ContainmentQuery
```

can be added without changing the overall architecture.

---

# 5.5A.6.30 Why this matters for your AI layer later

Suppose an AI agent asks:

> "Find a suitable place for this cargo."

The AI should not need to inspect every object.

Instead:

```text
AI Intent
   │
   ▼
Placement Query
   │
   ▼
Spatial Index
   │
   ▼
Nearby containers
   │
   ▼
Capacity
   │
   ▼
Compatibility
   │
   ▼
Geometry
   │
   ▼
Scoring
   │
   ▼
Recommendation
```

So the spatial index becomes part of your eventual:

```text
reasoning engine
```

not merely a rendering optimization.

---

# 5.5A.6.31 Example: warehouse

Imagine:

```text
100,000 cargo items
5,000 racks
```

User drags:

```text
Cargo #48321
```

Naive approach:

```text
100,000 collision checks
5,000 rack checks
```

Spatial approach:

```text
Cargo
 ↓
AABB query
 ↓
37 nearby objects
 ↓
8 racks
 ↓
3 compatible racks
 ↓
2 capacity-valid racks
 ↓
best placement
```

That's the architecture we want.

---

# 5.5A.6.32 Example: restaurant

Scene:

```text
restaurant
├── 30 tables
├── 120 chairs
├── 15 staff
├── 80 customers
└── thousands of decorative objects
```

User drags:

```text
chair
```

The system doesn't care about the thousands of decorative objects.

Spatial query:

```text
chair bounds
     ↓
nearby entities
     ↓
tables/chairs
     ↓
collision
     ↓
support/adjacency rules
     ↓
placement
```

Again, same engine.

---

# 5.5A.6.33 Example: city

At city scale:

```text
roads
buildings
vehicles
pedestrians
traffic signals
street furniture
```

A vehicle query:

```text
"what is around me?"
```

can become:

```text
RadiusQuery(
    center = vehicle.position,
    radius = 50m
)
```

Then:

```text
SpatialIndex
   ↓
potential entities
   ↓
semantic filtering
   ↓
traffic simulation
```

The same query API works.

---

# 5.5A.6.34 Important: index is not truth

This principle should be explicit in your architecture:

> **The spatial index is a cache/acceleration structure, not the source of truth.**

The source of truth is:

```text
SpatialWorld
```

The index is derived:

```text
SpatialWorld
      │
      └──► SpatialIndex
```

If the index becomes corrupted:

```text
rebuild index
```

should restore it.

This makes your system much safer.

---

# 5.5A.6.35 Add rebuild support

```dart
void rebuild() {
  clear();

  for (final entity
      in world.entities.values) {
    insert(
      entity.id,
      entity.worldBounds,
    );
  }
}
```

You should expose this for:

* loading a scene
* importing a model
* debugging
* recovering from synchronization issues
* tests

---

# 5.5A.6.36 Add validation

A very useful debugging method:

```dart
bool validate() {
  for (final entry
      in world.entities.entries) {

    final indexed =
        index.contains(
      entry.key,
    );

    if (!indexed) {
      return false;
    }
  }

  return true;
}
```

Later you can verify:

```text
world entity
    ↔
index entry
    ↔
correct cells
    ↔
correct bounds
```

This will save you a lot of debugging time.

---

# 5.5A.6.37 Testing strategy

Before continuing, write tests for:

### Insert

```text
object → correct cells
```

### Remove

```text
object removed → no cells contain it
```

### Update

```text
object moved → old cells cleared
```

### AABB query

```text
query region → expected candidates
```

### Large object

```text
object crossing cells → all cells registered
```

### Boundary

```text
object exactly on cell boundary
```

### Self-query

```text
object should be able to find itself
```

Then the collision layer excludes itself.

---

# 5.5A.6.38 One important boundary decision

You need to decide whether touching counts as intersection.

Currently:

```dart
min.x <= other.max.x
```

means touching counts.

So:

```text
┌─────┐┌─────┐
│  A  ││  B  │
└─────┘└─────┘
```

is considered intersecting.

But for placement, you may want:

```text
touching = allowed
overlap = forbidden
```

This distinction should eventually be represented explicitly:

```dart
enum ContactPolicy {
  touchingAllowed,
  touchingForbidden,
}
```

Don't bury this inside the AABB class.

---

# 5.5A.6.39 The architecture now becomes

```text
                       SPATIAL WORLD
                            │
             ┌──────────────┴──────────────┐
             │                             │
             ▼                             ▼
       SOURCE OF TRUTH                SPATIAL INDEX
             │                             │
        entities                    ┌──────┴──────┐
        transforms                  │             │
        relationships             static       dynamic
        properties                  │             │
        rules                       └──────┬──────┘
                                           │
                                           ▼
                                  Spatial Query
                                           │
                                  candidate IDs
                                           │
                                           ▼
                                   Exact Geometry
                                           │
                                           ▼
                                    Rule Pipeline
                                           │
                   ┌───────────────────────┼─────────────────────┐
                   ▼                       ▼                     ▼
               Capacity              Compatibility          Collision
                   │                       │                     │
                   └───────────────────────┼─────────────────────┘
                                           ▼
                                         Score
                                           │
                                           ▼
                                      Decision
```

This is a very strong foundation.

---

# 5.5A.6.40 One architectural correction I'd make now

At this stage, **don't let `PlacementEngine` directly depend on `GridSpatialIndex`.**

Bad:

```dart
class PlacementEngine {
  final GridSpatialIndex index;
}
```

Good:

```dart
class PlacementEngine {
  final SpatialIndex index;
}
```

Then:

```text
PlacementEngine
       │
       ▼
  SpatialIndex
       ▲
       │
 ┌─────┴─────┐
 │           │
Grid        BVH
```

That single interface is what keeps the platform extensible.

---

# 5.5A.6.41 Recommended folder structure

At the end of this step:

```text
lib/
├── domain/
│   ├── spatial/
│   │   ├── geometry/
│   │   │   ├── aabb.dart
│   │   │   ├── bounds.dart
│   │   │   └── ...
│   │   │
│   │   ├── index/
│   │   │   ├── spatial_index.dart
│   │   │   ├── spatial_query.dart
│   │   │   └── spatial_index_entry.dart
│   │   │
│   │   ├── placement/
│   │   ├── relation/
│   │   └── component/
│   │
│   └── rules/
│
├── application/
│   └── spatial/
│       ├── spatial_query_service.dart
│       ├── placement_engine.dart
│       └── collision_service.dart
│
└── infrastructure/
    └── spatial/
        └── grid_spatial_index.dart
```

This separation is intentional:

```text
domain
    what the concepts mean

application
    how the system uses them

infrastructure
    how they're implemented efficiently
```

---

# 5.5A.6.42 What we have accomplished

Your platform now has the beginnings of a proper **spatial computation kernel**:

```text
                    SPATIAL KERNEL
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
   Geometry          Relationships      Indexing
       │                 │                 │
       ▼                 ▼                 ▼
    Bounds          Semantics          Queries
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
                  Placement Engine
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
    Collision        Capacity       Compatibility
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                     Decision
```

And importantly, it remains **domain-neutral**.

---

# Next: 5.5A.7 — Snap, Anchor & Intelligent Placement

Now that queries are fast, the next piece should be the **actual placement intelligence**.

This is where we move from:

> "I can detect whether two things collide."

to:

> **"I know where this object should naturally go."**

For example:

```text
Cargo → Rack
        ↓
find compatible rack
        ↓
find available slot
        ↓
find valid orientation
        ↓
find nearest free position
        ↓
respect clearance
        ↓
avoid collisions
        ↓
respect weight/capacity
        ↓
snap into place
```

And restaurant:

```text
Chair → Table
        ↓
find table anchors
        ↓
find free seat
        ↓
orient chair toward table
        ↓
maintain clearance
        ↓
avoid other chairs
        ↓
snap
```

And factory:

```text
Machine → Floor
          ↓
find valid foundation zone
          ↓
align connection points
          ↓
respect clearance
          ↓
avoid restricted zones
          ↓
check utilities
          ↓
snap
```

**5.5A.7 will therefore introduce the `Anchor + Slot + Snap` system**, which is the piece that will make your editor feel much more like a game/world-building system rather than a conventional CAD viewer.
