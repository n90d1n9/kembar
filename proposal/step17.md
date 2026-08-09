# Step 5.5A.9 — Relationship & Semantic Rule Evaluation

This is the next major jump.

Up to **5.5A.8**, we established:

```text
Can the object physically be placed here?
```

Now we add:

```text
Does placing it here make sense in the world?
```

That distinction is essential for a truly **domain-agnostic digital-twin platform**.

---

# 5.5A.9.1 Physical validity vs semantic validity

Consider:

```text
Frozen food
     ↓
Storage room
```

Geometrically:

```text
✓ fits
✓ no collision
✓ enough capacity
✓ enough clearance
```

But suppose the room is:

```text
ambient-temperature
```

Then:

```text
❌ semantically invalid
```

Another example:

```text
Chair
 ↓
Parking slot
```

It may physically fit.

But:

```text
❌ wrong relationship
```

Another:

```text
Machine
 ↓
Pedestrian walkway
```

It may fit geometrically.

But:

```text
❌ violates world semantics
```

So our placement pipeline becomes:

```text
                    Placement
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
        Physical Rules       Semantic Rules
              │                   │
       collision              compatibility
       containment             relationships
       clearance               properties
       capacity                roles
              │                   │
              └─────────┬─────────┘
                        ▼
                    Valid?
```

---

# 5.5A.9.2 Don't confuse relationships with constraints

This distinction is important.

A **relationship** describes the world:

```text
cargo-01
    stored-in
rack-03
```

A **constraint** determines whether that relationship is allowed:

```text
cargo
    stored-in
rack
```

may be valid only if:

```text
cargo.category
compatibleWith
rack.allowedCategories
```

So:

```text
Relationship
= what is true

Constraint
= what is allowed
```

This separation will become extremely useful later.

---

# 5.5A.9.3 Introduce a generic `Relation`

Create:

```text
lib/domain/semantic/relation.dart
```

```dart
class EntityRelation {
  final String id;

  final String subjectId;

  final String predicate;

  final String objectId;

  final Map<String, dynamic> properties;

  const EntityRelation({
    required this.id,
    required this.subjectId,
    required this.predicate,
    required this.objectId,
    this.properties = const {},
  });
}
```

Now your world can contain:

```text
cargo-01
    stored-in
rack-03
```

as:

```dart
EntityRelation(
  id: 'relation-01',
  subjectId: 'cargo-01',
  predicate: 'stored-in',
  objectId: 'rack-03',
);
```

---

# 5.5A.9.4 Predicates should be dynamic

Don't make this:

```dart
enum RelationType {
  storedIn,
  seatedAt,
  parkedAt,
  assignedTo,
}
```

That would make your core engine domain-specific.

Instead:

```dart
typedef RelationPredicate = String;
```

Then domains can define:

```text
stored-in
seated-at
parked-at
assigned-to
connected-to
feeds
powered-by
located-in
contains
belongs-to
managed-by
```

The engine doesn't need to understand the English meaning.

It only needs a **relation model**.

---

# 5.5A.9.5 Relationship graph

We now need a graph.

```text
Entity A
   │
   │ predicate
   ▼
Entity B
```

Create:

```dart
abstract interface class RelationshipGraph {
  void add(EntityRelation relation);

  void remove(String relationId);

  List<EntityRelation> outgoing(
    String entityId,
  );

  List<EntityRelation> incoming(
    String entityId,
  );

  bool exists({
    required String subjectId,
    required String predicate,
    required String objectId,
  });
}
```

Implementation can initially be simple:

```dart
class InMemoryRelationshipGraph
    implements RelationshipGraph {

  final Map<String, EntityRelation>
      _relations = {};

  @override
  void add(EntityRelation relation) {
    _relations[relation.id] = relation;
  }

  @override
  void remove(String relationId) {
    _relations.remove(relationId);
  }

  @override
  List<EntityRelation> outgoing(
    String entityId,
  ) {
    return _relations.values
        .where(
          (r) => r.subjectId == entityId,
        )
        .toList();
  }

  @override
  List<EntityRelation> incoming(
    String entityId,
  ) {
    return _relations.values
        .where(
          (r) => r.objectId == entityId,
        )
        .toList();
  }

  @override
  bool exists({
    required String subjectId,
    required String predicate,
    required String objectId,
  }) {
    return _relations.values.any(
      (r) =>
          r.subjectId == subjectId &&
          r.predicate == predicate &&
          r.objectId == objectId,
    );
  }
}
```

Later this can become a much more sophisticated graph database.

---

# 5.5A.9.6 But placement should not immediately create relationships

This is another important design decision.

During preview:

```text
User dragging chair
```

we shouldn't create:

```text
chair → seated-at → table
```

because the user hasn't committed yet.

Instead:

```text
Preview
   ↓
Potential relationship
```

Only after:

```text
Commit
```

do we mutate:

```text
World graph
```

So we need a **prospective relationship**.

---

# 5.5A.9.7 `RelationshipProposal`

Create:

```dart
class RelationshipProposal {
  final String subjectId;

  final String predicate;

  final String objectId;

  final Map<String, dynamic> properties;

  const RelationshipProposal({
    required this.subjectId,
    required this.predicate,
    required this.objectId,
    this.properties = const {},
  });
}
```

A candidate placement might produce:

```text
Chair-17
   ↓
seated-at
   ↓
Table-03 / Seat-02
```

as a proposal.

---

# 5.5A.9.8 Candidate now needs semantic consequences

Previously:

```text
PlacementCandidate
```

contained:

```text
transform
score
validation
```

Now add:

```dart
final List<RelationshipProposal>
    relationshipProposals;
```

So a candidate becomes:

```text
Placement Candidate
├── transform
├── target
├── slot
├── physical validation
├── semantic validation
├── relationship proposals
└── score
```

This is much more powerful.

---

# 5.5A.9.9 Example: chair placement

Suppose:

```text
table-01
```

has:

```text
seat-01
seat-02
seat-03
seat-04
```

Candidate:

```text
chair-17 → seat-02
```

produces:

```text
RelationshipProposal(
  subjectId: 'chair-17',
  predicate: 'seated-at',
  objectId: 'table-01/seat-02',
)
```

Then semantic rules evaluate it.

---

# 5.5A.9.10 Semantic constraints

Create:

```text
lib/domain/semantic/semantic_constraint.dart
```

```dart
abstract interface class SemanticConstraint {

  String get id;

  ConstraintMode get mode;

  ConstraintEvaluation evaluate(
    SemanticContext context,
  );
}
```

And:

```dart
class SemanticContext {
  final Entity subject;

  final PlacementCandidate candidate;

  final RelationshipGraph graph;

  final WorldModel world;

  const SemanticContext({
    required this.subject,
    required this.candidate,
    required this.graph,
    required this.world,
  });
}
```

Notice that this is different from pure spatial context.

---

# 5.5A.9.11 Why separate spatial and semantic contexts?

Because you want to preserve clean architecture.

Spatial engine knows:

```text
geometry
position
bounds
collision
distance
```

Semantic engine knows:

```text
properties
roles
relations
state
meaning
```

Then:

```text
Spatial Kernel
       │
       ▼
Spatial candidate
       │
       ▼
Semantic Kernel
       │
       ▼
World-valid candidate
```

This prevents your geometry engine from becoming a giant business-rule engine.

---

# 5.5A.9.12 Property-based semantic rules

The first useful semantic rule is:

```text
property compatibility
```

For example:

```text
cargo.temperature = frozen

storage.temperature = frozen
```

valid.

But:

```text
cargo.temperature = frozen

storage.temperature = ambient
```

invalid.

Generic configuration:

```json
{
  "type": "property-match",
  "subjectProperty": "temperature",
  "targetProperty": "temperature",
  "mode": "hard"
}
```

Now the rule doesn't know anything about food.

---

# 5.5A.9.13 Property comparison engine

Create:

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
class PropertyConstraint {
  final String subjectProperty;

  final String targetProperty;

  final PropertyOperator operator;

  const PropertyConstraint({
    required this.subjectProperty,
    required this.targetProperty,
    required this.operator,
  });
}
```

Now we can express:

```text
temperature == temperature
```

or:

```text
weight <= maxWeight
```

or:

```text
category IN allowedCategories
```

without writing another domain-specific class.

---

# 5.5A.9.14 Relationship cardinality

Now we hit an important problem.

Suppose:

```text
Seat-01
```

can only have one person.

We need:

```text
seat-01
    seated-at
    ↓
person-01
```

but not:

```text
seat-01
    seated-at
    ↓
person-01

seat-01
    seated-at
    ↓
person-02
```

at the same time.

So relationships need cardinality.

```dart
enum RelationCardinality {
  oneToOne,
  oneToMany,
  manyToOne,
  manyToMany,
}
```

But even this may be too simplistic eventually.

---

# 5.5A.9.15 Better: relationship constraints

Define:

```text
RelationDefinition
```

```dart
class RelationDefinition {
  final String predicate;

  final RelationCardinality cardinality;

  final bool symmetric;

