Absolutely. **Step 5.5A.5 = Capacity, Compatibility & Containment Rules.**

This is where the spatial engine becomes much more than geometry.

Up to 5.5A.4, we can understand:

```text
cargo ON shelf
chair ADJACENT_TO table
product INSIDE cabinet
sensor ATTACHED_TO machine
box STACKED_ON box
```

But we still haven't answered:

> **"Is that relationship actually allowed?"**

For a truly domain-agnostic platform, the answer needs to come from **data-driven capabilities and constraints**, not hardcoded warehouse/restaurant logic.

---

# 5.5A.5 — Capacity, Compatibility & Containment

The new pipeline:

```text
Placement Request
       │
       ▼
Semantic Relation
       │
       ▼
Candidate Generation
       │
       ▼
Geometry
       │
       ▼
┌───────────────────────────────┐
│      Operational Rules        │
│                               │
│  Capacity                     │
│  Compatibility                │
│  Containment                  │
│  Support                      │
│  Weight                       │
│  Size                         │
│  Quantity                     │
│  Policy                       │
└───────────────┬───────────────┘
                │
                ▼
          Valid Candidates
                │
                ▼
             Scoring
```

The important architectural principle is:

> **The spatial engine provides generic mechanisms; the digital-twin model provides domain-specific rules.**

---

# 5.5A.5.1 First: distinguish the different kinds of "capacity"

Capacity isn't just one number.

An object/container can have:

### Physical capacity

```text
maximum volume
maximum dimensions
maximum weight
```

### Spatial capacity

```text
maximum slots
maximum occupants
maximum stacking height
```

### Semantic capacity

```text
allowed categories
allowed relationships
```

### Operational capacity

```text
maximum concurrent usage
maximum throughput
```

For example, a restaurant table might have:

```text
capacity = 4 people
```

A warehouse rack:

```text
maxWeight = 500kg
maxSlots = 10
```

A server rack:

```text
maxServers = 42U
maxPower = 8kW
```

A parking area:

```text
maxVehicles = 50
```

Same abstraction.

---

# 5.5A.5.2 Create `CapacityProfile`

Create:

```text
lib/domain/spatial/capacity_profile.dart
```

```dart
class CapacityProfile {
  final double? maxWeight;

  final double? maxVolume;

  final int? maxCount;

  final double? maxHeight;

  final double? maxWidth;

  final double? maxDepth;

  const CapacityProfile({
    this.maxWeight,
    this.maxVolume,
    this.maxCount,
    this.maxHeight,
    this.maxWidth,
    this.maxDepth,
  });
}
```

This is intentionally generic.

A container can specify only what matters.

For example:

```dart
CapacityProfile(
  maxWeight: 500,
)
```

or:

```dart
CapacityProfile(
  maxCount: 10,
)
```

or:

```dart
CapacityProfile(
  maxWeight: 500,
  maxCount: 10,
);
```

---

# 5.5A.5.3 Add capacity to `SpatialComponent`

Your component should now conceptually look like:

```dart
class SpatialComponent {
  final String id;

  final Transform transform;

  final Bounds localBounds;

  final SpatialCapabilities capabilities;

  final CapacityProfile? capacity;

  final List<SpatialAnchor> anchors;

  // ...
}
```

So:

```text
Rack
├── geometry
├── capabilities
├── capacity
├── anchors
└── relationships
```

---

# 5.5A.5.4 Capacity needs current usage

A rack saying:

```text
maxWeight = 500kg
```

doesn't tell us how much remains.

We calculate:

```text
remaining =
    maximum
    -
    current usage
```

Create:

```text
lib/application/spatial/capacity/capacity_calculator.dart
```

```dart
class CapacityUsage {
  final double weight;

  final double volume;

  final int count;

  const CapacityUsage({
    this.weight = 0,
    this.volume = 0,
    this.count = 0,
  });
}
```

Then:

```dart
class CapacityCalculator {
  const CapacityCalculator();

  CapacityUsage calculate(
    String containerId,
    SpatialWorld world,
  ) {
    final relationships =
        world.relationships.where(
      (relationship) =>
          relationship.objectId ==
          containerId,
    );

    var weight = 0.0;
    var volume = 0.0;
    var count = 0;

    for (final relationship
        in relationships) {
      final entity =
          world.component(
        relationship.subjectId,
      );

      if (entity == null) {
        continue;
      }

      weight +=
          entity.mass ?? 0;

      volume +=
          entity.volume;

      count++;
    }

    return CapacityUsage(
      weight: weight,
      volume: volume,
      count: count,
    );
  }
}
```

