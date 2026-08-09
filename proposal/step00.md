Absolutely. Let's make this **implementation-level**, not just architecture.

Based on your current code, I would **not rewrite the project**. Your existing `ContainerTwin`, `ContainerSceneBuilder`, `PlacedContainer`, `SceneRenderAdapter`, Canvas renderer, GLB renderer, repositories, and Riverpod providers give us a good migration path.

The first objective is:

> **Refactor the existing terminal twin into a generic Twin Kernel while keeping the current UI working.**

We should do this in small, compilable steps.

---

# Step 0 — Freeze the current working version

Before changing architecture:

```bash
git add .
git commit -m "baseline: terminal digital twin before generic kernel"
```

Then create a branch:

```bash
git checkout -b refactor/twin-kernel
```

We want every step to leave you with a runnable application.

---

# Step 1 — Create the generic Twin Core

Your current:

```text
domain/
├── entities/
│   ├── container_twin.dart
│   ├── container_status.dart
│   └── yard_block_layout.dart
└── value_objects/
```

is still domain-oriented.

Don't delete it.

Create a new generic layer beside it:

```text
domain/
├── core/
│   ├── twin_entity.dart
│   ├── twin_entity_id.dart
│   ├── twin_component.dart
│   ├── twin_property.dart
│   ├── twin_relationship.dart
│   ├── twin_event.dart
│   └── twin_command.dart
│
├── entities/
│   ├── container_twin.dart
│   └── ...
```

This gives us a migration path.

---

# Step 2 — `TwinEntityId`

Create:

```text
domain/core/twin_entity_id.dart
```

```dart
class TwinEntityId {
  final String value;

  const TwinEntityId(this.value);

  @override
  bool operator ==(Object other) =>
      other is TwinEntityId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
```

This looks trivial, but it becomes important because **every object in every future domain uses the same identity system**.

---

# Step 3 — Create `TwinProperty`

Create:

```text
domain/core/twin_property.dart
```

Start simple:

```dart
sealed class TwinProperty {
  const TwinProperty();
}

class TwinString extends TwinProperty {
  final String value;

  const TwinString(this.value);
}

class TwinNumber extends TwinProperty {
  final double value;

  const TwinNumber(this.value);
}

class TwinBoolean extends TwinProperty {
  final bool value;

  const TwinBoolean(this.value);
}

class TwinEnum extends TwinProperty {
  final String value;

  const TwinEnum(this.value);
}

class TwinDateTime extends TwinProperty {
  final DateTime value;

  const TwinDateTime(this.value);
}
```

Later we add:

```text
TwinVector3
TwinGeoPoint
TwinReference
TwinArray
TwinObject
TwinUnitValue
```

Don't build those yet.

---

# Step 4 — Create `TwinComponent`

Now create:

```text
domain/core/twin_component.dart
```

```dart
abstract class TwinComponent {
  const TwinComponent();

  String get type;
}
```

Then:

```dart
class PropertiesComponent implements TwinComponent {
  final Map<String, TwinProperty> properties;

  const PropertiesComponent(this.properties);

  @override
  String get type => 'properties';
}
```

We'll eventually have:

```text
TwinComponent
├── PropertiesComponent
├── SpatialComponent
├── TelemetryComponent
├── VisualizationComponent
├── BehaviorComponent
├── SimulationComponent
└── PredictionComponent
```

But **don't create all of them yet**.

---

# Step 5 — Create generic `TwinEntity`

Now:

```text
domain/core/twin_entity.dart
```

```dart
import 'twin_component.dart';
import 'twin_entity_id.dart';

class TwinEntity {
  final TwinEntityId id;
  final String type;

  final Map<String, TwinComponent> components;

  const TwinEntity({
    required this.id,
    required this.type,
    this.components = const {},
  });

  TwinComponent? component(String type) {
    return components[type];
  }
}
```

Now we have:

```text
TwinEntity
   │
   ├── id
   ├── type
   └── components
```

This is the first big architectural transition.

---

# Step 6 — Add relationships

Create:

```text
domain/core/twin_relationship.dart
```

```dart
import 'twin_entity_id.dart';

class TwinRelationship {
  final TwinEntityId from;
  final String type;
  final TwinEntityId to;

  const TwinRelationship({
    required this.from,
    required this.type,
    required this.to,
  });
}
```

