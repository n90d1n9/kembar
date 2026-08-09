Yes. **Step 5.5A.7 is where we turn the spatial engine into an intelligent placement system.**

The goal is to move from:

> “Can these two objects occupy this space?”

to:

> **“Given the object, environment, relationships, constraints, and intent, where should this object naturally be placed?”**

---

# 5.5A.7 — Anchor, Slot & Intelligent Placement

The architecture we have now is:

```text
Object
  │
  ▼
Spatial Index
  │
  ▼
Candidate Objects
  │
  ▼
Geometry / Collision
```

We're going to extend it to:

```text
Placement Request
       │
       ▼
Find Candidates
       │
       ▼
Find Anchors / Slots
       │
       ▼
Generate Placement Candidates
       │
       ▼
Validate
       │
       ├── Collision
       ├── Containment
       ├── Clearance
       ├── Capacity
       ├── Compatibility
       └── Relations
       │
       ▼
Score
       │
       ▼
Best Placement
       │
       ▼
Snap / Commit
```

This is the beginning of your **domain-agnostic spatial reasoning engine**.

---

# 5.5A.7.1 First principle: objects shouldn't only have geometry

Previously we have something like:

```dart
SpatialComponent
```

with:

```text
position
rotation
scale
bounds
```

Now we add a second concept:

```text
Placement affordances
```

An object can say:

> “Here are the places where another object can reasonably connect to me.”

For example:

### Rack

```text
Rack
├── slot-01
├── slot-02
├── slot-03
└── slot-04
```

### Restaurant table

```text
Table
├── seat-01
├── seat-02
├── seat-03
└── seat-04
```

### Truck

```text
Truck
├── cargo-zone-01
├── cargo-zone-02
└── cargo-zone-03
```

### Building

```text
Building
├── entrance
├── room-01
├── room-02
└── parking-zone
```

### Factory machine

```text
Machine
├── power-port
├── input-port
├── output-port
└── maintenance-zone
```

This is much more powerful than hardcoding:

```text
if object.type == "chair"
```

---

# 5.5A.7.2 Create `Anchor`

Create:

```text
lib/domain/spatial/placement/anchor.dart
```

```dart
class SpatialAnchor {
  final String id;

  final String ownerId;

  final Transform localTransform;

  final AnchorType type;

  const SpatialAnchor({
    required this.id,
    required this.ownerId,
    required this.localTransform,
    required this.type,
  });
}
```

And:

```dart
enum AnchorType {
  placement,
  connection,
  support,
  entrance,
  exit,
  seat,
  storage,
  loading,
  docking,
}
```

But remember:

**don't make these domain types mandatory.**

Eventually I recommend:

```dart
typedef AnchorTypeId = String;
```

so domains can define:

```text
warehouse.storage
restaurant.seat
factory.power
hospital.patient-bed
airport.gate
```

without modifying the core engine.

---

# 5.5A.7.3 Anchor versus Slot

This distinction is important.

An **anchor** is a geometric reference point.

A **slot** is an anchor with placement semantics.

For example:

```text
Rack
   │
   ├── Anchor
   │      position = x,y,z
   │
   └── Slot
          capacity = 50kg
          allowed = cargo
          occupied = false
```

So create:

```dart
class PlacementSlot {
  final String id;

  final String ownerId;

  final SpatialAnchor anchor;

  final double capacity;

  final Set<String> acceptedTypes;

  final bool occupied;

  const PlacementSlot({
    required this.id,
    required this.ownerId,
    required this.anchor,
    required this.capacity,
    required this.acceptedTypes,
    required this.occupied,
  });
}
```

---

# 5.5A.7.4 Why not make slots only for warehouses?

Because the same abstraction works everywhere.

### Warehouse

```text
rack
 └── cargo slot
```

### Restaurant

```text
table
 └── seat slot
```

### Hotel

```text
room
 └── bed slot
```

### Parking

```text
parking area
 └── parking slot
```

### Factory

```text
assembly station
 └── machine slot
```

### Game

```text
castle
 └── NPC spawn slot
```