This is the first version.

Later we'll distinguish which relationships actually consume capacity.

---

# 5.5A.5.5 Not every relationship consumes capacity

This is important.

Suppose:

```text
chair ADJACENT_TO table
```

That shouldn't necessarily consume table capacity.

But:

```text
person SEATED_AT chair
```

might consume:

```text
1 seat
```

And:

```text
cargo INSIDE truck
```

consumes:

```text
volume
weight
count
```

Therefore, capacity consumption should be defined by relation semantics.

---

# 5.5A.5.6 Add `CapacityConsumption`

```dart
class CapacityConsumption {
  final double weight;

  final double volume;

  final int count;

  const CapacityConsumption({
    this.weight = 0,
    this.volume = 0,
    this.count = 0,
  });
}
```

And each relation can eventually declare:

```text
INSIDE:
    consumes volume
    consumes weight
    consumes count

ON:
    consumes support capacity
    possibly weight

ADJACENT_TO:
    usually zero

SEATED_AT:
    consumes seat count
```

This is much more flexible than hardcoding container behavior.

---

# 5.5A.5.7 Add capacity policy to relations

Extend the relation definition:

```dart
class SpatialRelationDefinition {
  final SpatialRelationType type;

  final SpatialRelationType? inverse;

  final bool symmetric;

  final bool directional;

  final bool requiresContainment;

  final bool requiresSupport;

  final bool allowsOverlap;

  final bool consumesCapacity;

  const SpatialRelationDefinition({
    required this.type,
    this.inverse,
    this.symmetric = false,
    this.directional = false,
    this.requiresContainment = false,
    this.requiresSupport = false,
    this.allowsOverlap = false,
    this.consumesCapacity = false,
  });
}
```

For example:

```dart
SpatialRelationType.inside:
    SpatialRelationDefinition(
  type: SpatialRelationType.inside,
  requiresContainment: true,
  consumesCapacity: true,
);
```

---

# 5.5A.5.8 But capacity isn't enough

Consider:

```text
Rack
maxWeight = 500kg
```

Current:

```text
400kg
```

New cargo:

```text
50kg
```

Capacity says:

```text
450kg <= 500kg
```

So valid.

But what if:

```text
cargo category = explosive
rack allowedCategories = general
```

Then it should still fail.

This introduces:

# Compatibility

---

# 5.5A.5.9 Create `CompatibilityProfile`

```text
lib/domain/spatial/compatibility_profile.dart
```

```dart
class CompatibilityProfile {
  final Set<String> allowedCategories;

  final Set<String> deniedCategories;

  final Set<String> requiredCapabilities;

  final Map<String, dynamic> properties;

  const CompatibilityProfile({
    this.allowedCategories = const {},
    this.deniedCategories = const {},
    this.requiredCapabilities = const {},
    this.properties = const {},
  });
}
```

This is intentionally generic.

For example:

```text
Rack
allowedCategories:
    cargo
```

or:

```text
ColdStorage
required:
    temperatureControlled
```

or:

```text
ChargingStation
allowed:
    electric_vehicle
```

---

# 5.5A.5.10 Don't use domain-specific enums

Avoid:

```dart
enum CargoType {
  food,
  explosive,
  electronics,
}
```

inside your core engine.

That would make the platform less agnostic.

Instead:

```text
category = "electronics"
```

or:

```text
properties:
    hazardous = true
```

The **domain schema** defines what those properties mean.

The core engine only evaluates generic predicates.

---

# 5.5A.5.11 Introduce `EntityProperty`

A useful abstraction:

```dart
class EntityProperty {
  final String key;

  final dynamic value;

  const EntityProperty({
    required this.key,
    required this.value,
  });
}
```

Then:

```text
cargo-001
properties:
    weight = 80
    category = "fragile"
    temperature = "cold"
    hazardous = false
```

And:

```text
storage-04
properties:
    temperature = "cold"
    hazardousAllowed = false
```

---

# 5.5A.5.12 Compatibility becomes a rule

Instead of:

```text
if cargo.type == ...
```

we use:

```text
property comparison
```

For example:

```dart
class PropertyCompatibilityRule {
  final String subjectProperty;

  final String targetProperty;

  const PropertyCompatibilityRule({
    required this.subjectProperty,
    required this.targetProperty,
  });
}
```

Then eventually:

```text
cargo.temperature
        ==
storage.temperature
```

must be true.

---

# 5.5A.5.13 Create generic `SpatialRule`