Now the platform can express:

```text
container-001
     │
     └── locatedIn
             ↓
          block-A
```

or:

```text
robot-12
    │
    └── controlledBy
            ↓
        controller-4
```

or:

```text
machine-7
    │
    └── partOf
            ↓
        production-line-2
```

This is what allows different domains to share the same graph model.

---

# Step 7 — Create `TwinState`

This becomes the runtime's current world.

Create:

```text
domain/core/twin_state.dart
```

```dart
import 'twin_entity.dart';
import 'twin_relationship.dart';

class TwinState {
  final Map<String, TwinEntity> entities;
  final List<TwinRelationship> relationships;

  const TwinState({
    this.entities = const {},
    this.relationships = const [],
  });

  TwinEntity? entity(String id) {
    return entities[id];
  }

  TwinState copyWith({
    Map<String, TwinEntity>? entities,
    List<TwinRelationship>? relationships,
  }) {
    return TwinState(
      entities: entities ?? this.entities,
      relationships: relationships ?? this.relationships,
    );
  }
}
```

This is important.

Eventually:

```text
TwinState
```

becomes the canonical state of the entire digital twin.

---

# Step 8 — Add events

Create:

```text
domain/core/twin_event.dart
```

Start with:

```dart
sealed class TwinEvent {
  const TwinEvent();
}

class EntityCreated extends TwinEvent {
  final TwinEntity entity;

  const EntityCreated(this.entity);
}

class EntityRemoved extends TwinEvent {
  final TwinEntityId id;

  const EntityRemoved(this.id);
}

class EntityUpdated extends TwinEvent {
  final TwinEntity entity;

  const EntityUpdated(this.entity);
}
```

You'll need:

```dart
import 'twin_entity.dart';
import 'twin_entity_id.dart';
```

Now your architecture can eventually become:

```text
Repository
    ↓
TwinEvent
    ↓
TwinRuntime
    ↓
TwinState
```

rather than your current:

```text
Repository
    ↓
List<ContainerTwin>
    ↓
UI
```

Your current WebSocket implementation actually already has the conceptual equivalent of snapshot/update/remove messages. 

So we're not inventing something disconnected from your project—we're formalizing what you already have.

---

# Step 9 — Add commands

Create:

```text
domain/core/twin_command.dart
```

```dart
import 'twin_entity_id.dart';

class TwinCommand {
  final TwinEntityId entityId;
  final String action;
  final Map<String, Object?> parameters;

  const TwinCommand({
    required this.entityId,
    required this.action,
    this.parameters = const {},
  });
}
```

Example:

```dart
TwinCommand(
  entityId: TwinEntityId('DEMO0000001'),
  action: 'move',
  parameters: {
    'bay': 5,
    'row': 2,
    'tier': 1,
  },
);
```

Later:

```text
move
start
stop
open
close
load
unload
reroute
charge
repair
```

All domains can use the same command mechanism.

---

# Step 10 — Build `TwinRuntime`

This is where things become interesting.

Create:

```text
application/runtime/twin_runtime.dart
```

```dart
import 'dart:async';

import '../../domain/core/twin_entity.dart';
import '../../domain/core/twin_event.dart';
import '../../domain/core/twin_state.dart';

class TwinRuntime {
  TwinState _state;

  final StreamController<TwinEvent> _events =
      StreamController<TwinEvent>.broadcast();

  TwinRuntime({
    TwinState initialState = const TwinState(),
  }) : _state = initialState;

  TwinState get state => _state;

  Stream<TwinEvent> get events => _events.stream;

  void apply(TwinEvent event) {
    switch (event) {
      case EntityCreated():
        _create(event);
      case EntityRemoved():
        _remove(event);
      case EntityUpdated():
        _update(event);
    }

    _events.add(event);
  }

  void _create(EntityCreated event) {
    final entities = Map<String, TwinEntity>.of(_state.entities);

    entities[event.entity.id.value] = event.entity;

    _state = _state.copyWith(
      entities: entities,
    );
  }

  void _update(EntityUpdated event) {
    final entities = Map<String, TwinEntity>.of(_state.entities);

    entities[event.entity.id.value] = event.entity;

    _state = _state.copyWith(
      entities: entities,
    );
  }

  void _remove(EntityRemoved event) {
    final entities = Map<String, TwinEntity>.of(_state.entities);

    entities.remove(event.id.value);

    _state = _state.copyWith(
      entities: entities,
    );
  }

  Future<void> dispose() async {
    await _events.close();
  }
}
```

