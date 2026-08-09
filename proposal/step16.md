# Step 5.5A.8 — Constraint & Rule Engine

Now we make the placement system **domain-agnostic at the rule level**.

The key change is:

> **The engine should not know what a “rack”, “chair”, “cargo”, “machine”, or “parking space” is. It should know how to evaluate constraints.**

So instead of this:

```dart
if (object.type == 'cargo' &&
    target.type == 'rack') {
  ...
}
```

we want:

```text
Placement
   ↓
Rules
   ↓
Evaluate
   ↓
Pass / Fail / Penalty
```

The domain supplies the rules as data/configuration.

---

## 5.5A.8.1 The problem we're solving

Imagine these requirements:

### Warehouse

```text
Cargo must:
- fit inside slot
- not exceed weight capacity
- maintain clearance
- be compatible with rack
```

### Restaurant

```text
Chair must:
- fit around table
- maintain aisle clearance
- not overlap another chair
- remain accessible
```

### Factory

```text
Machine must:
- fit in zone
- have maintenance clearance
- be near required utilities
- not overlap safety zones
```

### Hospital

```text
Bed must:
- fit in room
- maintain access around bed
- be reachable from required corridor
- satisfy equipment clearance
```

These are very different domains.

But structurally they are all:

```text
subject
   ↓
candidate placement
   ↓
constraints
   ↓
evaluation
```

That's what we abstract.

---

# 5.5A.8.2 Introduce `Constraint`

Create:

```text
lib/domain/spatial/rules/constraint.dart
```

```dart
abstract interface class PlacementConstraint {
  String get id;

  ConstraintEvaluation evaluate(
    PlacementContext context,
  );
}
```

Then:

```dart
class ConstraintEvaluation {
  final ConstraintResultType result;

  final double scoreImpact;

  final String message;

  const ConstraintEvaluation({
    required this.result,
    required this.scoreImpact,
    required this.message,
  });
}
```

So every rule has the same interface.

---

# 5.5A.8.3 The rule does not modify the world

This is critical.

A constraint should be:

```text
READ
 ↓
EVALUATE
 ↓
RETURN RESULT
```

not:

```text
READ
 ↓
CHANGE OBJECT
 ↓
MOVE OBJECT
```

For example:

```dart
class CapacityConstraint
    implements PlacementConstraint {

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    // read capacity
    // compare with object requirement
    // return result
  }
}
```

No mutation.

This makes the engine:

* deterministic
* testable
* previewable
* AI-friendly
* simulation-friendly

---

# 5.5A.8.4 `PlacementContext`

The rule needs information about the world.

Create:

```dart
class PlacementContext {
  final Entity subject;

  final PlacementCandidate candidate;

  final SpatialWorld world;

  final Map<String, dynamic> parameters;

  const PlacementContext({
    required this.subject,
    required this.candidate,
    required this.world,
    this.parameters = const {},
  });
}
```

This is essentially the **read-only context** given to every rule.

---

# 5.5A.8.5 Why `parameters` matters

Suppose we have a generic clearance rule.

You shouldn't create:

```text
WarehouseClearanceConstraint
RestaurantClearanceConstraint
FactoryClearanceConstraint
HospitalClearanceConstraint
```

Instead:

```text
ClearanceConstraint
```

with:

```json
{
  "minimum": 0.8
}
```

or:

```json
{
  "minimum": 1.2
}
```

depending on the environment.

Same rule.

Different configuration.

---

# 5.5A.8.6 Hard and soft constraints

We introduced this concept in the previous step.

Let's make it explicit.

```dart
enum ConstraintMode {
  hard,
  soft,
}
```

Then:

```dart
abstract interface class PlacementConstraint {
  String get id;

  ConstraintMode get mode;

  ConstraintEvaluation evaluate(
    PlacementContext context,
  );
}
```

### Hard

Failure means:

```text
INVALID
```

### Soft

Failure means:

```text
VALID BUT LESS DESIRABLE
```

---

# 5.5A.8.7 Example: collision

Collision should normally be hard.