  const RelationDefinition({
    required this.predicate,
    required this.cardinality,
    this.symmetric = false,
  });
}
```

Example:

```json
{
  "predicate": "seated-at",
  "cardinality": "many-to-one"
}
```

Meaning:

```text
many people
    ↓
one seat
```

Actually, for seating, you may want the reverse depending on graph direction. This is why **direction and cardinality should be explicitly defined**, rather than inferred.

---

# 5.5A.9.16 Relation ontology

Now we're approaching a lightweight ontology system.

For example:

```text
stored-in
  subject: Cargo
  object: StorageLocation

seated-at
  subject: Person
  object: Seat

parked-at
  subject: Vehicle
  object: ParkingSlot

located-in
  subject: Entity
  object: SpatialContainer
```

The platform can represent these definitions as data.

```json
{
  "predicate": "stored-in",
  "domain": ["cargo"],
  "range": ["storage-location"],
  "cardinality": "many-to-one"
}
```

This is extremely useful for domain generation.

---

# 5.5A.9.17 Domain and range

Two important concepts:

### Domain

What can appear on the left?

```text
stored-in
domain = cargo
```

### Range

What can appear on the right?

```text
stored-in
range = storage-location
```

Then:

```text
Cargo → stored-in → Rack
```

might be valid.

But:

```text
Chair → stored-in → Employee
```

would fail semantic validation.

Again:

**the spatial engine doesn't need to know what a chair or employee is.**

It simply evaluates the relation definition.

---

# 5.5A.9.18 Generic `RelationRule`

Create:

```dart
class RelationRule
    implements SemanticConstraint {

  final RelationDefinition definition;

  const RelationRule({
    required this.definition,
  });

  @override
  String get id =>
      'relation.${definition.predicate}';

  @override
  ConstraintMode get mode =>
      ConstraintMode.hard;

  @override
  ConstraintEvaluation evaluate(
    SemanticContext context,
  ) {
    // validate proposed relationship
  }
}
```

It can check:

```text
domain
range
cardinality
existing relations
```

---

# 5.5A.9.19 Example: stored-in

Configuration:

```json
{
  "predicate": "stored-in",
  "domain": ["cargo"],
  "range": ["storage-location"],
  "cardinality": "many-to-one"
}
```

Candidate:

```text
cargo-123
   ↓
stored-in
   ↓
rack-slot-04
```

Evaluation:

```text
cargo type?
✓ cargo

target type?
✓ storage-location

slot available?
✓

relationship cardinality?
✓
```

Result:

```text
VALID
```

---

# 5.5A.9.20 Example: invalid semantic placement

Suppose:

```text
cargo-123
   ↓
stored-in
   ↓
restaurant-table-01
```

Geometry:

```text
✓
```

Semantic:

```text
domain:
cargo ✓

range:
restaurant-table ✕

→ FAIL
```

That's exactly the distinction we need.

---

# 5.5A.9.21 Existing relationships also matter

Suppose:

```text
employee-01
assigned-to
workstation-04
```

and user tries:

```text
employee-01
assigned-to
workstation-05
```

Should that be allowed?

Depends on domain.

Maybe:

```text
one employee → one workstation
```

Then the new placement must either:

```text
reject
```

or:

```text
replace previous assignment
```

This means relationship rules need access to the **existing graph**.

---

# 5.5A.9.22 Relationship transition

This leads to an important concept:

> A placement doesn't only create state. It can **change state**.

Before:

```text
Employee
   │
   └── assigned-to → Desk-01
```

After moving:

```text
Employee
   │
   └── assigned-to → Desk-02
```

So the placement candidate should contain:

```text
Relationship changes
```

not just new relationships.

---

# 5.5A.9.23 `RelationshipChangeSet`

Create:

```dart
class RelationshipChangeSet {
  final List<EntityRelation> additions;

  final List<String> removals;

  const RelationshipChangeSet({
    this.additions = const [],
    this.removals = const [],
  });
}
```

Now a candidate can say:

```text
REMOVE
employee-01 → assigned-to → desk-01

ADD
employee-01 → assigned-to → desk-02
```

This is a much more powerful abstraction.

---

# 5.5A.9.24 Why this matters for simulation

Imagine a warehouse robot.

Before:

```text
robot-01
located-at
zone-A
```

Simulation moves it:

```text
zone-A → zone-B
```

The relationship state changes.

Or:

```text
truck
carrying
cargo
```

Then cargo is unloaded:

```text
truck
carrying
cargo
```

becomes:

```text
warehouse
contains
cargo
```

So your relationship engine isn't just for UI.

It's part of the **simulation state model**.

---

# 5.5A.9.25 Relationship state transitions

Eventually define:

```dart
class RelationshipTransition {
  final RelationshipChangeSet changes;