This is where the architecture starts becoming powerful.

```text
lib/domain/rules/spatial_rule.dart
```

```dart
abstract interface class SpatialRule {
  RuleEvaluation evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  );
}
```

And:

```dart
class RuleEvaluation {
  final bool satisfied;

  final double penalty;

  final String reason;

  const RuleEvaluation({
    required this.satisfied,
    this.penalty = 0,
    required this.reason,
  });
}
```

Notice we're not calling these only "constraints".

Some rules may be:

```text
hard constraint
```

while others are:

```text
soft preference
```

That's important.

---

# 5.5A.5.14 Hard vs soft rules

For example:

```text
collision
```

should usually be:

```text
HARD
```

because:

```text
collision = invalid
```

But:

```text
prefer same orientation
```

is:

```text
SOFT
```

because the placement can still happen.

Similarly:

```text
capacity exceeded
```

might be:

```text
HARD
```

while:

```text
prefer filling left-to-right
```

is:

```text
SOFT
```

So add:

```dart
enum RuleSeverity {
  hard,
  soft,
}
```

And:

```dart
class RuleEvaluation {
  final bool satisfied;

  final RuleSeverity severity;

  final double score;

  final String reason;

  const RuleEvaluation({
    required this.satisfied,
    required this.severity,
    this.score = 0,
    required this.reason,
  });
}
```

---

# 5.5A.5.15 Capacity constraint

Now create:

```text
capacity_constraint.dart
```

```dart
class CapacityConstraint
    implements PlacementConstraint {
  final CapacityCalculator calculator;

  const CapacityConstraint({
    required this.calculator,
  });

  @override
  ConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final container =
        world.component(
      request.targetId!,
    );

    final subject =
        world.component(
      request.subjectId,
    );

    if (container == null ||
        subject == null) {
      return const ConstraintResult.fail(
        'Missing container or subject',
      );
    }

    final capacity =
        container.capacity;

    if (capacity == null) {
      return const ConstraintResult.pass();
    }

    final usage =
        calculator.calculate(
      container.id,
      world,
    );

    if (capacity.maxWeight != null) {
      final nextWeight =
          usage.weight +
          (subject.mass ?? 0);

      if (nextWeight >
          capacity.maxWeight!) {
        return ConstraintResult.fail(
          'Weight capacity exceeded',
        );
      }
    }

    if (capacity.maxCount != null) {
      final nextCount =
          usage.count + 1;

      if (nextCount >
          capacity.maxCount!) {
        return ConstraintResult.fail(
          'Count capacity exceeded',
        );
      }
    }

    return const ConstraintResult.pass();
  }
}
```

---

# 5.5A.5.16 Example: warehouse

Rack:

```text
maxWeight = 500kg
maxCount = 10
```

Current:

```text
weight = 420kg
count = 7
```

Cargo:

```text
weight = 50kg
```

Result:

```text
420 + 50 = 470kg
```

and:

```text
7 + 1 = 8
```

Therefore:

```text
VALID
```

But another cargo:

```text
weight = 100kg
```

gives:

```text
420 + 100 = 520kg
```

Therefore:

```text
INVALID
```

even if the geometry fits perfectly.

---

# 5.5A.5.17 Add volume capacity

Volume:

```dart
final nextVolume =
    usage.volume +
    subject.volume;

if (capacity.maxVolume != null &&
    nextVolume >
        capacity.maxVolume!) {
  return ConstraintResult.fail(
    'Volume capacity exceeded',
  );
}
```

Now a container can say:

```text
maxVolume = 10m³
```

without knowing anything about warehouses.

---

# 5.5A.5.18 Physical dimensions are separate from volume

This distinction matters.

Suppose:

```text
cabinet:
    2m × 2m × 2m
```

Volume:

```text
8m³
```

A long object:

```text
4m × 1m × 1m
```

has volume:

```text
4m³
```

but doesn't fit.

Therefore:

```text
volume capacity
```

doesn't replace:

```text
geometric containment
```

You need both.

```text
ContainmentConstraint
+
CapacityConstraint
```

---

# 5.5A.5.19 Compatibility constraint

Create:

```text
compatibility_constraint.dart
```