Same engine.

Different domain data.

---

# 5.5A.7.5 Local versus world transform

An anchor should normally be defined in **local coordinates**.

Example:

```text
Table
position = (100, 50, 0)

seat-01
local position = (-1, 0, 0)
```

When the table moves:

```text
Table
   ↓
transform
   ↓
Seat anchor moves automatically
```

So:

```dart
Transform worldTransformOfAnchor(
  SpatialAnchor anchor,
  Transform ownerTransform,
) {
  return ownerTransform *
      anchor.localTransform;
}
```

The exact multiplication depends on your transform implementation, but conceptually:

```text
world anchor =
    owner world transform
    ×
    anchor local transform
```

---

# 5.5A.7.6 Orientation is part of placement

This is a major point.

A placement isn't only:

```text
position
```

It is:

```text
position
+
rotation
+
scale
```

For a chair:

```text
        TABLE
     ┌─────────┐
     │         │
     └─────────┘
        ↑
      chair
```

The chair shouldn't merely be:

```text
position = (x,y,z)
```

It should also face:

```text
toward table
```

So an anchor needs orientation.

---

# 5.5A.7.7 Anchor transform

```dart
class SpatialAnchor {
  final String id;
  final String ownerId;

  final Transform localTransform;

  final AnchorTypeId type;

  final AnchorOrientationPolicy orientationPolicy;

  const SpatialAnchor({
    required this.id,
    required this.ownerId,
    required this.localTransform,
    required this.type,
    required this.orientationPolicy,
  });
}
```

For example:

```dart
enum AnchorOrientationPolicy {
  useAnchorRotation,
  faceOwner,
  faceAwayFromOwner,
  alignForward,
  free,
}
```

Again, this can eventually become extensible configuration rather than a hardcoded enum.

---

# 5.5A.7.8 Add `PlacementCandidate`

The placement engine shouldn't immediately move an object.

It should generate possibilities.

Create:

```text
lib/domain/spatial/placement/placement_candidate.dart
```

```dart
class PlacementCandidate {
  final String targetId;

  final String? slotId;

  final Transform transform;

  final double distance;

  final List<String> reasons;

  double score;

  const PlacementCandidate({
    required this.targetId,
    required this.slotId,
    required this.transform,
    required this.distance,
    required this.reasons,
    required this.score,
  });
}
```

Now the system can say:

```text
Candidate A
score = 0.94

Candidate B
score = 0.72

Candidate C
invalid
```

This is much better than:

```text
first valid location wins
```

---

# 5.5A.7.9 Placement request

Create:

```dart
class PlacementRequest {
  final String objectId;

  final Vector3 desiredPosition;

  final Transform? desiredTransform;

  final String? preferredTargetId;

  final String? preferredSlotType;

  const PlacementRequest({
    required this.objectId,
    required this.desiredPosition,
    this.desiredTransform,
    this.preferredTargetId,
    this.preferredSlotType,
  });
}
```

This allows different interaction modes.

For example:

### User drags cargo

```text
desiredPosition = mouse world position
```

### AI places cargo

```text
desiredPosition = generated target
```

### Simulation moves cargo

```text
desiredPosition = simulation output
```

Same placement engine.

---

# 5.5A.7.10 Placement should be multi-stage

Don't write one giant function like:

```dart
placeObject(...)
```

Instead:

```text
PlacementPipeline
```

with stages:

```text
1. discover
2. generate
3. transform
4. validate
5. score
6. select
7. commit
```

---

# 5.5A.7.11 Stage 1 — discover targets

```dart
List<PlacementTarget> discoverTargets(
  PlacementRequest request,
) {
  // spatial query
  // semantic filtering
  // relationship filtering
}
```

For cargo:

```text
nearby objects
    ↓
containers/racks
    ↓
compatible targets
```

For chair:

```text
nearby objects
    ↓
tables
    ↓
tables with available seat slots
```

---

# 5.5A.7.12 Stage 2 — discover slots