```dart
class CollisionConstraint
    implements PlacementConstraint {

  @override
  String get id => 'collision';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    final collision =
        context.world.collisionEngine
            .hasCollision(
              context.subject,
              context.candidate.transform,
            );

    if (collision) {
      return ConstraintEvaluation(
        result: ConstraintResultType.fail,
        scoreImpact: 0,
        message: 'Placement causes collision.',
      );
    }

    return ConstraintEvaluation(
      result: ConstraintResultType.pass,
      scoreImpact: 0,
      message: 'No collision.',
    );
  }
}
```

---

# 5.5A.8.8 Example: clearance

```dart
class ClearanceConstraint
    implements PlacementConstraint {

  final double minimumDistance;

  const ClearanceConstraint({
    required this.minimumDistance,
  });

  @override
  String get id => 'clearance';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    final distance =
        context.world.spatialEngine
            .minimumClearance(
              context.subject,
              context.candidate.transform,
            );

    if (distance < minimumDistance) {
      return ConstraintEvaluation(
        result: ConstraintResultType.fail,
        scoreImpact: 0,
        message:
            'Required clearance is '
            '$minimumDistance but only '
            '$distance is available.',
      );
    }

    return ConstraintEvaluation(
      result: ConstraintResultType.pass,
      scoreImpact: 0,
      message: 'Clearance requirement satisfied.',
    );
  }
}
```

Now this rule works for:

```text
chair
machine
bed
cargo
vehicle
robot
building
```

without knowing what any of them are.

---

# 5.5A.8.9 Example: capacity

```dart
class CapacityConstraint
    implements PlacementConstraint {

  final double requiredCapacity;

  const CapacityConstraint({
    required this.requiredCapacity,
  });

  @override
  String get id => 'capacity';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    final available =
        context.candidate.availableCapacity;

    if (available < requiredCapacity) {
      return ConstraintEvaluation(
        result: ConstraintResultType.fail,
        scoreImpact: 0,
        message:
            'Insufficient capacity.',
      );
    }

    return ConstraintEvaluation(
      result: ConstraintResultType.pass,
      scoreImpact: 0,
      message:
          'Capacity requirement satisfied.',
    );
  }
}
```

---

# 5.5A.8.10 But capacity isn't always weight

This is where we need to make the architecture more general.

Capacity might mean:

```text
50 kg
```

but also:

```text
10 people
```

or:

```text
4 pallets
```

or:

```text
2 vehicles
```

or:

```text
100 m³
```

or:

```text
20 seats
```

So don't hardcode:

```dart
double kilograms
```

Instead define:

```dart
class Quantity {
  final double value;

  final String unit;

  const Quantity({
    required this.value,
    required this.unit,
  });
}
```

Now:

```text
50 kg
20 m3
4 units
10 persons
```

can use the same mechanism.

---

# 5.5A.8.11 Resource constraints

Eventually I'd make capacity a generalized resource system.

```text
Resource
├── mass
├── volume
├── area
├── count
├── power
├── energy
├── bandwidth
└── custom
```

Then:

```text
Rack
capacity:
  mass = 500kg
  volume = 20m3
```

A machine:

```text
Machine
requirements:
  power = 15kW
```

A room:

```text
Room
capacity:
  people = 20
```

This will become useful later for simulation.

---

# 5.5A.8.12 Compatibility rule

Now introduce a generic compatibility constraint.

```dart
class CompatibilityConstraint
    implements PlacementConstraint {

  final String relation;

  const CompatibilityConstraint({
    required this.relation,
  });

  @override
  String get id => 'compatibility.$relation';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    final compatible =
        context.world.relationshipEngine
            .canRelate(
              context.subject.id,
              context.candidate.targetId,
              relation,
            );

    if (!compatible) {
      return ConstraintEvaluation(
        result: ConstraintResultType.fail,
        scoreImpact: 0,
        message:
            'Objects are not compatible.',
      );
    }

    return ConstraintEvaluation(
      result: ConstraintResultType.pass,
      scoreImpact: 0,
      message:
          'Compatibility requirement satisfied.',
    );
  }
}
```

Now:

```text
cargo → compatible with → rack
chair → compatible with → table
vehicle → compatible with → parking slot
machine → compatible with → factory zone
```

The engine doesn't care what the nouns mean.

---

# 5.5A.8.13 Semantic constraints

