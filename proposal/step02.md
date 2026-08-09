Great. **Step 2 is the bridge layer**: we keep `ContainerTwin` exactly as your existing domain model, but teach the generic Twin Core how to represent it.

Your current `ContainerTwin` already contains the important domain data—ID, size, yard slot, status, weight, owner, and timestamp—so we should **map it**, not replace it. 

# Step 2 — ContainerTwin → Generic TwinEntity

The target after this step is:

```text
Existing domain
────────────────────────────

ContainerTwin
    │
    │ mapper
    ▼
Generic platform
────────────────────────────

TwinEntity
 ├── identity
 ├── type = container
 ├── properties
 └── spatial
```

And importantly:

```text
ContainerTwin
```

still remains usable by your current Canvas/GLB pipeline.

---

# 2.1 Create `SpatialComponent`

This is the first new generic capability.

Create:

```text
lib/domain/core/spatial_component.dart
```

```dart
import 'twin_component.dart';

class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(
    this.x,
    this.y,
    this.z,
  );

  static const zero = Vector3(0, 0, 0);
  static const one = Vector3(1, 1, 1);

  Vector3 copyWith({
    double? x,
    double? y,
    double? z,
  }) {
    return Vector3(
      x ?? this.x,
      y ?? this.y,
      z ?? this.z,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Vector3 &&
        other.x == x &&
        other.y == y &&
        other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);
}
```

Then:

```dart
class SpatialComponent implements TwinComponent {
  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  const SpatialComponent({
    required this.position,
    this.rotation = Vector3.zero,
    this.scale = Vector3.one,
  });

  @override
  String get type => 'spatial';

  SpatialComponent copyWith({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
  }) {
    return SpatialComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }
}
```

Now export it from:

```text
lib/domain/core/twin_core.dart
```

Add:

```dart
export 'spatial_component.dart';
```

---

# 2.2 Important distinction: domain position vs world position

Your existing project has:

```text
YardSlot
   ↓
SlotPositionMapper
   ↓
Position3D
```

That is a good separation. Your `SlotPositionMapper` already translates logical yard positions into scene coordinates. 

**Do not put that logic into `ContainerTwin`.**

Instead:

```text
ContainerTwin
    │
    └── YardSlot
          │
          ▼
     SlotPositionMapper
          │
          ▼
      world Vector3
          │
          ▼
   SpatialComponent
```

This will become extremely important when we later support:

```text
GPS
BIM
GIS
factory coordinates
robot coordinates
warehouse coordinates
game coordinates
```

all through the same spatial abstraction.

---

# 2.3 Create `ContainerTwinMapper`

Create:

```text
lib/application/mappers/container_twin_mapper.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';

class ContainerTwinMapper {
  const ContainerTwinMapper();

  TwinEntity toEntity(
    ContainerTwin container, {
    Vector3? worldPosition,
  }) {
    return TwinEntity(
      id: TwinEntityId(container.id.value),
      type: 'container',
      components: {
        'properties': _properties(container),

        if (worldPosition != null)
          'spatial': SpatialComponent(
            position: worldPosition,
          ),
      },
    );
  }

  PropertiesComponent _properties(
    ContainerTwin container,
  ) {
    return PropertiesComponent(
      properties: {
        'size': TwinEnum(container.size.name),
        'status': TwinEnum(container.status.name),
        'weightKg': TwinNumber(container.weightKg),
        'lastUpdated': TwinDateTime(container.lastUpdated),

        if (container.ownerLine != null)
          'ownerLine': TwinString(container.ownerLine!),
      },
    );
  }
}
```

This is the first major architectural boundary.

The mapper knows:

```text
ContainerTwin
```

but the generic runtime doesn't.

---

# 2.4 What about `YardSlot`?

This is where we need to be careful.

Your `ContainerTwin` contains:

```text
YardSlot slot
```

but `YardSlot` is a **domain concept**, not inherently a world coordinate.

So don't do this:

```dart
TwinString(container.slot.toString())
```

and call it spatial information.

Instead, use the existing `SlotPositionMapper`.

Your current code already has this concept:

```text
SlotPositionMapper
```

and the Canvas builder uses it to derive positions. 

So create a generic adapter around it.

---

# 2.5 Create `ContainerSpatialMapper`

