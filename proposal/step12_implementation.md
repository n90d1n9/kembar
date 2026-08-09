# Step 12 Implementation: Semantic Spatial Relations & Anchors

## Overview

Step 12 implements **Semantic Spatial Relations & Anchors**, transforming the placement system from asking "Where can this object physically go?" to "**What does it mean for this object to be related to another object?**"

This enables the same engine to work across all domains (warehouse, restaurant, port, parking, factory, etc.) without domain-specific logic in the spatial engine.

## Architecture Change

### Before (Position-First)
```
Placement Request → Candidate Generation → Constraints → Scoring → Placement
```

### After (Relation-First)
```
Placement Request → Semantic Relation → Relation-Specific Candidate Generation → Constraints → Scoring → Placement + Relationship Creation
```

## Files Created/Updated

### Core Domain Files

1. **`lib/domain/spatial/spatial_relation.dart`** (Enhanced)
   - Added `SpatialRelationDefinition` class with properties:
     - `directional`: Whether relation has direction (above/below)
     - `symmetric`: Whether relation is symmetric (adjacentTo)
     - `inverse`: Inverse relation type (above ↔ below)
     - `requiresContainment`: For inside/contains relations
     - `requiresSupport`: For on/stackedOn relations
     - `allowsOverlap`: For attached/overlapping relations
   - Added `SpatialRelationRegistry` with definitions for all relation types
   - Relations organized by category:
     - Containment: inside, contains
     - Support: on, supports, stackedOn
     - Proximity: adjacentTo, near, far
     - Positional: leftOf, rightOf, above, below, inFrontOf, behind
     - Connection: attachedTo, connectedTo, alignedWith
     - Collision: overlaps, intersects

2. **`lib/domain/spatial/relations/spatial_relationship.dart`** (New)
   - `SpatialRelationship` class representing actual relationships between entities
   - Properties: subjectId, relation, objectId, confidence, metadata, state
   - Lifecycle states: proposed, active, invalid, broken
   - Automatic inverse relationship generation
   - `copyWith()` for immutable updates

3. **`lib/domain/spatial/placement_request.dart`** (Enhanced)
   - Added `relation` field (required) - semantic relation type
   - Added `preferredAnchorId` for anchor-based placement
   - Added `createRelationship` flag for automatic relationship creation

### Application Layer Files

4. **`lib/application/spatial/spatial_world.dart`** (Enhanced)
   - Added `relationships` list to store spatial relationships
   - Added `withRelationship()`, `withoutRelationship()` methods
   - Added `updateRelationships()` for batch updates
   - Maintains separation: components + relationships

5. **`lib/application/spatial/relations/spatial_relation_query.dart`** (New)
   - Query API for searching relationships
   - Methods:
     - `whereSubject()`: Find relationships where entity is subject
     - `whereObject()`: Find relationships where entity is object
     - `find()`: Flexible filtering by any criteria
     - `findByRelationAndObject()`: e.g., "what's ON shelf-01?"
     - `getSubjectsRelatedTo()`: Get entities with specific relation
     - `hasRelationship()`: Check if relationship exists
     - `activeRelationships`, `brokenRelationships` getters
     - `groupByRelationType()`: Group by relation type
     - `involvingEntities()`: Get relationships involving specific entities

6. **`lib/application/spatial/relations/relation_constraint_resolver.dart`** (New)
   - Resolves appropriate constraints based on relation type
   - Examples:
     - ON/STACKED_ON → SurfaceFit + Support + Collision
     - INSIDE/CONTAINS → Collision (+ future ContainmentConstraint)
     - ADJACENT_TO/NEAR → Collision + Clearance
     - ATTACHED_TO/CONNECTED_TO → Collision (+ future AttachmentConstraint)
     - ABOVE/BELOW → Collision + small Clearance
     - LEFT_OF/RIGHT_OF/IN_FRONT_OF/BEHIND → Collision + medium Clearance
     - OVERLAPS/INTERSECTS → No collision constraint (allows overlap)

## Key Architectural Achievements

### 1. Two-Layer Spatial Model

```
GEOMETRIC STATE                    SEMANTIC STATE
position / rotation                ON
bounds                             INSIDE
mesh                               ADJACENT_TO
collision                          ATTACHED_TO
transform                          STACKED_ON
        │                              │
        └──────────┬───────────────────┘
                   ▼
           Spatial Reasoner
```

- **Geometry**: "Where is it?"
- **Semantics**: "Why is it there / how is it related?"

### 2. Relationship Lifecycle

Relationships have states:
- `proposed`: Created but not validated
- `active`: Valid and current
- `invalid`: Temporarily invalid (e.g., during movement)
- `broken`: Permanently broken (triggers events/simulation response)