```dart
List<PlacementSlot> discoverSlots(
  PlacementTarget target,
) {
  return target.slots
      .where((slot) => !slot.occupied)
      .toList();
}
```

But don't just check:

```text
occupied == false
```

Eventually we also need:

```text
capacity
compatibility
accessibility
clearance
reservation
state
```

---

# 5.5A.7.13 Stage 3 — generate candidate transforms

For each slot:

```text
slot
 ↓
anchor transform
 ↓
object placement transform
```

Conceptually:

```dart
Transform candidateTransform(
  SpatialAnchor anchor,
  SpatialComponent object,
) {
  return anchorWorldTransform;
}
```

But usually we need an **offset** because the object's origin isn't necessarily its contact point.

---

# 5.5A.7.14 This is where `PlacementProfile` becomes useful

Create:

```dart
class PlacementProfile {
  final Vector3 localAnchorOffset;

  final Vector3 clearance;

  final bool alignRotation;

  const PlacementProfile({
    required this.localAnchorOffset,
    required this.clearance,
    required this.alignRotation,
  });
}
```

Example:

```text
chair origin
      ●
      │
      │ 0.45m
      ▼
contact point
```

Without this concept, objects will often appear visually "almost right" but physically wrong.

---

# 5.5A.7.15 Cargo example

Suppose:

```text
Cargo:
width  = 1.0m
depth  = 1.2m
height = 0.8m
```

Rack slot:

```text
width  = 1.2m
depth  = 1.5m
height = 1.0m
```

The placement system evaluates:

```text
cargo dimensions
        ↓
slot dimensions
        ↓
orientation candidates
        ↓
fit?
```

Try:

```text
rotation 0°
rotation 90°
```

Potentially:

```text
0°  → valid
90° → valid
```

Then score:

```text
0°  → 0.91
90° → 0.83
```

Choose 0°.

---

# 5.5A.7.16 Orientation candidates

Don't assume only one orientation.

Create:

```dart
class OrientationCandidate {
  final Quaternion rotation;

  const OrientationCandidate(
    this.rotation,
  );
}
```

A placement strategy can generate:

```text
identity
90°
180°
270°
```

For 3D domains you may also generate:

```text
yaw
pitch
roll
```

but don't blindly generate every possible angle.

That would explode the search space.

---

# 5.5A.7.17 Use domain-defined orientation constraints

For example:

```text
cargo
  allowed rotations:
    yaw only

chair
  allowed rotations:
    yaw only

drone
  allowed:
    yaw/pitch/roll

building
  allowed:
    yaw = 0,90,180,270
```

So:

```dart
class OrientationConstraint {
  final bool allowYaw;
  final bool allowPitch;
  final bool allowRoll;

  const OrientationConstraint({
    this.allowYaw = true,
    this.allowPitch = false,
    this.allowRoll = false,
  });
}
```

---

# 5.5A.7.18 Stage 4 — validation

Every candidate now goes through the validators we have been building.

```text
Candidate
   │
   ├── Geometry
   ├── Collision
   ├── Containment
   ├── Clearance
   ├── Capacity
   ├── Compatibility
   └── Relationship
```

Create:

```dart
class PlacementValidation {
  final bool valid;

  final List<PlacementViolation>
      violations;

  const PlacementValidation({
    required this.valid,
    required this.violations,
  });
}
```

And:

```dart
class PlacementViolation {
  final String ruleId;

  final String message;

  final double severity;

  const PlacementViolation({
    required this.ruleId,
    required this.message,
    required this.severity,
  });
}
```

---

# 5.5A.7.19 Don't return only `true/false`

This is extremely important for your future AI system.

Instead of:

```dart
false
```

return:

```text
INVALID

violations:
- slot too small
- 15cm clearance violation
- incompatible cargo category
```

Then your UI can show:

```text
❌ Can't place here

Rack slot is too small
Required clearance: 20cm
Available clearance: 12cm
```

And your AI can reason:

```text
Candidate rejected because
clearance < required clearance.
```

---

# 5.5A.7.20 Soft constraints versus hard constraints

This is where intelligent placement becomes much better.