  final String reason;

  const RelationshipTransition({
    required this.changes,
    required this.reason,
  });
}
```

Then:

```text
Placement
   ↓
Relationship transition
   ↓
Validation
   ↓
Commit
```

This gives you a clean event/state architecture later.

---

# 5.5A.9.26 Semantic rules can depend on world state

Example:

```text
Machine
```

can only be placed if:

```text
power source
```

is available.

That is not purely geometry.

You might have:

```text
Machine
requires
Power
```

and:

```text
PowerOutlet
provides
Power
```

The semantic engine can ask:

```text
Does this candidate placement create
a valid "powered-by" relationship?
```

This begins to look like actual **world reasoning**.

---

# 5.5A.9.27 Dependency relationships

You can define:

```text
requires
provides
depends-on
connected-to
```

For example:

```text
Machine-01
   requires
Power-01
```

A candidate placement could create:

```text
Machine-01
   connected-to
PowerOutlet-03
```

Then:

```text
requires(power)
```

is satisfied.

---

# 5.5A.9.28 Example: factory machine

Suppose:

```text
Machine
```

requires:

```text
power >= 20kW
water >= 5L/min
```

Candidate location:

```text
Zone-04
```

near:

```text
PowerOutlet-01 = 30kW
WaterOutlet-02 = 10L/min
```

Semantic engine can determine:

```text
power requirement ✓
water requirement ✓
```

while another location:

```text
Zone-07
```

has:

```text
power = 10kW
```

and therefore:

```text
❌ insufficient resource
```

That is already moving beyond simple object placement into **constraint-based world configuration**.

---

# 5.5A.9.29 Relationship query API

We'll need a query layer.

```dart
abstract interface class RelationshipQuery {

  bool exists({
    required String subject,
    required String predicate,
    required String object,
  });

  List<String> objectsOf({
    required String subject,
    required String predicate,
  });

  List<String> subjectsOf({
    required String predicate,
    required String object,
  });
}
```

Examples:

```dart
query.objectsOf(
  subject: 'cargo-01',
  predicate: 'stored-in',
);
```

returns:

```text
rack-slot-04
```

Or:

```dart
query.subjectsOf(
  predicate: 'assigned-to',
  object: 'desk-04',
);
```

returns:

```text
employee-17
```

---

# 5.5A.9.30 Semantic query should eventually become generic

Eventually I'd like:

```text
Find:
  entities where

  type = cargo
  temperature = frozen
  weight < 50kg
  stored-in = cold-storage
```

That can later become a query language.

Something like:

```json
{
  "type": "cargo",
  "properties": {
    "temperature": "frozen",
    "weight": {
      "$lt": 50
    }
  },
  "relations": {
    "stored-in": {
      "type": "cold-storage"
    }
  }
}
```

Don't build the full query language yet.

But design your APIs so we can get there.

---

# 5.5A.9.31 Semantic placement pipeline

We can now update our previous pipeline:

```text
Placement Request
       │
       ▼
Candidate Discovery
       │
       ▼
Anchor / Slot Discovery
       │
       ▼
Transform Generation
       │
       ▼
Physical Validation
       │
       ├── Collision
       ├── Containment
       ├── Clearance
       └── Capacity
       │
       ▼
Relationship Proposal
       │
       ▼
Semantic Validation
       │
       ├── Domain / Range
       ├── Compatibility
       ├── Cardinality
       ├── Properties
       ├── Dependencies
       └── World State
       │
       ▼
Scoring
       │
       ▼
Best Candidate
       │
       ▼
Commit
       │
       ├── Spatial State
       └── Relationship State
```

This is a very important milestone.

---

# 5.5A.9.32 Combine physical + semantic results

Don't have two unrelated validation systems.

Create a unified result:

```dart
class WorldValidationResult {
  final bool valid;

  final List<ConstraintEvaluation>
      physical;

  final List<ConstraintEvaluation>
      semantic;

  final double scoreImpact;

  const WorldValidationResult({
    required this.valid,
    required this.physical,
    required this.semantic,
    required this.scoreImpact,
  });
}
```

Then:

```text
valid =
    allHardPhysicalRulesPass
    &&
    allHardSemanticRulesPass
```

---

# 5.5A.9.33 Explainability becomes much better

Now your UI can say:

```text
❌ Placement rejected

Physical:
✓ No collision
✓ Fits container
✓ Clearance OK

Semantic:
✕ Target does not support "stored-in"
✕ Temperature mismatch