This is your first real **Twin Kernel**.

---

# Step 11 — Test the runtime before touching Flutter

Create:

```text
test/domain/twin_runtime_test.dart
```

Test:

```dart
test('creates an entity', () {
  final runtime = TwinRuntime();

  final entity = TwinEntity(
    id: TwinEntityId('machine-1'),
    type: 'machine',
  );

  runtime.apply(EntityCreated(entity));

  expect(
    runtime.state.entity('machine-1'),
    isNotNull,
  );
});
```

Then:

```dart
test('updates an entity', () {
  final runtime = TwinRuntime();

  final first = TwinEntity(
    id: TwinEntityId('machine-1'),
    type: 'machine',
  );

  runtime.apply(EntityCreated(first));

  final updated = TwinEntity(
    id: TwinEntityId('machine-1'),
    type: 'robot',
  );

  runtime.apply(EntityUpdated(updated));

  expect(
    runtime.state.entity('machine-1')!.type,
    'robot',
  );
});
```

Don't proceed until these work.

---

# Step 12 — Now adapt `ContainerTwin`

This is the critical migration step.

**Do not delete `ContainerTwin`.**

Instead make it implement/adapt to the generic entity model.

Currently you have:

```dart
class ContainerTwin {
  final ContainerId id;
  final IsoContainerSize size;
  final YardSlot slot;
  final ContainerStatus status;
  final double weightKg;
  final String? ownerLine;
  final DateTime lastUpdated;
}
```

This is actually a perfectly reasonable domain object. 

Add:

```dart
TwinEntity toEntity() {
  return TwinEntity(
    id: TwinEntityId(id.value),
    type: 'container',
    components: {
      'properties': PropertiesComponent({
        'weightKg': TwinNumber(weightKg),
        'status': TwinEnum(status.name),
        if (ownerLine != null)
          'ownerLine': TwinString(ownerLine!),
        'lastUpdated': TwinDateTime(lastUpdated),
      }),
    },
  );
}
```

But we're missing spatial information.

That's deliberate.

We'll solve spatial state properly next.

---

# Step 13 — Create generic `SpatialComponent`

Create:

```text
domain/core/spatial_component.dart
```

```dart
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(
    this.x,
    this.y,
    this.z,
  );
}

class SpatialComponent implements TwinComponent {
  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  const SpatialComponent({
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
  });

  @override
  String get type => 'spatial';
}
```

Now the generic runtime doesn't care whether the entity came from:

```text
YardSlot
```

or:

```text
GPS
```

or:

```text
BIM
```

or:

```text
robot coordinates
```

It simply knows:

```text
SpatialComponent
```

---

# Step 14 — Adapt `ContainerTwin` spatially

Now:

```dart
TwinEntity toEntity({
  required Position3D worldPosition,
}) {
  return TwinEntity(
    id: TwinEntityId(id.value),
    type: 'container',
    components: {
      'properties': PropertiesComponent({
        'weightKg': TwinNumber(weightKg),
        'status': TwinEnum(status.name),
        if (ownerLine != null)
          'ownerLine': TwinString(ownerLine!),
        'lastUpdated': TwinDateTime(lastUpdated),
      }),
      'spatial': SpatialComponent(
        position: Vector3(
          worldPosition.x,
          worldPosition.y,
          worldPosition.z,
        ),
      ),
    },
  );
}
```

Now the generic twin understands the object spatially without knowing what a `YardSlot` is.

---

# Step 15 — Don't put coordinate conversion inside `TwinEntity`

This is extremely important.

Your existing:

```text
YardSlot
   ↓
SlotPositionMapper
   ↓
Position3D
```

is actually a good design. 

Keep it.

Eventually we want:

```text
Domain spatial representation
        ↓
SpatialMapper
        ↓
World coordinates
        ↓
Scene
```

So:

```text
Container
    └── YardSlot

Robot
    └── RobotPose

Building
    └── BIMTransform

Vehicle
    └── GPSPosition
```

can all resolve to:

```text
WorldTransform
```

without the generic runtime knowing anything about the source representation.

---

# Step 16 — Create generic `SceneNode`