Not every rule should be:

```text
valid / invalid
```

Some rules are preferences.

### Hard

```text
cargo doesn't fit
```

→ reject.

### Soft

```text
rack is 3 meters farther
```

→ penalize.

So:

```text
Hard constraints
    ↓
must pass

Soft constraints
    ↓
affect score
```

---

# 5.5A.7.21 Create constraint result

```dart
enum ConstraintResultType {
  pass,
  fail,
  penalty,
}
```

```dart
class ConstraintResult {
  final ConstraintResultType type;

  final double scoreImpact;

  final String reason;

  const ConstraintResult({
    required this.type,
    required this.scoreImpact,
    required this.reason,
  });
}
```

Now:

```text
distance
→ penalty -0.10

alignment
→ penalty -0.03

capacity
→ pass

collision
→ fail
```

---

# 5.5A.7.22 Placement scoring

A candidate score might be:

```text
score =
    distanceScore
  + alignmentScore
  + capacityScore
  + compatibilityScore
  + preferenceScore
  - clearancePenalty
```

For example:

```dart
double scoreCandidate(
  PlacementCandidate candidate,
) {
  return
      candidate.distanceScore
    + candidate.alignmentScore
    + candidate.compatibilityScore
    + candidate.capacityScore
    - candidate.clearancePenalty;
}
```

Eventually this becomes a generic scoring framework.

---

# 5.5A.7.23 But don't hardcode the formula

This:

```dart
distance * 0.4 +
compatibility * 0.3
```

will eventually become problematic.

Instead:

```dart
abstract interface class PlacementScorer {
  double score(
    PlacementContext context,
    PlacementCandidate candidate,
  );
}
```

Then you can compose scorers:

```text
DistanceScorer
CompatibilityScorer
AlignmentScorer
CapacityScorer
AccessibilityScorer
PreferenceScorer
```

---

# 5.5A.7.24 Composite scorer

```dart
class CompositePlacementScorer
    implements PlacementScorer {

  final List<PlacementScorer>
      scorers;

  const CompositePlacementScorer(
    this.scorers,
  );

  @override
  double score(
    PlacementContext context,
    PlacementCandidate candidate,
  ) {
    return scorers.fold(
      0.0,
      (score, scorer) =>
          score +
          scorer.score(
            context,
            candidate,
          ),
    );
  }
}
```

Now the platform can compose different behaviors.

---

# 5.5A.7.25 Warehouse configuration

```text
WarehousePlacementScorer
├── compatibility
├── capacity
├── distance
├── accessibility
└── weight distribution
```

Restaurant:

```text
RestaurantPlacementScorer
├── table proximity
├── seat accessibility
├── aisle clearance
├── orientation
└── customer flow
```

Factory:

```text
FactoryPlacementScorer
├── machine compatibility
├── utility proximity
├── safety clearance
├── maintenance access
└── production flow
```

Same core.

Different configuration.

---

# 5.5A.7.26 Stage 5 — select

After generating candidates:

```dart
PlacementCandidate? selectBest(
  List<PlacementCandidate> candidates,
) {
  final valid =
      candidates
          .where(
            (candidate) =>
                candidate.validation.valid,
          )
          .toList();

  if (valid.isEmpty) {
    return null;
  }

  valid.sort(
    (a, b) =>
        b.score.compareTo(a.score),
  );

  return valid.first;
}
```

Now:

```text
100 possible positions
        ↓
70 invalid
        ↓
30 valid
        ↓
score
        ↓
best candidate
```

---

# 5.5A.7.27 Stage 6 — preview versus commit

This is very important for the interactive editor.

The placement engine should support:

```text
PREVIEW
```

and:

```text
COMMIT
```

Preview:

```text
mouse moves
    ↓
candidate
    ↓
validate
    ↓
visualize
```

Commit:

```text
user releases
    ↓
selected candidate
    ↓
apply transform
    ↓
update relationships
    ↓
update spatial index
```

Never mutate the world during preview.

---

# 5.5A.7.28 Create `PlacementResult`