Suggested alternatives:
• Cold Storage A
• Cold Storage B
```

That's significantly more useful than:

```text
Cannot place.
```

---

# 5.5A.9.34 AI can now reason using structured failures

This is where your future intelligent layer gets interesting.

Instead of giving an LLM a raw 3D scene and asking:

> “Where should I put this?”

you can provide:

```json
{
  "object": "cargo-123",
  "goal": "store",
  "candidates": [
    {
      "target": "slot-04",
      "valid": false,
      "violations": [
        "temperature-mismatch"
      ]
    },
    {
      "target": "slot-07",
      "valid": true,
      "score": 0.87
    }
  ]
}
```

The AI doesn't have to perform geometry itself.

It reasons over **structured world state**.

That is a much stronger architecture.

---

# 5.5A.9.35 AI should propose intent, not coordinates

Eventually a user might say:

> “Put all frozen cargo into suitable storage near the loading dock.”

The AI translates this into something like:

```json
{
  "action": "place",
  "subjectQuery": {
    "type": "cargo",
    "temperature": "frozen"
  },
  "targetQuery": {
    "affordance": "storage",
    "temperature": "frozen"
  },
  "preferences": {
    "near": "loading-dock"
  }
}
```

Then your deterministic engine does:

```text
query
 ↓
candidate targets
 ↓
geometry
 ↓
constraints
 ↓
scoring
 ↓
placement
```

That separation is one of the most important architectural decisions for your platform.

---

# 5.5A.9.36 Don't build the AI layer yet

For now, implement the deterministic pieces.

Your immediate code should be:

```text
semantic/
├── relation.dart
├── relation_definition.dart
├── relationship_graph.dart
├── relationship_change_set.dart
├── relationship_query.dart
└── semantic_constraint.dart
```

Then:

```text
rules/
├── relation_rule.dart
├── property_constraint.dart
├── cardinality_constraint.dart
└── dependency_constraint.dart
```

Then connect them into:

```text
PlacementEngine
```

---

# 5.5A.9.37 Recommended first implementation

Don't try to implement the entire ontology system immediately.

Start with **three relations**:

```text
contains
stored-in
seated-at
```

Then test:

### Warehouse

```text
cargo
   ↓
stored-in
   ↓
rack-slot
```

### Restaurant

```text
person
   ↓
seated-at
   ↓
seat
```

### Building

```text
room
   ↓
contains
   ↓
table
```

If those three work using the same engine, your abstraction is probably heading in the right direction.

---

# 5.5A.9.38 The three-layer test

For every placement, test three levels:

### Level 1 — Geometry

```text
Does it physically fit?
```

### Level 2 — Spatial rules

```text
Does it satisfy clearance/capacity/etc?
```

### Level 3 — Semantics

```text
Does the resulting relationship make sense?
```

Example:

```text
Chair → table
```

### Geometry

```text
✓
```

### Spatial

```text
✓ clearance
✓ no collision
```

### Semantic

```text
✓ table has seat
✓ seat available
✓ chair compatible
```

→ **VALID**

---

# 5.5A.9.39 The architecture is now becoming domain-agnostic

We have:

```text
                    DOMAIN
                      │
                      ▼
             Entity Definitions
                      │
                      ▼
                Components
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
       Spatial                 Semantic
          │                       │
          ▼                       ▼
      Geometry                Relations
      Anchors                 Properties
      Slots                   State
      Zones                   Rules
          │                       │
          └───────────┬───────────┘
                      ▼
               World Validation
                      │
                      ▼
                Placement
                      │
                      ▼
                  World State
```

The domain-specific part is increasingly becoming:

```text
DATA + RULE CONFIGURATION
```

rather than:

```text
CUSTOM CODE
```

That's exactly where we want to go.

---

# 5.5A.9.40 What comes next

The next step should **not** immediately be AI.

We now have enough structure to tackle something more fundamental:

## **Step 5.5A.10 — World State & Transaction Engine**

Because once placement can modify:

```text
position
relations
occupancy
capacity
state
```

we need a reliable way to say:

> **Apply all these changes atomically, or apply none of them.**

For example, moving:

```text
Cargo A
```

from:

```text
Rack A / Slot 01
```

to:

```text
Rack B / Slot 04
```

must update **all** of these together:

```text
Cargo transform
       ↓
old slot occupancy
       ↓
new slot occupancy
       ↓
capacity usage
       ↓
stored-in relation
       ↓
spatial index
       ↓
simulation state
       ↓
event history
```

If one update succeeds and another fails, your digital twin becomes inconsistent.

So **5.5A.10 will introduce the transaction/state-change architecture** that makes all of this safe, undoable, replayable, and eventually suitable for simulation, multiplayer, and AI-generated world changes.