Create:

```text
lib/application/mappers/container_spatial_mapper.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';
import '../../domain/services/slot_position_mapper.dart';

class ContainerSpatialMapper {
  final SlotPositionMapper slotPositionMapper;

  const ContainerSpatialMapper({
    required this.slotPositionMapper,
  });

  Vector3 map(ContainerTwin container) {
    final position = slotPositionMapper.map(
      container.slot,
    );

    return Vector3(
      position.x,
      position.y,
      position.z,
    );
  }
}
```

### But check your actual `SlotPositionMapper` API

Your existing source shows the mapper concept, but if its actual method isn't:

```dart
map(...)
```

use the method already present in your project.

The important architecture is:

```text
ContainerSpatialMapper
       ↓
existing SlotPositionMapper
       ↓
Position3D
       ↓
Vector3
```

**Don't rewrite `SlotPositionMapper` just for this step.**

---

# 2.6 Combine the two mappers

Now improve `ContainerTwinMapper`.

Instead of passing:

```dart
Vector3? worldPosition
```

we can make the mapper itself resolve spatial state.

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';
import 'container_spatial_mapper.dart';

class ContainerTwinMapper {
  final ContainerSpatialMapper spatialMapper;

  const ContainerTwinMapper({
    required this.spatialMapper,
  });

  TwinEntity toEntity(ContainerTwin container) {
    final position = spatialMapper.map(container);

    return TwinEntity(
      id: TwinEntityId(container.id.value),
      type: 'container',
      components: {
        'properties': _properties(container),

        'spatial': SpatialComponent(
          position: position,
        ),
      },
    );
  }

  PropertiesComponent _properties(
    ContainerTwin container,
  ) {
    return PropertiesComponent(
      properties: {
        'size': TwinEnum(container.size.name),
        'status': TwinEnum(container.status.name),
        'weightKg': TwinNumber(container.weightKg),
        'lastUpdated': TwinDateTime(container.lastUpdated),

        if (container.ownerLine != null)
          'ownerLine': TwinString(container.ownerLine!),
      },
    );
  }
}
```

Now:

```text
ContainerTwin
     │
     ├── domain properties
     │
     └── YardSlot
            │
            ▼
     ContainerSpatialMapper
            │
            ▼
      SpatialComponent
```

---

# 2.7 Add a relationship for the slot

Here's an important design decision.

We eventually don't want the generic platform to treat:

```text
slot
```

as just a string.

We want:

```text
container-001
       │
       │ locatedIn
       ▼
slot-A-03-02
```

So let's create a generic entity for the slot.

For now, make a mapper:

```text
lib/application/mappers/yard_slot_mapper.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/entities/yard_slot.dart';

class YardSlotMapper {
  const YardSlotMapper();

  TwinEntity toEntity(YardSlot slot) {
    return TwinEntity(
      id: TwinEntityId(_id(slot)),
      type: 'yard_slot',
      components: {
        'properties': PropertiesComponent(
          properties: {
            // Map the actual YardSlot fields here.
          },
        ),
      },
    );
  }

  String _id(YardSlot slot) {
    return slot.toString();
  }
}
```

### Stop here before copying this blindly

Your uploaded source tells us `YardSlot` exists, but we need its actual fields to design this mapper correctly. 

So for now, **do not implement `YardSlotMapper` unless you inspect the actual `yard_slot.dart` file**.

We can already represent the container without it.

---

# 2.8 Add `TwinRelationship` to `TwinState`

Our current `TwinRuntime` handles entities but not relationships.

Let's fix that now because the container's location is conceptually important.

Modify `TwinRuntime`:

```dart
import '../../domain/core/twin_relationship.dart';
```

Add:

```dart
void addRelationship(TwinRelationship relationship) {
  final relationships = List<TwinRelationship>.of(
    _state.relationships,
  );

  if (!relationships.contains(relationship)) {
    relationships.add(relationship);
  }

  _state = _state.copyWith(
    relationships: relationships,
  );
}
```

And:

```dart
void removeRelationship(TwinRelationship relationship) {
  final relationships = List<TwinRelationship>.of(
    _state.relationships,
  );

  relationships.remove(relationship);

  _state = _state.copyWith(
    relationships: relationships,
  );
}
```

This isn't the final event-driven relationship system.

We're just giving the runtime enough capability for Step 2.

---

# 2.9 Better: introduce relationship events

Actually, since we're building this properly, I'd prefer not to mutate relationships directly.

Add to `twin_event.dart`:

```dart
class RelationshipCreated extends TwinEvent {
  final TwinRelationship relationship;