```dart
class CompatibilityConstraint
    implements PlacementConstraint {
  const CompatibilityConstraint();

  @override
  ConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(
      request.subjectId,
    );

    final target =
        world.component(
      request.targetId!,
    );

    if (subject == null ||
        target == null) {
      return const ConstraintResult.fail(
        'Missing subject or target',
      );
    }

    final profile =
        target.compatibility;

    if (profile == null) {
      return const ConstraintResult.pass();
    }

    final category =
        subject.category;

    if (profile.deniedCategories
        .contains(category)) {
      return ConstraintResult.fail(
        'Category is not allowed',
      );
    }

    if (profile.allowedCategories
            .isNotEmpty &&
        !profile.allowedCategories
            .contains(category)) {
      return ConstraintResult.fail(
        'Category is not compatible',
      );
    }

    return const ConstraintResult.pass();
  }
}
```

---

# 5.5A.5.20 Example

Container:

```text
ColdStorage
allowed:
    food
    medicine
```

Object:

```text
Cargo
category:
    furniture
```

Geometry:

```text
FIT
```

Capacity:

```text
FIT
```

Compatibility:

```text
FAIL
```

Therefore:

```text
Placement rejected
```

This is exactly what a domain-agnostic platform needs.

---

# 5.5A.5.21 Add property-based compatibility

Category isn't enough.

Suppose:

```text
Storage A
temperature = cold
```

Cargo:

```text
temperatureRequired = cold
```

We want:

```text
compatible
```

Create a generic predicate model:

```dart
enum PropertyOperator {
  equals,
  notEquals,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  contains,
  inSet,
}
```

Then:

```dart
class PropertyRule {
  final String key;

  final PropertyOperator operator;

  final dynamic value;

  const PropertyRule({
    required this.key,
    required this.operator,
    required this.value,
  });
}
```

Now you can define:

```text
temperature
equals
cold
```

or:

```text
weight
lessOrEqual
500
```

or:

```text
category
inSet
[food, medicine]
```

without hardcoding the domain.

---

# 5.5A.5.22 Property evaluator

```dart
class PropertyEvaluator {
  const PropertyEvaluator();

  bool evaluate(
    dynamic actual,
    PropertyOperator operator,
    dynamic expected,
  ) {
    switch (operator) {
      case PropertyOperator.equals:
        return actual == expected;

      case PropertyOperator.notEquals:
        return actual != expected;

      case PropertyOperator.greaterThan:
        return actual > expected;

      case PropertyOperator.greaterOrEqual:
        return actual >= expected;

      case PropertyOperator.lessThan:
        return actual < expected;

      case PropertyOperator.lessOrEqual:
        return actual <= expected;

      case PropertyOperator.contains:
        return actual
            ?.contains(expected) ??
            false;

      case PropertyOperator.inSet:
        return expected
            is Iterable &&
            expected.contains(actual);
    }
  }
}
```

Later, you'll want proper type-safe numeric comparisons rather than relying on dynamic Dart operators.

---

# 5.5A.5.23 Containment becomes its own concept

Now we need to distinguish:

```text
INSIDE
```

from:

```text
ON
```

For `INSIDE`, the object must fit completely inside the target's usable volume.

The test conceptually is:

```text
subjectBounds ⊂ containerBounds
```

Not:

```text
subject.center ∈ container
```

That's a common mistake.

---

# 5.5A.5.24 Containment constraint

```dart
class ContainmentConstraint
    implements PlacementConstraint {
  const ContainmentConstraint();

  @override
  ConstraintResult evaluate(
    PlacementCandidate candidate,
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject =
        world.component(
      request.subjectId,
    );

    final container =
        world.component(
      request.targetId!,
    );

    if (subject == null ||
        container == null) {
      return const ConstraintResult.fail(
        'Missing subject or container',
      );
    }

    final bounds =
        subject.boundsAt(
      candidate.position,
      candidate.rotation,
    );

    final containerBounds =
        container.internalBounds;

    if (!containerBounds
        .contains(bounds)) {
      return const ConstraintResult.fail(
        'Object does not fit inside container',
      );
    }

    return const ConstraintResult.pass();
  }
}
```

This is a major improvement over simple point-in-volume testing.

---

# 5.5A.5.25 Add clearance inside containers

Even if an object technically fits:

```text
┌──────────────┐
│ ┌──────────┐ │
│ │  object  │ │
│ └──────────┘ │
└──────────────┘
```

we might want:

```text
minimum clearance = 0.1m
```

So:

```text
┌──────────────┐
│              │
│   ┌──────┐   │
│   │ obj  │   │
│   └──────┘   │
│              │
└──────────────┘
```

This can be represented by expanding the object's bounds before checking.

```dart
final expanded =
    bounds.expand(
  request.clearance,
);
```

Then:

```text
expanded object ⊂ container
```

must hold.

---