```dart
class PlacementResult {
  final bool success;

  final PlacementCandidate? candidate;

  final List<PlacementCandidate>
      alternatives;

  const PlacementResult({
    required this.success,
    required this.candidate,
    required this.alternatives,
  });
}
```

This gives the UI more information.

For example:

```text
✓ Best placement
Rack A / Slot 12

Alternatives:
Rack A / Slot 14
Rack B / Slot 03
Rack C / Slot 07
```

That's excellent for AI-assisted workflows.

---

# 5.5A.7.29 Snap behavior

Now we finally introduce:

```text
SNAP
```

But snapping should not simply mean:

```text
round(x)
```

Instead:

```text
desired transform
       ↓
find compatible anchor
       ↓
find candidate transform
       ↓
if within snap distance
       ↓
snap
```

---

# 5.5A.7.30 Snap distance

```dart
class SnapSettings {
  final double maxDistance;

  final double rotationTolerance;

  const SnapSettings({
    required this.maxDistance,
    required this.rotationTolerance,
  });
}
```

Example:

```text
mouse position
      ●

anchor
      ◎
```

If:

```text
distance <= 0.5m
```

then:

```text
SNAP
```

otherwise:

```text
free placement
```

---

# 5.5A.7.31 Snap should still validate

Never:

```text
near anchor
→ snap blindly
```

Instead:

```text
near anchor
   ↓
generate snapped transform
   ↓
collision check
   ↓
clearance check
   ↓
capacity check
   ↓
if valid → snap
```

Otherwise snapping can create impossible states.

---

# 5.5A.7.32 Example: chair and table

Let's make the whole pipeline concrete.

Scene:

```text
       TABLE
   ┌─────────────┐
   │             │
   └─────────────┘
```

Table exposes:

```text
seat-01
seat-02
seat-03
seat-04
```

User drags chair.

```text
Chair
  ↓
spatial query
  ↓
nearby table
  ↓
find available seats
  ↓
seat anchor
  ↓
generate transform
  ↓
check chair collision
  ↓
check aisle clearance
  ↓
check seat occupancy
  ↓
score
  ↓
snap
```

Result:

```text
Chair
   ↓
seat-02
```

And the relationship graph gets:

```text
chair-17
    │
    └── seated-at ──► table-03/seat-02
```

---

# 5.5A.7.33 Example: cargo and rack

```text
Cargo
  ↓
nearby racks
  ↓
compatible slots
  ↓
orientation candidates
  ↓
fit test
  ↓
capacity
  ↓
weight
  ↓
clearance
  ↓
score
  ↓
best slot
```

Then:

```text
cargo-923
    │
    └── stored-in ──► rack-12/slot-04
```

Now your spatial placement also updates your semantic graph.

That's a major milestone.

---

# 5.5A.7.34 Example: car and parking

Parking lot:

```text
Parking Area
├── slot A1
├── slot A2
├── slot A3
├── slot A4
└── ...
```

Car arrives:

```text
vehicle
 ↓
nearby parking area
 ↓
available slots
 ↓
vehicle dimensions
 ↓
orientation
 ↓
clearance
 ↓
accessibility
 ↓
score
 ↓
parking slot
```

Same API.

---

# 5.5A.7.35 Example: machine placement

Machine:

```text
Machine
├── power connector
├── input
├── output
└── maintenance boundary
```

Floor:

```text
FactoryFloor
├── placement zones
├── restricted zones
└── utility anchors
```

The placement engine can eventually reason:

```text
machine
 ↓
candidate zones
 ↓
floor capacity
 ↓
power proximity
 ↓
input/output alignment
 ↓
maintenance clearance
 ↓
safety zone
 ↓
collision
 ↓
best position
```

This is where your platform starts becoming genuinely interesting.

---

# 5.5A.7.36 Create a generic `PlacementTarget`

We shouldn't make the engine depend directly on:

```text
Rack
Table
ParkingLot
Machine
```

Create:

```dart
abstract interface class PlacementTarget {
  String get id;

  Aabb get bounds;

  List<SpatialAnchor>
      get anchors;

  List<PlacementSlot>
      get slots;
}
```

Then:

```text
Rack implements PlacementTarget
Table implements PlacementTarget
ParkingArea implements PlacementTarget
FactoryZone implements PlacementTarget
```

Or, better, use components so the object itself doesn't have to inherit anything.

---

# 5.5A.7.37 Component-based version

I recommend this longer-term:

```text
Entity
├── TransformComponent
├── GeometryComponent
├── SpatialComponent
├── AnchorComponent
├── SlotComponent
├── CapacityComponent
├── CompatibilityComponent
└── RelationshipComponent
```

Then:

```text
Rack
```

isn't a special engine object.

It's simply an entity with:

```text
AnchorComponent
SlotComponent
CapacityComponent
...
```

Likewise:

```text
Table
```

has:

```text
AnchorComponent
SlotComponent
```

This is much closer to the **agnostic platform** goal.

---

# 5.5A.7.38 This is the architecture I recommend

```text
                   ENTITY
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
    Geometry      Transform     Semantics
        │            │            │
        ▼            ▼            ▼
      Bounds       Position     Properties
        │
        ▼
   Spatial Index
        │
        ▼
  Spatial Query
        │
        ▼
Placement Components
 ┌──────┼───────┐
 ▼      ▼       ▼
Anchor Slot   Constraints
 │      │       │
 └──────┼───────┘
        ▼
 Placement Candidate
        │
        ▼
 Validation
        │
        ▼
   Scoring Engine
        │
        ▼
 Best Placement
```

---

# 5.5A.7.39 The critical new concept: "affordance"

I recommend introducing this term into the platform.

An **affordance** means:

> An object exposes something another object can meaningfully do with it.

Examples:

```text
Rack
  → store cargo

Table
  → seat person
  → support object

Door
  → enter
  → exit

Dock
  → receive vehicle

Machine
  → connect input
  → connect output

Charging station
  → charge vehicle

Building
  → contain room
```

This is far more powerful than simply:

```text
object.type == "rack"
```

---

# 5.5A.7.40 Create `Affordance`

```dart
class SpatialAffordance {
  final String id;

  final String ownerId;

  final String type;

  final String anchorId;

  final Map<String, dynamic> properties;

  const SpatialAffordance({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.anchorId,
    required this.properties,
  });
}
```

Example:

```json
{
  "type": "storage",
  "anchorId": "rack-12-slot-04",
  "properties": {
    "capacity": 50,
    "unit": "kg"
  }
}
```

Now your AI layer can eventually query:

```text
find affordances:
    type = storage
    capacity >= 20kg
    distance < 100m
```

That is a **huge step toward intelligent generation**.

---

# 5.5A.7.41 Don't make AI responsible for geometry

This distinction will matter later.

Bad architecture:

```text
LLM
 ↓
calculate coordinates
 ↓
modify scene
```

Better:

```text
LLM / AI
 ↓
intent
 ↓
"put this cargo into suitable storage"
 ↓
Placement Engine
 ↓
spatial reasoning
 ↓
constraints
 ↓
best placement
```

The AI provides:

```text
intent
preferences
goals
```

The deterministic engine provides:

```text
geometry
physics
constraints
validation
```

This is how you keep the system reliable.

---

# 5.5A.7.42 The first usable API

Eventually I want you to be able to write something conceptually like:

```dart
final result =
    placementEngine.findPlacement(
  PlacementRequest(
    objectId: cargo.id,
    desiredPosition:
        cursor.worldPosition,
  ),
);
```

and get:

```dart
result.success
```

plus:

```dart
result.candidate
```

and:

```dart
result.alternatives
```

Then the UI:

```text
if success:
    show green preview
else:
    show red preview
```

---

# 5.5A.7.43 Preview visualization

This is where your game-style interface starts emerging.

### Valid

```text
        ┌─────────┐
        │  CARGO  │
        └─────────┘
             ↓
        [ SLOT 04 ]
```

Show:

```text
✓ Valid placement
```