  const RelationshipCreated(this.relationship);
}

class RelationshipRemoved extends TwinEvent {
  final TwinRelationship relationship;

  const RelationshipRemoved(this.relationship);
}
```

Then update:

```dart
void apply(TwinEvent event) {
  switch (event) {
    case EntityCreated():
      _applyCreated(event);

    case EntityUpdated():
      _applyUpdated(event);

    case EntityRemoved():
      _applyRemoved(event);

    case RelationshipCreated():
      _applyRelationshipCreated(event);

    case RelationshipRemoved():
      _applyRelationshipRemoved(event);
  }

  _eventController.add(event);
}
```

Add:

```dart
void _applyRelationshipCreated(
  RelationshipCreated event,
) {
  final relationships = List<TwinRelationship>.of(
    _state.relationships,
  );

  if (!relationships.contains(event.relationship)) {
    relationships.add(event.relationship);
  }

  _state = _state.copyWith(
    relationships: relationships,
  );
}
```

And:

```dart
void _applyRelationshipRemoved(
  RelationshipRemoved event,
) {
  final relationships = List<TwinRelationship>.of(
    _state.relationships,
  );

  relationships.remove(event.relationship);

  _state = _state.copyWith(
    relationships: relationships,
  );
}
```

Now **everything that changes the twin becomes an event**.

That's the direction we want.

---

# 2.10 Test the mapper

Create:

```text
test/application/container_twin_mapper_test.dart
```

The exact imports and fixture construction depend on your current `ContainerTwin` constructors.

The important test structure is:

```dart
test('maps container into generic TwinEntity', () {
  final mapper = ContainerTwinMapper(
    spatialMapper: fakeSpatialMapper,
  );

  final entity = mapper.toEntity(container);

  expect(entity.id.value, container.id.value);
  expect(entity.type, 'container');

  expect(
    entity.hasComponent('properties'),
    isTrue,
  );

  expect(
    entity.hasComponent('spatial'),
    isTrue,
  );
});
```

---

# 2.11 Test the generic representation

More importantly, inspect what the mapper produces.

For a container:

```text
TwinEntity
│
├── id
│     DEMO0000001
│
├── type
│     container
│
└── components
      │
      ├── properties
      │    ├── size
      │    ├── status
      │    ├── weightKg
      │    ├── ownerLine
      │    └── lastUpdated
      │
      └── spatial
           └── position
```

This is the first time your existing container has become a **platform entity**.

---

# 2.12 Now connect it to `TwinRuntime`

Create a small integration test:

```dart
test('container can enter generic runtime', () {
  final runtime = TwinRuntime();

  final entity = mapper.toEntity(container);

  runtime.apply(
    EntityCreated(entity),
  );

  final result = runtime.state.entity(
    container.id.value,
  );

  expect(result, isNotNull);
  expect(result!.type, 'container');
});
```

Now we've proven:

```text
ContainerTwin
     ↓
ContainerTwinMapper
     ↓
TwinEntity
     ↓
EntityCreated
     ↓
TwinRuntime
     ↓
TwinState
```

---

# 2.13 Don't connect Riverpod yet

Your current provider architecture is:

```text
ContainerRepository
        ↓
Stream<List<ContainerTwin>>
        ↓
containersProvider
        ↓
placedContainersProvider
        ↓
Canvas / GLB
```



Do **not** replace that in Step 2.

Instead we now have two parallel pipelines:

```text
CURRENT
──────────────────────────

Repository
   ↓
ContainerTwin
   ↓
existing providers
   ↓
existing renderer
```

and:

```text
NEW
──────────────────────────

ContainerTwin
   ↓
ContainerTwinMapper
   ↓
TwinEntity
   ↓
TwinRuntime
   ↓