Now we attack your `PlacedContainer`.

Currently:

```dart
PlacedContainer
```

contains container-specific properties such as:

```text
lengthM
widthM
heightM
status
```



Instead create:

```text
application/scene/scene_node.dart
```

```dart
import '../../domain/core/spatial_component.dart';

class SceneNode {
  final String id;
  final String entityId;

  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  final String? modelId;

  const SceneNode({
    required this.id,
    required this.entityId,
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
    this.modelId,
  });
}
```

Now the renderer sees:

```text
SceneNode
```

instead of:

```text
PlacedContainer
```

---

# Step 17 — Keep `PlacedContainer` temporarily

Don't immediately remove it.

Instead:

```dart
SceneNode toSceneNode(PlacedContainer container) {
  return SceneNode(
    id: container.id,
    entityId: container.id,
    position: Vector3(
      container.baseCenter.x,
      container.baseCenter.y,
      container.baseCenter.z,
    ),
    rotation: Vector3(
      0,
      container.rotationYDeg,
      0,
    ),
    scale: Vector3(
      container.lengthM,
      container.heightM,
      container.widthM,
    ),
  );
}
```

This gives us:

```text
ContainerTwin
       ↓
ContainerSceneBuilder
       ↓
PlacedContainer
       ↓
SceneNode
       ↓
Renderer
```

Then later:

```text
TwinEntity
       ↓
GenericSceneBuilder
       ↓
SceneNode
```

---

# Step 18 — Generalize `ContainerSceneBuilder`

Your current builder is already a good separation:

```text
Twin state
    ↓
Scene
```

The code explicitly describes itself this way. 

Eventually rename the concept to:

```text
TwinSceneBuilder
```

Create:

```dart
abstract class SceneBuilder {
  List<SceneNode> build(TwinState state);
}
```

But **don't implement the generic version yet**.

First get the generic kernel working.

---

# Step 19 — Change rendering abstraction

Your current:

```dart
abstract class SceneRenderAdapter {
  Uint8List buildGlb(
    List<PlacedContainer> containers, {
    YardBlockLayout? layout,
  });
}
```

is still terminal-specific because it explicitly accepts:

```text
PlacedContainer
YardBlockLayout
GLB
```



Change it eventually to:

```dart
abstract class SceneRenderer {
  Future<void> render(Scene scene);
}
```

But I would **not make this change yet**.

First create:

```text
SceneNode
Scene
```

and adapt the existing GLB implementation around them.

---

# Step 20 — Create `Scene`

```text
application/scene/scene.dart
```

```dart
import 'scene_node.dart';

class Scene {
  final List<SceneNode> nodes;

  const Scene({
    this.nodes = const [],
  });
}
```

Then:

```dart
class TwinSceneBuilder {
  Scene build(List<SceneNode> nodes) {
    return Scene(nodes: nodes);
  }
}
```

Eventually:

```text
TwinState
    ↓
TwinSceneBuilder
    ↓
Scene
    ↓
SceneRenderer
```

---

# Step 21 — Then change GLB adapter

Instead of:

```text
PlacedContainer → GLB
```

we eventually want:

```text
Scene → GLB
```

Conceptually:

```dart
abstract class SceneRenderer {
  Future<RenderArtifact> render(Scene scene);
}
```

and:

```dart
class GlbSceneRenderer implements SceneRenderer {
  @override
  Future<RenderArtifact> render(Scene scene) async {
    // convert generic SceneNode objects
    // to lite_3d_core Node3D objects
  }
}
```

Your existing `Lite3dSceneRenderAdapter` is the implementation to refactor. It currently loops through `PlacedContainer` and creates `Node3D`, which makes it the perfect place to insert the new generic scene boundary. 

---

# Step 22 — Change the state flow

Right now:

```text
Stream<List<ContainerTwin>>
          ↓
placedContainersProvider
          ↓
Canvas
```

and:

```text
Stream<List<ContainerTwin>>
          ↓
debouncedContainersProvider
          ↓
GLB
```

Your providers explicitly do this today. 

The target is:

```text
Repository
    ↓
TwinEvent
    ↓
TwinRuntime
    ↓
TwinState
    ↓
TwinSceneBuilder
    ↓
Scene
    ↓
Renderer
```

This is the most important long-term change.

---

# Step 23 — Introduce `TwinRepository` generically