### Invalid

```text
        ┌─────────┐
        │  CARGO  │
        └─────────┘
             ↓
        [ SLOT 04 ]

          COLLISION
```

Show:

```text
✕ Collision
```

### Alternative

```text
Slot 04 ✕
Slot 05 ✓
Slot 06 ✓
```

This is much closer to a game-world builder.

---

# 5.5A.7.44 One more important thing: reservations

For simulation/multiplayer/AI, two agents may attempt the same slot.

Example:

```text
Robot A → Rack slot 04
Robot B → Rack slot 04
```

If both check:

```text
occupied == false
```

at the same moment, both may succeed.

So eventually slots need:

```text
available
reserved
occupied
blocked
```

Create:

```dart
enum SlotState {
  available,
  reserved,
  occupied,
  blocked,
}
```

For now, you can simply implement:

```text
available
occupied
```

and add reservations in the next iteration.

---

# 5.5A.7.45 What Step 5.5A.7 gives us

After this step, your system can conceptually support:

```text
                ANY ENTITY
                     │
                     ▼
              Spatial Query
                     │
                     ▼
              Find Targets
                     │
                     ▼
             Find Affordances
                     │
                     ▼
                Find Slots
                     │
                     ▼
          Generate Transforms
                     │
                     ▼
                Validate
                     │
                     ▼
                 Score
                     │
                     ▼
              Best Candidate
                     │
                     ▼
              Snap / Commit
```

That is the correct direction for your **agnostic digital-twin platform**.

---

# 5.5A.7.46 Implementation order

Don't implement all of this at once.

Do it in this exact order:

### 1

```text
SpatialAnchor
```

### 2

```text
PlacementSlot
```

### 3

```text
PlacementProfile
```

### 4

```text
PlacementRequest
```

### 5

```text
PlacementCandidate
```

### 6

```text
PlacementValidation
```

### 7

```text
PlacementScorer
```

### 8

```text
PlacementEngine
```

### 9

```text
SnapSettings
```

### 10

```text
SpatialAffordance
```

### 11

Connect it to:

```text
SpatialIndex
```

### 12

Connect it to:

```text
RelationshipGraph
```

---

# 5.5A.7.47 Final architecture after this step

```text
                    DIGITAL TWIN ENGINE
                           │
      ┌────────────────────┼─────────────────────┐
      │                    │                     │
      ▼                    ▼                     ▼
   ENTITY              RELATIONSHIP          SPATIAL
   SYSTEM                 GRAPH              SYSTEM
      │                    │                     │
      │                    │              ┌──────┴──────┐
      │                    │              │             │
      │                    │             INDEX       GEOMETRY
      │                    │              │             │
      │                    │              └──────┬──────┘
      │                    │                     │
      └────────────────────┼─────────────────────┤
                           ▼
                  PLACEMENT ENGINE
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
          Anchors        Slots      Affordances
              │            │            │
              └────────────┼────────────┘
                           ▼
                      Candidates
                           │
                           ▼
                       Validation
                           │
                           ▼
                         Scoring
                           │
                           ▼
                     Best Placement
                           │
                    ┌──────┴──────┐
                    ▼             ▼
                  Snap          Commit
                    │             │
                    └──────┬──────┘
                           ▼
                    Updated World
```

### The important conceptual shift

We're no longer building a:

> **3D viewer with collision detection.**

We're building a:

> **general-purpose spatial reasoning and simulation kernel where domains are expressed as data, components, relationships, constraints, affordances, and behaviors.**

That distinction is what will let the same platform eventually handle **warehouses, restaurants, factories, cities, hospitals, campuses, logistics, games, robotics, buildings, or completely new domains** without rewriting the underlying engine.

**Next step: 5.5A.8 — Constraint & Rule Engine.** That's where we make rules such as *"cargo cannot exceed rack capacity"*, *"chair must maintain aisle clearance"*, *"machine needs maintenance access"*, and *"vehicle cannot enter this zone"* declarative and domain-configurable rather than hardcoded into the placement engine.