TwinState
```

This is exactly what we want during migration.

---

# 2.14 One thing we should change in `TwinProperty`

There is a subtle problem with our current:

```dart
TwinEnum(container.status.name)
```

and:

```dart
TwinEnum(container.size.name)
```

We're using strings without knowing whether they're valid.

That's okay **for Step 2**.

But don't build business rules directly around those strings.

Later the schema will define:

```yaml
status:
  type: enum
  values:
    - available
    - reserved
    - loaded
    - discharged
```

So eventually:

```text
TwinEnum
```

will carry validated schema information.

Not yet.

---

# 2.15 Add metadata to `TwinEntity`

I recommend one small improvement before we finish Step 2.

Change:

```dart
class TwinEntity {
  final TwinEntityId id;
  final String type;
  final Map<String, TwinComponent> components;
```

to:

```dart
class TwinEntity {
  final TwinEntityId id;

  final String type;

  final Map<String, TwinComponent> components;

  final DateTime? updatedAt;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
    this.updatedAt,
  });

  TwinComponent? component(String type) {
    return components[type];
  }

  bool hasComponent(String type) {
    return components.containsKey(type);
  }

  TwinEntity copyWith({
    TwinEntityId? id,
    String? type,
    Map<String, TwinComponent>? components,
    DateTime? updatedAt,
  }) {
    return TwinEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      components: components ?? this.components,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

Why?

Because the platform will eventually need to distinguish:

```text
entity updated at
telemetry timestamp
simulation timestamp
prediction timestamp
```

For now we only need the entity-level timestamp.

---

# 2.16 Add source metadata

I'd also add:

```dart
final String? sourceId;
```

So:

```dart
class TwinEntity {
  final TwinEntityId id;
  final String type;
  final Map<String, TwinComponent> components;
  final DateTime? updatedAt;
  final String? sourceId;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
    this.updatedAt,
    this.sourceId,
  });
}
```

Then the container mapper can eventually say:

```dart
TwinEntity(
  id: TwinEntityId(container.id.value),
  type: 'container',
  sourceId: 'terminal-websocket',
  updatedAt: container.lastUpdated,
  ...
)
```

This will become very useful when you eventually have:

```text
Live IoT
   +
Database
   +
Simulation
   +
AI generated state
```

feeding the same twin.

---

# 2.17 The resulting architecture

After Step 2, we have:

```text
                    ┌────────────────────┐
                    │   ContainerTwin    │
                    │ existing domain    │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │ ContainerTwinMapper│
                    └─────────┬──────────┘
                              │
             ┌────────────────┴────────────────┐
             ▼                                 ▼
      PropertiesComponent              SpatialComponent
             │                                 │
             └────────────────┬────────────────┘
                              ▼
                       ┌────────────┐
                       │ TwinEntity │
                       └─────┬──────┘
                             │
                       EntityCreated
                             │
                             ▼
                     ┌─────────────┐
                     │ TwinRuntime │
                     └──────┬──────┘
                            ▼
                       ┌─────────┐
                       │TwinState│
                       └─────────┘
```

And the existing system remains:

```text
ContainerTwin
      │
      ├──────────────► ContainerSceneBuilder
      │                         │
      │                         ▼
      │                  PlacedContainer
      │                         │
      │                         ▼
      │                    GLB / Canvas
      │
      └──────────────► ContainerTwinMapper
                                │
                                ▼
                            TwinEntity
```

**This is exactly the migration pattern we want.**

---

# Step 2 acceptance checklist

Before moving to Step 3, verify:

```text
[ ] flutter analyze passes

[ ] flutter test passes

[ ] SpatialComponent exists

[ ] ContainerTwinMapper exists

[ ] ContainerTwin can become TwinEntity

[ ] TwinEntity has properties component

[ ] TwinEntity has spatial component

[ ] TwinRuntime accepts mapped ContainerTwin

[ ] existing Canvas still works

[ ] existing GLB still works

[ ] no ContainerTwin code was deleted

[ ] no renderer code was rewritten
```

The key result is that **we have not broken your current project while establishing the generic representation**.

### Step 3 will be the more substantial one

Next we'll take the existing:

```text
List<ContainerTwin>
```

flow and introduce a **generic `TwinRepository` + adapter + runtime provider**, so your real WebSocket/backend data can start flowing into `TwinState`.

That is where the new architecture starts becoming **live**, rather than just a set of new classes.