This becomes even more interesting.

Suppose the object has properties:

```json
{
  "category": "food",
  "temperature": "frozen",
  "hazardClass": "none"
}
```

The storage location has:

```json
{
  "temperature": "frozen"
}
```

A rule can evaluate:

```text
subject.temperature
        ==
target.temperature
```

That's a semantic constraint.

```dart
class PropertyMatchConstraint
    implements PlacementConstraint {

  final String subjectProperty;

  final String targetProperty;

  const PropertyMatchConstraint({
    required this.subjectProperty,
    required this.targetProperty,
  });

  @override
  String get id =>
      'property-match.$subjectProperty';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    PlacementContext context,
  ) {
    // compare semantic properties
  }
}
```

This is the bridge between:

```text
geometry
```

and:

```text
meaning
```

---

# 5.5A.8.14 Zone constraints

We also need spatial zones.

Example:

```text
Factory
├── production
├── maintenance
├── hazardous
└── pedestrian
```

A machine might be:

```text
allowed:
  production
```

but:

```text
forbidden:
  pedestrian
```

Create:

```dart
class ZoneConstraint
    implements PlacementConstraint {

  final Set<String> allowedZones;

  final Set<String> forbiddenZones;

  const ZoneConstraint({
    this.allowedZones = const {},
    this.forbiddenZones = const {},
  });

  ...
}
```

Now the same system can handle:

```text
airport restricted zone
hospital sterile zone
warehouse cold zone
factory safety zone
game no-build zone
```

---

# 5.5A.8.15 Containment constraint

We need to distinguish:

```text
inside
```

from:

```text
near
```

For example:

```text
Cargo
 ↓
inside RackSlot
```

or:

```text
Bed
 ↓
inside Room
```

or:

```text
Table
 ↓
inside Restaurant
```

Create:

```dart
class ContainmentConstraint
    implements PlacementConstraint {

  final double tolerance;

  const ContainmentConstraint({
    this.tolerance = 0,
  });

  @override
  String get id => 'containment';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  ...
}
```

The geometry engine should determine whether the object's **full relevant volume** lies within the target boundary.

Not merely:

```text
object.center inside target
```

That's a common but serious mistake.

---

# 5.5A.8.16 Partial containment

We may eventually need:

```text
fully contained
mostly contained
partially contained
outside
```

So define:

```dart
enum ContainmentLevel {
  outside,
  partial,
  mostlyContained,
  fullyContained,
}
```

Then different domains can configure the threshold.

For example:

```text
cargo:
  fullyContained

table:
  mostlyContained

vehicle:
  fullyContained
```

---

# 5.5A.8.17 Accessibility constraint

This becomes very useful for:

* restaurants
* hospitals
* warehouses
* factories
* public buildings

Example:

```text
chair
```

shouldn't be placed so that:

```text
wall
chair
chair
```

creates an inaccessible seat.

A generic rule:

```dart
class AccessibilityConstraint
    implements PlacementConstraint {
  ...
}
```

can eventually evaluate:

```text
can a required path reach this object?
```

That connects the placement engine to your future:

```text
navigation engine
```

---

# 5.5A.8.18 The important architecture connection

Your platform now starts looking like:

```text
                 Spatial World
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
    Geometry      Navigation     Semantics
        │             │             │
        └─────────────┼─────────────┘
                      ▼
                Rule Engine
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
      Collision   Clearance   Compatibility
          │           │           │
          └───────────┼───────────┘
                      ▼
                Placement Engine
```

This is the foundation for a real digital-twin kernel.

---

# 5.5A.8.19 Rule groups

Don't pass 30 constraints manually every time.

Create:

```dart
class ConstraintSet {
  final String id;

  final List<PlacementConstraint>
      constraints;

  const ConstraintSet({
    required this.id,
    required this.constraints,
  });
}
```

For example:

```text
warehouse.storage
```

could contain:

```text
collision
containment
capacity
compatibility
clearance
zone
```

Restaurant:

```text
restaurant.seating
```

could contain:

```text
collision
clearance
accessibility
compatibility
orientation
```

---

# 5.5A.8.20 Domain configuration

Eventually the domain definition can look like:

```json
{
  "ruleSet": "warehouse.storage",
  "constraints": [
    {
      "type": "collision",
      "mode": "hard"
    },
    {
      "type": "containment",
      "mode": "hard"
    },
    {
      "type": "capacity",
      "mode": "hard"
    },
    {
      "type": "clearance",
      "mode": "hard",
      "minimum": 0.2
    },
    {
      "type": "distance",
      "mode": "soft",
      "weight": 0.4
    }
  ]
}
```

That means the domain becomes **configuration**, rather than code.

This is exactly what we want.

---

# 5.5A.8.21 Rule registry

We'll need a registry that maps configuration → implementation.

```dart
class ConstraintRegistry {
  final Map<String, PlacementConstraint Function(
    Map<String, dynamic>,
  )> factories = {};

  void register(
    String type,
    PlacementConstraint Function(
      Map<String, dynamic>,
    ) factory,
  ) {
    factories[type] = factory;
  }

  PlacementConstraint create(
    String type,
    Map<String, dynamic> config,
  ) {
    final factory = factories[type];

    if (factory == null) {
      throw StateError(
        'Unknown constraint: $type',
      );
    }

    return factory(config);
  }
}
```

Then:

```dart
registry.register(
  'collision',
  (_) => CollisionConstraint(),
);
```

and:

```dart
registry.register(
  'clearance',
  (config) => ClearanceConstraint(
    minimumDistance:
        config['minimum'],
  ),
);
```

---

# 5.5A.8.22 Now the engine becomes dynamic

The user can eventually load:

```json
{
  "domain": "restaurant"
}
```

and the platform loads:

```text
restaurant domain
    ↓
entities
    ↓
components
    ↓
affordances
    ↓
rules
    ↓
behaviors
```

Or:

```json
{
  "domain": "warehouse"
}
```

and the engine loads a completely different configuration.

**The underlying spatial kernel remains the same.**

---

# 5.5A.8.23 Evaluate the entire constraint set

Create:

```dart
class ConstraintEngine {

  ConstraintEvaluationSummary evaluate(
    PlacementContext context,
    ConstraintSet set,
  ) {
    final evaluations =
        set.constraints
            .map(
              (constraint) =>
                  constraint.evaluate(context),
            )
            .toList();

    final hasHardFailure =
        evaluations.any(
          (evaluation) =>
              evaluation.result ==
                  ConstraintResultType.fail,
        );

    final scoreImpact =
        evaluations.fold<double>(
      0,
      (sum, evaluation) =>
          sum + evaluation.scoreImpact,
    );

    return ConstraintEvaluationSummary(
      valid: !hasHardFailure,
      evaluations: evaluations,
      scoreImpact: scoreImpact,
    );
  }
}
```

---

# 5.5A.8.24 Result should be explainable

Don't return:

```text
false
```

Return something like:

```json
{
  "valid": false,
  "score": 0.0,
  "violations": [
    {
      "rule": "clearance",
      "message": "Required 0.8m, available 0.42m"
    },
    {
      "rule": "compatibility",
      "message": "Object is incompatible with target"
    }
  ]
}
```

This will later power:

### UI

```text
❌ Can't place object

• Insufficient clearance
• Incompatible target
```

### AI

```text
The closest slot is unavailable
because it violates clearance.
```

### Simulation

```text
placement_failed(reason=clearance)
```

### Debugging

```text
constraint=clearance
expected=0.8
actual=0.42
```

One result object serves all four.

---

# 5.5A.8.25 Constraint priority

Some rules are more important than others.

For example:

```text
Safety
  ↓
Geometry
  ↓
Compatibility
  ↓
Accessibility
  ↓
Efficiency
  ↓
Aesthetics
```

Don't encode this only as a score.

Create priority:

```dart
class ConstraintPriority {
  final int value;

  const ConstraintPriority(
    this.value,
  );
}
```

Or simply:

```dart
enum ConstraintPriority {
  critical,
  high,
  normal,
  low,
}
```

Then the engine can distinguish:

```text
Safety violation
```

from:

```text
suboptimal distance
```

---

# 5.5A.8.26 Hard constraints shouldn't be bypassed by AI

This is important for your future intelligent-generation system.