# 5.5A.5.26 Capacity isn't always additive

Here's a subtle problem.

If:

```text
box A
INSIDE
container B
```

and box A itself contains:

```text
box C
```

we don't necessarily want B's capacity to count C twice.

Example:

```text
Truck
 └── pallet
      ├── box A
      ├── box B
      └── box C
```

Truck capacity should probably count:

```text
pallet mass
+
perhaps cargo mass
```

depending on the model.

So capacity calculation eventually needs:

```text
capacity policy
+
relationship semantics
+
aggregation strategy
```

not just "sum all descendants."

---

# 5.5A.5.27 Introduce aggregation policy

```dart
enum CapacityAggregationMode {
  directChildren,
  allDescendants,
  explicit,
}
```

Then:

```dart
class CapacityPolicy {
  final CapacityAggregationMode mode;

  const CapacityPolicy({
    this.mode =
        CapacityAggregationMode.directChildren,
  });
}
```

For a simple shelf:

```text
directChildren
```

may be enough.

For a room:

```text
allDescendants
```

might make sense for occupant count.

For a complex factory:

```text
explicit
```

may be better.

---

# 5.5A.5.28 Slot capacity

Now let's add a very useful abstraction:

```text
maxCount
```

but also:

```text
availableSlots
```

A rack might have:

```text
10 slots
```

with:

```text
7 occupied
```

So:

```text
3 available
```

Create:

```dart
class CapacitySnapshot {
  final CapacityUsage usage;

  final CapacityProfile capacity;

  int get remainingCount {
    if (capacity.maxCount == null) {
      return 999999;
    }

    return capacity.maxCount! -
        usage.count;
  }

  const CapacitySnapshot({
    required this.usage,
    required this.capacity,
  });
}
```

Now the UI can display:

```text
Rack 03
███████░░░
7 / 10 slots
```

without any warehouse-specific UI code.

---

# 5.5A.5.29 Capacity can be dimensional

For a shelf:

```text
usable width = 2m
```

If products are placed sequentially:

```text
[A][B][C]
```

we may want to calculate:

```text
occupiedWidth
```

not just volume.

For example:

```text
2m shelf
A = 0.5m
B = 0.5m
C = 0.5m

occupied = 1.5m
remaining = 0.5m
```

This is different from:

```text
volume capacity
```

So introduce:

```dart
class SpatialCapacityUsage {
  final double width;

  final double depth;

  final double height;

  final double volume;

  final double weight;

  final int count;

  const SpatialCapacityUsage({
    this.width = 0,
    this.depth = 0,
    this.height = 0,
    this.volume = 0,
    this.weight = 0,
    this.count = 0,
  });
}
```

This gives us the basis for more sophisticated packing.

---

# 5.5A.5.30 Compatibility isn't just "allowed/not allowed"

This is where soft rules become useful.

Suppose:

```text
Rack A:
preferred category = electronics

Rack B:
allowed category = electronics
```

Both are valid.

But:

```text
Rack A
```

should score higher.

So compatibility needs:

```text
hard incompatibility
```

and:

```text
soft preference
```

Example:

```text
hard:
hazardous forbidden

soft:
electronics preferred
```

Then:

```text
candidate A
compatibility score = 1.0

candidate B
compatibility score = 0.5
```

---

# 5.5A.5.31 Create `CompatibilityScore`

```dart
class CompatibilityScore
    implements PlacementScorer {
  const CompatibilityScore();

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

    final target =
        world.component(
      request.targetId!,
    );

    if (subject == null ||
        target == null) {
      return 0;
    }

    final profile =
        target.compatibility;

    if (profile == null) {
      return 0;
    }

    if (profile.preferredCategories
        .contains(subject.category)) {
      return 1.0;
    }

    return 0;
  }
}
```

So:

```text
constraints
```

decide:

```text
allowed?
```

while:

```text
scorers
```

decide:

```text
preferred?
```

Excellent separation.

---

# 5.5A.5.32 Add preferred properties

Extend compatibility:

```dart
class CompatibilityProfile {
  final Set<String> allowedCategories;

  final Set<String> deniedCategories;

  final Set<String> preferredCategories;

  final List<PropertyRule> requiredProperties;

  final List<PropertyRule> preferredProperties;

  const CompatibilityProfile({
    this.allowedCategories = const {},
    this.deniedCategories = const {},
    this.preferredCategories = const {},
    this.requiredProperties = const [],
    this.preferredProperties = const [],
  });
}
```

Now the domain model can express:

```text
Required:
    temperature == cold

Preferred:
    fragile == false
```

without modifying engine code.

---

# 5.5A.5.33 Example: restaurant

Table:

```text
capacity:
    maxCount = 4
```

Four chairs are already associated:

```text
chair-1
chair-2
chair-3
chair-4
```

Trying to place:

```text
chair-5
```

should produce:

```text
capacity exceeded
```

But there is another possibility:

```text
table has 4 seats
```

and the user tries to place:

```text
person-5
```

That should also fail.

Same capacity system.

The engine doesn't care whether the capacity represents:

```text
chairs
people
cargo
vehicles
servers
```

---

# 5.5A.5.34 Example: server rack

Rack:

```text
maxHeight = 42U
maxPower = 8kW
```

Server:

```text
height = 4U
power = 0.6kW
```

Current:

```text
height = 36U
power = 7kW
```

New server:

```text
40U
7.6kW
```

Valid.

Another:

```text
height = 8U
power = 1.5kW
```

would exceed:

```text
height: 44U > 42U
power: 8.5kW > 8kW
```

Therefore:

```text
INVALID
```

Same engine.

---

# 5.5A.5.35 Example: parking

Parking area:

```text
maxCount = 20
allowedCategories:
    vehicle
```

Candidate:

```text
vehicle
```

passes.

Candidate:

```text
pedestrian
```

fails compatibility.

Candidate:

```text
vehicle
```

when 20 are already parked:

```text
fails capacity
```

Candidate:

```text
vehicle
```

with enough capacity but physically overlapping another vehicle:

```text
fails collision
```

This demonstrates why we need multiple independent validation layers.

---

# 5.5A.5.36 Example: hazardous materials

Container:

```text
allowed:
    hazardous = false
```

Cargo:

```text
hazardous = true
```

Geometry:

```text
valid
```

Capacity:

```text
valid
```

Compatibility:

```text
invalid
```

Result:

```text
REJECT
reason:
  hazardous material not permitted
```

The engine doesn't need to understand what a hazardous material is.

The domain model tells it.

---

# 5.5A.5.37 We should introduce explainability now

This becomes increasingly important as rules multiply.

Instead of:

```text
PlacementResult.invalid()
```

we want:

```text
Placement rejected:

✓ geometry
✓ collision
✓ containment
✓ capacity

✗ compatibility
  hazardous = true
  target allows hazardous = false
```

Create:

```dart
class PlacementDiagnostic {
  final String rule;

  final bool passed;

  final String message;

  final double? score;

  const PlacementDiagnostic({
    required this.rule,
    required this.passed,
    required this.message,
    this.score,
  });
}
```

Then:

```text
PlacementResult
├── valid
├── position
├── score
└── diagnostics[]
```

This will become extremely valuable for your interactive UI.

---

# 5.5A.5.38 Visual feedback

The game-style editor can now show:

```text
         ┌─────────────────┐
         │       RACK      │
         │ [A][B][C][D]    │
         └─────────────────┘
                  ↑
               dragged
                cargo
```

Candidate:

```text
red
✗ capacity exceeded
```

Another:

```text
green
✓ valid
```

Another:

```text
yellow
⚠ compatible but not preferred
```

This is much better than merely:

```text
red = collision
```

The user can understand **why** the system behaves as it does.

---

# 5.5A.5.39 Add rule priority

Some rules should be evaluated before expensive geometry.

For example:

```text
category incompatible
```

can be rejected immediately.

There's no reason to perform expensive collision detection.

So eventually each rule gets:

```dart
class RulePriority {
  final int value;

  const RulePriority(
    this.value,
  );
}
```

Pipeline:

```text
cheap rules
   ↓
compatibility
   ↓
capacity
   ↓
containment
   ↓
collision
   ↓
advanced geometry
```

This can dramatically improve performance.

---

# 5.5A.5.40 But don't over-optimize yet

For the current implementation, just make the architecture support ordering:

```dart
class PlacementRuleSet {
  final List<PlacementConstraint>
      constraints;

  const PlacementRuleSet({
    required this.constraints,
  });
}
```

Then later:

```text
RulePipeline
```

can sort rules by cost.

---

# 5.5A.5.41 Update `PlacementEngine`

The engine now becomes:

```dart
class PlacementEngine {
  final CandidateGenerator candidateGenerator;

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
          <ConstraintResult>[];

      var valid = true;

      for (final constraint
          in constraints) {
        final result =
            constraint.evaluate(
          candidate,
          request,
          world,
        );

        evaluations.add(result);

        if (!result.satisfied) {
          valid = false;
          break;
        }
      }

      if (!valid) {
        continue;
      }

      final score =
          scorer.score(
        candidate,
        request,
        world,
      );

      final result =
          PlacementResult(
        valid: true,
        position: candidate.position,
        rotation: candidate.rotation,
        surfaceId: candidate.surfaceId,
        anchorId: candidate.anchorId,
        score: score,
        diagnostics: evaluations,
      );

      if (best == null ||
          score > best.score) {
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

---

# 5.5A.5.42 But there is a subtle issue here

We're currently doing:

```text
first failed constraint
      ↓
stop
```

That's efficient, but bad for UX.

If the user asks:

> "Why can't I place this?"

we want:

```text
collision       ✓
capacity        ✗
compatibility   ✗
containment     ✓
```

So I recommend two modes:

```text
Fast mode
    stop on first hard failure

Diagnostic mode
    evaluate all rules
```

---

# 5.5A.5.43 Add evaluation mode

```dart
enum PlacementEvaluationMode {
  fast,
  diagnostic,
}
```

Then:

```dart
PlacementResult findPlacement(
  PlacementRequest request,
  SpatialWorld world, {
  PlacementEvaluationMode mode =
      PlacementEvaluationMode.fast,
})
```

This gives you:

### Runtime

```text
fast
```

### Editor/debugging

```text
diagnostic
```

### AI/explanation

```text
diagnostic
```

Very useful.

---

# 5.5A.5.44 Now introduce the concept of "resource"

We're getting close to a very important general abstraction.

Capacity isn't always:

```text
weight
volume
count
```

It can be:

```text
power
water
bandwidth
seating
parking
storage
processing capacity
time
temperature range
```

So eventually I'd abstract:

```dart
class ResourceCapacity {
  final String resource;

  final double maximum;

  final double current;

  const ResourceCapacity({
    required this.resource,
    required this.maximum,
    required this.current,
  });

  double get remaining =>
      maximum - current;
}
```

Now:

```text
server rack:
    power = 8kW

restaurant:
    seating = 40

warehouse:
    storage_volume = 1000m3

factory:
    throughput = 500 units/hour
```

Same mechanism.

---

# 5.5A.5.45 This is the path toward a truly domain-agnostic platform

Your core model eventually becomes:

```text
Entity
│
├── Geometry
├── Transform
├── Properties
├── Capabilities
├── Anchors
├── Relationships
└── Resources
```

And the environment:

```text
World
│
├── Entities
├── Relationships
├── Spatial structures
├── Rules
└── Resource states
```

Then a domain is largely just:

```text
Domain Definition
│
├── entity types
├── properties
├── relations
├── capabilities
├── rules
└── resource definitions
```

This is exactly the direction I'd recommend for your platform.

---

# 5.5A.5.46 Example domain definition

Imagine a warehouse configuration:

```json
{
  "entities": {
    "rack": {
      "capabilities": [
        "contain",
        "support"
      ]
    },
    "cargo": {
      "capabilities": [
        "beContained",
        "beSupported"
      ]
    }
  },
  "relations": {
    "inside": {
      "consumesCapacity": true
    },
    "on": {
      "requiresSupport": true
    }
  }
}
```

Restaurant:

```json
{
  "entities": {
    "table": {
      "capabilities": [
        "support",
        "provideSeating"
      ]
    },
    "chair": {
      "capabilities": [
        "provideSeating"
      ]
    }
  }
}
```

The spatial engine doesn't change.

Only the **domain configuration** changes.

---

# 5.5A.5.47 This is the architecture we're aiming toward

```text
                  DIGITAL TWIN PLATFORM
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼                                 ▼
    DOMAIN DEFINITION                  CORE ENGINE
          │                                 │
          ├── entity types                  ├── geometry
          ├── properties                    ├── collision
          ├── capabilities                  ├── placement
          ├── relations                     ├── containment
          ├── rules                         ├── capacity
          └── resources                     ├── compatibility
                                            ├── simulation
                                            └── reasoning
```

Then:

```text
Warehouse
Restaurant
Factory
Hospital
Retail
Construction
Smart City
Logistics
```

are primarily **data/configuration**, not separate engines.

---

# 5.5A.5.48 One more thing: rules should be composable

Eventually:

```text
PlacementPolicy
```

could look like:

```dart
class PlacementPolicy {
  final List<SpatialRule> rules;