### 3. Inverse Relationships

The system automatically handles inverse relations:
- `above` ↔ `below`
- `inside` ↔ `contains`
- `leftOf` ↔ `rightOf`
- `inFrontOf` ↔ `behind`
- `on` ↔ `supports`

### 4. Relation-Aware Constraint Resolution

Instead of applying all constraints to all placements, the system now selects constraints based on the semantic relation:

```dart
final resolver = RelationConstraintResolver();
final constraints = resolver.resolve(SpatialRelationType.on);
// Returns: [SurfaceFitConstraint, SupportConstraint, CollisionConstraint]
```

### 5. Query Capabilities

The query API enables powerful semantic queries:

```dart
final query = SpatialRelationQuery(world);

// What is on this shelf?
query.findByRelationAndObject(SpatialRelationType.on, 'shelf-01');

// What is inside this room?
query.getSubjectsRelatedTo(SpatialRelationType.inside, 'room-01');

// Is this chair adjacent to any table?
query.hasRelationship(
  subjectId: 'chair-22',
  relation: SpatialRelationType.adjacentTo,
  objectId: 'table-04',
);
```

## Usage Examples

### Warehouse Scenario

```dart
// Cargo placed ON rack slot
final cargoOnRack = SpatialRelationship(
  subjectId: 'cargo-001',
  relation: SpatialRelationType.on,
  objectId: 'rack-slot-04',
  metadata: {'anchorId': 'slot-04'},
);

// Query: What's on this rack?
final items = query.findByRelationAndObject(
  SpatialRelationType.on,
  'rack-03',
);

// Lifecycle: Rack moves, cargo relationship becomes invalid
world.updateRelationships(
  (r) => r.objectId == 'rack-03',
  (r) => r.copyWith(state: SpatialRelationState.invalid),
);
```

### Restaurant Scenario

```dart
// Chair ADJACENT_TO table
final chairAtTable = SpatialRelationship(
  subjectId: 'chair-22',
  relation: SpatialRelationType.adjacentTo,
  objectId: 'table-04',
  metadata: {'anchorId': 'seat-02'},
);

// Query: What chairs are at this table?
final chairs = query.getSubjectsRelatedTo(
  SpatialRelationType.adjacentTo,
  'table-04',
);
```

### Factory Scenario

```dart
// Sensor ATTACHED_TO machine
final sensorOnMachine = SpatialRelationship(
  subjectId: 'sensor-07',
  relation: SpatialRelationType.attachedTo,
  objectId: 'machine-12',
  metadata: {'anchorId': 'mount-B'},
);

// Query: What sensors are attached to this machine?
final sensors = query.getSubjectsRelatedTo(
  SpatialRelationType.attachedTo,
  'machine-12',
);
```

## Integration with Placement Pipeline

The updated placement pipeline:

```
PlacementRequest (with relation)
       ↓
Relation Definition Lookup
       ↓
Relation-Specific Candidate Generator
       ↓
Relation-Specific Constraints (from resolver)
       ↓
Generic Constraints
       ↓
Scoring
       ↓
Best Placement
       ↓
┌──────┴──────┐
▼             ▼
Update    Create Relationship
Geometry  (if createRelationship=true)
       │
       ▼
   Twin State
```

## Future Extensions

This implementation sets the foundation for:

1. **Relation Validators**: Continuous validation of relationship invariants
   - `OnRelationValidator`: Checks cargo bottom ≈ shelf top
   - `InsideRelationValidator`: Checks bounds containment
   - `AttachedRelationValidator`: Checks transform hierarchy

2. **Relationship Events**: Trigger simulation/workflow on relationship changes
   - `RelationshipCreated`
   - `RelationshipBroken`
   - `RelationshipRestored`

3. **Transform Hierarchies**: Parent-child relationships for coordinated movement

4. **Ontology Layer**: Higher-level semantic reasoning on top of relationships

5. **AI Integration**: AI proposes placements, spatial engine validates semantically

## Testing Recommendations

Test scenarios should cover:

1. Creating relationships of different types
2. Querying relationships by subject/object/relation
3. Inverse relationship generation
4. Relationship lifecycle transitions
5. Constraint resolution for different relation types
6. Multi-domain compatibility (warehouse, restaurant, port, etc.)

## Conclusion

Step 12 successfully implements semantic spatial relations, providing a domain-agnostic foundation for intelligent digital twin scenarios. The system now understands not just WHERE objects are, but WHY they are there and HOW they relate to other objects—enabling sophisticated simulation, prediction, and AI-assisted generation across any domain.