Current:

```dart
abstract class ContainerRepository {
  Stream<List<ContainerTwin>> watchContainers(...);
  Future<List<ContainerTwin>> fetchContainers(...);
}
```

Eventually:

```dart
abstract class TwinRepository {
  Stream<TwinEvent> watch();

  Future<List<TwinEntity>> fetchEntities({
    String? type,
  });
}
```

Then:

```text
WebSocket
REST
MQTT
Database
IoT
Simulator
```

can all become event sources.

---

# Step 24 — Keep the existing repository as an adapter

Don't rewrite it yet.

Create:

```dart
class ContainerRepositoryAdapter implements TwinRepository {
  final ContainerRepository source;

  ContainerRepositoryAdapter(this.source);

  @override
  Stream<TwinEvent> watch() async* {
    await for (final containers in source.watchContainers(blockId: 'A')) {
      for (final container in containers) {
        // convert to EntityUpdated / EntityCreated
      }
    }
  }
}
```

This is a temporary bridge.

It lets us prove the generic runtime without breaking the existing backend implementation.

Your current WebSocket repository already maintains a cache and handles snapshot/update/remove semantics, so that conversion is quite natural. 

---

# Step 25 — Build the first generic demo

At this point we should create:

```text
TwinRuntime
      │
      ├── Container
      ├── Machine
      └── Robot
```

Even if only the container renders.

For example:

```dart
final runtime = TwinRuntime();

runtime.apply(
  EntityCreated(
    TwinEntity(
      id: TwinEntityId('container-001'),
      type: 'container',
    ),
  ),
);

runtime.apply(
  EntityCreated(
    TwinEntity(
      id: TwinEntityId('robot-001'),
      type: 'robot',
    ),
  ),
);
```

The runtime now doesn't care what these objects represent.

That's our first proof of **domain agnosticism**.

---

# Step 26 — Then create the Definition layer

Only after the above works do we introduce:

```text
TwinDefinition
```

Structure:

```text
domain/schema/

TwinDefinition
 ├── EntityDefinition
 ├── PropertyDefinition
 ├── RelationshipDefinition
 ├── VisualizationDefinition
 └── BehaviorDefinition
```

For example:

```dart
class TwinDefinition {
  final String id;
  final String version;

  final Map<String, EntityDefinition> entities;

  const TwinDefinition({
    required this.id,
    required this.version,
    required this.entities,
  });
}
```

Then:

```dart
class EntityDefinition {
  final String type;
  final Map<String, PropertyDefinition> properties;

  const EntityDefinition({
    required this.type,
    this.properties = const {},
  });
}
```

---

# Step 27 — JSON/YAML becomes the next major milestone

Eventually this:

```dart
TwinDefinition(...)
```

should be loadable from:

```yaml
id: warehouse

entities:

  forklift:
    properties:
      battery:
        type: number
        unit: percent

      state:
        type: enum
        values:
          - idle
          - moving
          - charging
          - fault
```

Then:

```text
YAML / JSON
      ↓
TwinDefinitionParser
      ↓
TwinDefinition
      ↓
TwinRuntime
```

Now we're genuinely approaching a platform.

---

# Step 28 — Then add behaviors

After definitions:

```text
BehaviorDefinition
```

Example:

```yaml
behaviors:

  - name: low_battery
    when:
      property: battery
      operator: "<"
      value: 20

    action:
      command: goCharge
```

Runtime:

```text
state changed
     ↓
RuleEngine
     ↓
condition matched
     ↓
TwinCommand
     ↓
entity changes
     ↓
TwinEvent
```

Now entities can behave.

---

# Step 29 — Then simulation

Only after commands + behaviors work.

Create:

```text
simulation/

TwinClock
SimulationScenario
SimulationEvent
SimulationResult
TwinSimulator
```

Start with:

```dart
abstract class TwinSimulator {
  Future<SimulationResult> run(
    TwinState initialState,
    SimulationScenario scenario,
  );
}
```

The first simulator should be **discrete event**, not physics.

For your project it can simulate:

```text
10:00 crane operating
10:05 truck arrives
10:07 container loaded
10:09 truck departs
10:15 crane failure
10:16 queue grows
...
```

This will give you a huge amount of capability before touching complicated physics.

---

# Step 30 — Then AI generation

Only after the schema is stable.

The architecture becomes:

```text
User prompt
    ↓
LLM
    ↓
TwinDefinition JSON
    ↓
Schema validation
    ↓
Runtime
```

Example:

> "Generate a warehouse digital twin."

AI outputs:

```json
{
  "id": "warehouse",
  "entities": {
    "forklift": {},
    "rack": {},
    "pallet": {},
    "dock": {}
  }
}
```

The platform compiles it.

---

# The actual migration tree

So I recommend we implement in this exact order:

```text
PHASE 1
────────────────────────

01 twin_entity_id.dart
02 twin_property.dart
03 twin_component.dart
04 twin_entity.dart
05 twin_relationship.dart
06 twin_state.dart
07 twin_event.dart
08 twin_command.dart
09 twin_runtime.dart
10 runtime tests


PHASE 2
────────────────────────

11 SpatialComponent
12 SceneNode
13 Scene
14 generic scene tests

15 ContainerTwin → TwinEntity adapter
16 PlacedContainer → SceneNode adapter

17 Generic SceneBuilder interface


PHASE 3
────────────────────────

18 TwinRepository
19 ContainerRepositoryAdapter
20 TwinEvent → Runtime
21 Riverpod TwinRuntimeProvider

22 replace List<ContainerTwin> flow
    with TwinState flow


PHASE 4
────────────────────────

23 SceneRenderer
24 SceneRenderAdapter refactor
25 GLB renderer → Scene
26 Canvas renderer → Scene

27 remove renderer dependency on ContainerTwin


PHASE 5
────────────────────────

28 TwinDefinition
29 EntityDefinition
30 PropertyDefinition
31 RelationshipDefinition
32 JSON/YAML parser
33 validation


PHASE 6
────────────────────────

34 CommandEngine
35 RuleEngine
36 BehaviorDefinition


PHASE 7
────────────────────────

37 TwinClock
38 SimulationScenario
39 DiscreteEventSimulator
40 SimulationTimeline


PHASE 8
────────────────────────

41 Telemetry
42 TimeSeries
43 PredictionModel
44 PredictionResult


PHASE 9
────────────────────────

45 AI TwinGenerator
46 AI ScenarioGenerator
47 AI Prediction/Explanation
48 AI Optimization


PHASE 10
────────────────────────

49 Domain packs
50 terminal pack
51 warehouse pack
52 factory pack
53 building pack
```

---

# But don't implement all of that now

**Our immediate coding sprint should only be Steps 1–10.**

Specifically create these **9 new files**:

```text
lib/domain/core/
├── twin_entity_id.dart
├── twin_property.dart
├── twin_component.dart
├── twin_entity.dart
├── twin_relationship.dart
├── twin_state.dart
├── twin_event.dart
└── twin_command.dart

lib/application/runtime/
└── twin_runtime.dart
```

Then:

```text
test/
└── twin_runtime_test.dart
```

At that point your existing application should still run exactly as before.

---

## One architectural rule I want us to enforce from this point

Whenever we add a new capability, ask:

> **"Does this belong to the generic twin runtime, the domain pack, the scene system, the renderer, or the presentation layer?"**

For example:

| Feature                        | Where it belongs      |
| ------------------------------ | --------------------- |
| Container status `laden`       | Terminal domain       |
| Robot battery                  | Factory domain        |
| Entity ID                      | Twin Core             |
| Position                       | Twin Core             |
| `locatedIn`                    | Twin Core             |
| "red when damaged"             | Visualization         |
| GLB                            | Renderer              |
| Canvas                         | Renderer              |
| Camera orbit                   | Presentation/scene    |
| "if battery <20%"              | Behavior              |
| Simulation clock               | Simulation            |
| Failure prediction             | Intelligence          |
| AI-generated entity definition | Intelligence + Schema |
| WebSocket                      | Infrastructure        |
| MQTT                           | Infrastructure        |

That separation is what will ultimately let you say:

> **"Build me a digital twin for a factory."**

without the factory having to become another hard-coded version of `ContainerTwin`.

Your current architecture already has good boundaries around scene building, coordinate mapping, repository access, and rendering; we're going to **move those boundaries one level upward**, rather than throw them away.

**Next, I would implement the actual Step 1 code file-by-file, including the exact Dart files, imports, tests, and the first changes to your existing `ContainerTwin` and Riverpod providers.**