Suppose an AI says:

> Put this machine here.

The AI **cannot override**:

```text
collision
safety
structural limits
restricted zone
```

unless the domain explicitly gives it permission.

Architecture:

```text
AI intent
   ↓
Placement Engine
   ↓
Hard constraints
   ↓
reject if invalid
```

Not:

```text
AI
 ↓
directly mutate world
```

This separation will make the platform dramatically safer and more predictable.

---

# 5.5A.8.27 Soft constraints can be optimized

Suppose 20 locations are valid.

The engine can score:

```text
distance
orientation
accessibility
energy cost
workflow efficiency
visual preference
```

Then:

```text
20 valid
 ↓
score
 ↓
rank
 ↓
best 5
```

This is where your future optimization engine can enter.

---

# 5.5A.8.28 First version of the complete placement algorithm

Conceptually:

```dart
PlacementResult findPlacement(
  PlacementRequest request,
) {
  final targets =
      discoverTargets(request);

  final candidates =
      generateCandidates(
        request,
        targets,
      );

  final evaluated =
      candidates.map((candidate) {
        final context =
            createContext(
              request,
              candidate,
            );

        final result =
            constraintEngine.evaluate(
              context,
              constraintSet,
            );

        candidate.validation =
            result;

        if (result.valid) {
          candidate.score =
              scorer.score(
                context,
                candidate,
              );
        }

        return candidate;
      }).toList();

  return selectBestResult(
    evaluated,
  );
}
```

This is the **core loop**.

---

# 5.5A.8.29 Test it before moving forward

Before we add more features, create tests for at least these scenarios:

### Test 1 — valid placement

```text
cargo → empty rack slot
```

Expected:

```text
success
```

### Test 2 — collision

```text
cargo → occupied geometry
```

Expected:

```text
failure
reason = collision
```

### Test 3 — capacity

```text
50kg cargo
20kg slot
```

Expected:

```text
failure
reason = capacity
```

### Test 4 — clearance

```text
required = 1m
available = 0.5m
```

Expected:

```text
failure
reason = clearance
```

### Test 5 — semantic incompatibility

```text
frozen cargo
ambient storage
```

Expected:

```text
failure
reason = compatibility
```

### Test 6 — multiple candidates

```text
slot A = 10m
slot B = 3m
slot C = 5m
```

Expected:

```text
B selected
```

---

# 5.5A.8.30 The bigger architecture we're heading toward

After 5.5A.8, your system has four distinct layers:

```text
┌─────────────────────────────────────┐
│          DOMAIN DEFINITION          │
│                                     │
│ warehouse / restaurant / factory   │
│ hospital / city / game / etc.      │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│          SEMANTIC SYSTEM            │
│                                     │
│ entities / properties / relations  │
│ affordances / behaviors             │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│          SPATIAL KERNEL             │
│                                     │
│ geometry / collision / containment  │
│ anchors / slots / placement         │
│ navigation / spatial index         │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│        RULE / CONSTRAINT ENGINE     │
│                                     │
│ hard constraints                    │
│ soft constraints                    │
│ scoring / optimization              │
└─────────────────────────────────────┘
```

And later:

```text
                    AI
                     │
              intent / prediction
                     │
                     ▼
              Decision Engine
                     │
                     ▼
             Rule + Spatial Kernel
                     │
                     ▼
                 World
                     │
                     ▼
              Simulation State
                     │
                     ▼
               AI Prediction
```

That's the architecture that can eventually support the **dynamic + interactive + simulation + game-like + intelligent-generation/prediction** goal you described.

---

## Next: Step 5.5A.9

The natural next step is **Relationship & Semantic Rule Evaluation**.

That will take us beyond:

> “Can this object physically fit here?”

into:

> **“Does this placement make semantic sense in the world?”**

For example:

```text
cargo
  └─ stored-in → cold-storage

chair
  └─ belongs-to → table

employee
  └─ assigned-to → workstation

machine
  └─ feeds → production-line

patient
  └─ assigned-to → bed

vehicle
  └─ parked-at → parking-slot
```

Then the engine can reject a placement not only because of **geometry**, but because the resulting **world state/relationship graph would be invalid**.