  const PlacementPolicy({
    required this.rules,
  });
}
```

A particular target can then have:

```text
Rack policy
├── collision
├── containment
├── weight
├── volume
├── category
└── hazardous-material rule
```

while another has:

```text
Table policy
├── collision
├── seating capacity
├── accessibility
└── clearance
```

Same engine.

---

# 5.5A.5.49 Policy inheritance

This will be useful later.

For example:

```text
warehouse
   ↓
storage zone
   ↓
rack
   ↓
rack slot
```

Rules can inherit:

```text
warehouse policy
      +
zone policy
      +
rack policy
      +
slot policy
```

So a slot doesn't need to duplicate every rule.

This gives us:

```text
Policy hierarchy
```

which will become useful when we get into larger digital-twin scenes.

Don't implement inheritance yet; just keep the architecture open for it.

---

# 5.5A.5.50 The final placement decision now looks like this

Suppose:

```text
Cargo-123
```

is dragged toward:

```text
Rack-05
```

The system generates candidates.

For each candidate:

```text
1. Is geometry valid?
        ↓
2. Is collision valid?
        ↓
3. Does it fit?
        ↓
4. Is it contained/supported?
        ↓
5. Is capacity available?
        ↓
6. Is category compatible?
        ↓
7. Are required properties compatible?
        ↓
8. Is the candidate preferred?
        ↓
9. Score
```

Then:

```text
             Candidate A
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
    geometry   capacity  compatibility
       ✓          ✓          ✓
                 │
                 ▼
               score
                 │
                 ▼
               0.92


             Candidate B
                 │
       ┌─────────┼─────────┐
       ▼         ▼         ▼
    geometry   capacity  compatibility
       ✓          ✗          ✓
                 │
                 ▼
               REJECT
```

Best valid candidate wins.

---

# 5.5A.5.51 What Step 5.5A.5 gives you

At this point, your platform can reason about:

### Geometry

```text
Does it physically fit?
```

### Collision

```text
Does it intersect something?
```

### Containment

```text
Is it actually inside?
```

### Support

```text
Can something hold it?
```

### Capacity

```text
Is there enough room/weight/count/resource?
```

### Compatibility

```text
Is this object allowed here?
```

### Preference

```text
Which valid location is better?
```

### Semantics

```text
What relationship exists after placement?
```

That is a **major milestone**.

---

# 5.5A.5.52 The architecture after 5.5A.5

```text
                          USER INTENT
                              │
                              ▼
                     PlacementRequest
                              │
                              ▼
                     Spatial Relation
                              │
                              ▼
                 Relation Candidate Generator
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           Surface          Anchor         Neighbor
              │               │               │
              └───────────────┼───────────────┘
                              ▼
                       Candidate Pool
                              │
                              ▼
                ┌─────────────────────────┐
                │      Rule Pipeline      │
                │                         │
                │ Geometry                │
                │ Collision               │
                │ Containment             │
                │ Support                 │
                │ Capacity                │
                │ Compatibility           │
                │ Property Rules           │
                │ Domain Policies           │
                └────────────┬────────────┘
                             │
                      valid candidates
                             │
                             ▼
                         Scoring
                             │
                             ▼
                      Best Placement
                             │
                 ┌───────────┴───────────┐
                 ▼                       ▼
           Geometry State          Semantic State
                 │                       │
                 ▼                       ▼
             Transform             Relationship
                                         │
                                         ▼
                                  Capacity Update
```

This is now a very solid foundation.

---

# What I would build next: 5.5A.6

The next step should **not** immediately be AI.

We have reached the point where performance becomes important.

Right now, a naive implementation still does:

```text
candidate
   ↓
scan every object
   ↓
collision / neighbor / capacity
```

That will break when your digital twin becomes:

```text
10,000 objects
100,000 objects
1,000,000 objects
```

So **5.5A.6 should be Spatial Indexing & Incremental Spatial Queries**.

We'll introduce:

```text
SpatialIndex
    │
    ├── AABB queries
    ├── nearest-neighbor
    ├── overlap queries
    ├── containment queries
    └── ray/proximity queries
```

with an architecture roughly like:

```text
                         SpatialWorld
                              │
                    ┌─────────┴─────────┐
                    │                   │
              Entity State        Spatial Index
                                      │
                         ┌────────────┼────────────┐
                         ▼            ▼            ▼
                       AABB         Grid         BVH
                         │            │            │
                         └────────────┼────────────┘
                                      ▼
                              Candidate Queries
```

That will let the exact same placement/rule architecture work efficiently for a **small restaurant scene and a huge warehouse/city-scale digital twin**.
