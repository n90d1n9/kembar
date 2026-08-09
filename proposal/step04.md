Absolutely. **Step 4 is the rendering abstraction layer.**

The goal is to remove this dependency:

```text
ContainerSceneBuilder → ContainerTwin → renderer
```

and move toward:

```text
TwinState
   ↓
TwinSceneBuilder
   ↓
SceneGraph
   ↓
SceneRenderer
   ↓
Canvas / 3D / WebGL / GLB / future engines
```

This is a major architectural step because your current `ContainerSceneBuilder` already performs the job of translating domain data into renderable objects, while `PlacedContainer` is currently a container-specific render representation. 

We will **not delete those classes yet**.

---

# Step 4 — Generic Scene Graph

## 4.1 The target architecture

We're aiming for:

```text
                       TwinState
                           │
                           ▼
                  ┌─────────────────┐
                  │ TwinSceneBuilder│
                  └────────┬────────┘
                           │
                           ▼
                    ┌────────────┐
                    │ SceneGraph │
                    └─────┬──────┘
                          │
          ┌───────────────┼────────────────┐
          ▼               ▼                ▼
       Container         Crane            Robot
          │               │                │
          ▼               ▼                ▼
       SceneNode       SceneNode        SceneNode
          │
          ▼
   ┌───────────────┐
   │ SceneRenderer  │
   └───────┬───────┘
           │
     ┌─────┼──────────┐
     ▼     ▼          ▼
   Canvas  GLB       WebGL
```

The critical thing is:

> **The renderer should not know what a container is.**

---

# 4.2 First create `SceneNode`

Create:

```text
lib/domain/scene/scene_node.dart
```

```dart
import '../core/twin_core.dart';

class SceneNode {
  final String id;

  /// Generic twin entity type.
  ///
  /// Examples:
  /// container
  /// crane
  /// truck
  /// robot
  /// building
  final String entityType;

  final Vector3 position;

  final Vector3 rotation;

  final Vector3 scale;

  /// Optional visual/model identifier.
  ///
  /// Examples:
  /// container_20ft
  /// crane
  /// truck
  /// robot_arm
  final String? assetId;

  final bool visible;

  const SceneNode({
    required this.id,
    required this.entityType,
    required this.position,
    this.rotation = Vector3.zero,
    this.scale = Vector3.one,
    this.assetId,
    this.visible = true,
  });

  SceneNode copyWith({
    String? id,
    String? entityType,
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    String? assetId,
    bool? visible,
  }) {
    return SceneNode(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      assetId: assetId ?? this.assetId,
      visible: visible ?? this.visible,
    );
  }
}
```

This is the first important separation:

```text
TwinEntity
```

is the **digital twin**.

```text
SceneNode
```

is its **visual representation**.

They are not the same thing.

---

# 4.3 Why this distinction matters

Consider:

```text
container-001
```

Its twin state might say:

```text
status = loaded
weight = 21000kg
temperature = 24°C
location = slot-A-03
```

But its scene representation might say:

```text
asset = container_40ft
position = (12, 0, 7)
rotation = (0, 90, 0)
visible = true
```

And in another view:

```text
Dashboard
```

the same twin might have:

```text
chart
status badge
temperature graph
```

Therefore:

```text
ONE TWIN
   │
   ├── 3D SceneNode
   ├── 2D SceneNode
   ├── Dashboard representation
   ├── AR representation
   └── Simulation representation
```

This is essential for an agnostic platform.

---

# 4.4 Create `SceneGraph`

Create:

```text
lib/domain/scene/scene_graph.dart
```

```dart
import 'scene_node.dart';

class SceneGraph {
  final Map<String, SceneNode> nodes;

  const SceneGraph({
    this.nodes = const {},
  });

  SceneNode? node(String id) {
    return nodes[id];
  }

  List<SceneNode> get visibleNodes {
    return nodes.values
        .where((node) => node.visible)
        .toList(growable: false);
  }

  List<SceneNode> nodesOfType(String type) {
    return nodes.values
        .where((node) => node.entityType == type)
        .toList(growable: false);
  }

  SceneGraph copyWith({
    Map<String, SceneNode>? nodes,
  }) {
    return SceneGraph(
      nodes: nodes ?? this.nodes,
    );
  }
}
```

Now:

```text
TwinState
```

and:

```text
SceneGraph
```

are independent.

---

# 4.5 Create `SceneNodeBuilder`

We don't want one giant:

```text
TwinSceneBuilder
```

with 500 `if` statements.

Instead:

```text
TwinEntity
    ↓
SceneNodeBuilder
```

Create:

```text
lib/application/scene/scene_node_builder.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';

abstract class SceneNodeBuilder {
  bool supports(TwinEntity entity);

  SceneNode build(TwinEntity entity);
}
```

Now each domain can eventually have its own adapter.

---

# 4.6 Container implementation

Create:

```text
lib/application/scene/container_scene_node_builder.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

class ContainerSceneNodeBuilder
    implements SceneNodeBuilder {
  const ContainerSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'container';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial =
        entity.component('spatial') as SpatialComponent?;

    final properties =
        entity.component('properties') as PropertiesComponent?;

    final size = properties?.get('size');

    String? assetId;

    if (size is TwinEnum) {
      assetId = switch (size.value) {
        '20ft' => 'container_20ft',
        '40ft' => 'container_40ft',
        '45ft' => 'container_45ft',
        _ => 'container_default',
      };
    }

    return SceneNode(
      id: entity.id.value,
      entityType: entity.type,
      position: spatial?.position ?? Vector3.zero,
      assetId: assetId,
    );
  }
}
```

### Important

The exact enum values in your current `IsoContainerSize` should be checked against the actual source before finalizing the `switch`. Your uploaded material confirms the field exists but doesn't establish every enum member. 

So if your actual values are:

```text
twenty
forty
fortyFive
```

use those instead.

---

# 4.7 Create the generic `TwinSceneBuilder`

Now create:

```text
lib/application/scene/twin_scene_builder.dart
```

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_graph.dart';
import 'scene_node_builder.dart';

class TwinSceneBuilder {
  final List<SceneNodeBuilder> builders;

  const TwinSceneBuilder({
    required this.builders,
  });

  SceneGraph build(TwinState state) {
    final nodes = <String, dynamic>{};

    for (final entity in state.entities.values) {
      final builder = _findBuilder(entity);

      if (builder == null) {
        continue;
      }

      final node = builder.build(entity);

      nodes[node.id] = node;
    }

    return SceneGraph(
      nodes: Map.unmodifiable(nodes),
    );
  }

  SceneNodeBuilder? _findBuilder(
    TwinEntity entity,
  ) {
    for (final builder in builders) {
      if (builder.supports(entity)) {
        return builder;
      }
    }

    return null;
  }
}
```

You'll need:

```dart
import '../../domain/scene/scene_node.dart';
```

and ideally make the map strongly typed:

```dart
final nodes = <String, SceneNode>{};
```

So the final version should be:

```dart
import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_graph.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

class TwinSceneBuilder {
  final List<SceneNodeBuilder> builders;

  const TwinSceneBuilder({
    required this.builders,
  });

  SceneGraph build(TwinState state) {
    final nodes = <String, SceneNode>{};

    for (final entity in state.entities.values) {
      final builder = _findBuilder(entity);

      if (builder == null) {
        continue;
      }

      final node = builder.build(entity);

      nodes[node.id] = node;
    }

    return SceneGraph(
      nodes: Map.unmodifiable(nodes),
    );
  }

  SceneNodeBuilder? _findBuilder(
    TwinEntity entity,
  ) {
    for (final builder in builders) {
      if (builder.supports(entity)) {
        return builder;
      }
    }

    return null;
  }
}
```

---

# 4.8 Now test it with a fake TwinEntity

Before touching your existing renderer, test the new abstraction independently.

```dart
test(
  'builds a scene node from a generic container entity',
  () {
    final entity = TwinEntity(
      id: const TwinEntityId('container-001'),
      type: 'container',
      components: {
        'spatial': const SpatialComponent(
          position: Vector3(10, 0, 5),
        ),
        'properties': PropertiesComponent(
          properties: {
            'size': TwinEnum('40ft'),
          },
        ),
      },
    );

    final builder = TwinSceneBuilder(
      builders: const [
        ContainerSceneNodeBuilder(),
      ],
    );

    final graph = builder.build(
      TwinState(
        entities: {
          entity.id.value: entity,
        },
      ),
    );

    final node = graph.node('container-001');

    expect(node, isNotNull);
    expect(node!.position, const Vector3(10, 0, 5));
    expect(node.assetId, 'container_40ft');
  },
);
```

This test proves:

```text
TwinEntity
    ↓
TwinSceneBuilder
    ↓
SceneGraph
    ↓
SceneNode
```

without Flutter rendering anything.

That's exactly what we want.

---

# 4.9 Now address your existing `PlacedContainer`

Your existing architecture has:

```text
ContainerTwin
      ↓
ContainerSceneBuilder
      ↓
PlacedContainer
```

and the Canvas renderer consumes the placed containers. 

Don't delete `PlacedContainer`.

Instead, make it an **adapter**.

The migration becomes:

```text
OLD

ContainerTwin
    ↓
ContainerSceneBuilder
    ↓
PlacedContainer
    ↓
Canvas


NEW

TwinEntity
    ↓
TwinSceneBuilder
    ↓
SceneGraph
    ↓
SceneNode
    ↓
Renderer
```

For now, both can coexist.

---

# 4.10 Create a compatibility adapter

Create:

```text
lib/application/scene/placed_container_adapter.dart
```

Conceptually:

```dart
class PlacedContainerAdapter {
  const PlacedContainerAdapter();

  // Convert generic SceneNode
  // into existing PlacedContainer.
}
```

The exact implementation depends on the current constructor of `PlacedContainer`, which your uploaded source references but doesn't provide in full. 

Don't invent that constructor.

Instead inspect:

```text
lib/domain/scene/placed_container.dart
```

and map its actual fields.

The conceptual mapping should be:

```text
SceneNode.id
     ↓
PlacedContainer.id

SceneNode.position
     ↓
PlacedContainer.position

SceneNode.assetId
     ↓
PlacedContainer.asset/model
```

---

# 4.11 Why we're not replacing the renderer yet

Your current `SceneRenderAdapter` has implementations for:

```text
Canvas
3D
```

and `Lite3dSceneRenderAdapter` specifically bridges placed containers into the 3D scene. 

That is actually valuable architecture.

We want:

```text
                         SceneGraph
                            │
                            ▼
                    SceneRenderAdapter
                       /          \
                      /            \
                 Canvas             3D
```

instead of:

```text
ContainerSceneBuilder
       │
       ├── Canvas-specific
       │
       └── 3D-specific
```

So the renderer interface stays.

We're changing what goes **into** it.

---

# 4.12 Introduce generic render interface

Create:

```text
lib/application/rendering/scene_renderer.dart
```

```dart
import '../../domain/scene/scene_graph.dart';

abstract class SceneRenderer<T> {
  T render(SceneGraph scene);
}
```

This is deliberately generic.

For example:

```text
SceneGraph
    ↓
CanvasSceneRenderer
    ↓
Flutter widgets
```

or:

```text
SceneGraph
    ↓
ThreeDSceneRenderer
    ↓
3D scene
```

or later:

```text
SceneGraph
    ↓
WebGLSceneRenderer
```

---

# 4.13 But don't immediately rewrite `SceneRenderAdapter`

Keep your existing:

```text
SceneRenderAdapter
```

for now.

Instead create a bridge:

```text
SceneGraph
   ↓
SceneRenderAdapterBridge
   ↓
existing adapter
```

This lets us migrate incrementally.

---

# 4.14 Add a scene diff

This will become important for performance.

Suppose your twin has:

```text
10,000 entities
```

but one container moves.

We don't want:

```text
TwinState
   ↓
rebuild 10,000 SceneNodes
   ↓
rerender everything
```

Eventually we want:

```text
EntityUpdated(container-001)
           ↓
SceneNodeUpdated(container-001)
           ↓
renderer updates ONE object
```

Let's establish the data structure now.

Create:

```text
lib/domain/scene/scene_change.dart
```

```dart
import 'scene_node.dart';

sealed class SceneChange {
  const SceneChange();
}

class SceneNodeCreated extends SceneChange {
  final SceneNode node;

  const SceneNodeCreated(this.node);
}

class SceneNodeUpdated extends SceneChange {
  final SceneNode node;

  const SceneNodeUpdated(this.node);
}

class SceneNodeRemoved extends SceneChange {
  final String id;

  const SceneNodeRemoved(this.id);
}
```

Now we have:

```text
TwinEvent
    ↓
SceneChange
    ↓
Renderer
```

This is a very powerful future optimization.

---

# 4.15 Create `SceneGraphUpdater`

Create:

```text
lib/application/scene/scene_graph_updater.dart
```

```dart
import '../../domain/scene/scene_change.dart';
import '../../domain/scene/scene_graph.dart';

class SceneGraphUpdater {
  SceneGraph apply(
    SceneGraph graph,
    SceneChange change,
  ) {
    final nodes = Map<String, dynamic>.of(
      graph.nodes,
    );

    switch (change) {
      case SceneNodeCreated():
        nodes[change.node.id] = change.node;

      case SceneNodeUpdated():
        nodes[change.node.id] = change.node;

      case SceneNodeRemoved():
        nodes.remove(change.id);
    }

    return SceneGraph(
      nodes: Map.unmodifiable(nodes),
    );
  }
}
```

Again, make this strongly typed:

```dart
final nodes = Map<String, SceneNode>.of(
  graph.nodes,
);
```

with:

```dart
import '../../domain/scene/scene_node.dart';
```

---

# 4.16 Now the architecture becomes event-driven

We're starting to reach the architecture you ultimately want:

```text
                     External world
                           │
                           ▼
                      TwinEvent
                           │
                           ▼
                     TwinRuntime
                           │
                           ▼
                       TwinState
                           │
                           ▼
                    TwinSceneBuilder
                           │
                           ▼
                      SceneGraph
                           │
                     SceneChanges
                           │
                           ▼
                    SceneRenderAdapter
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
              Canvas                3D
```

Later:

```text
                           TwinState
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼
         SceneBuilder    SimulationEngine   AI Engine
             │                │                │
             ▼                ▼                ▼
        SceneGraph       SimulatedState    Predictions
```

That's the real platform direction.

---

# 4.17 Add a generic `SceneObject` concept later — not now

You may eventually want:

```text
SceneNode
├── transform
├── geometry
├── material
├── animation
├── interaction
├── visibility
├── metadata
```

But don't add all that yet.

For Step 4, keep:

```text
id
entityType
position
rotation
scale
assetId
visible
```

That's enough to establish the boundary.

---

# 4.18 Important: asset selection must eventually leave the container builder

Currently we're doing:

```dart
if (size == '40ft') {
  assetId = 'container_40ft';
}
```

That's okay as a temporary migration step.

But **this is not the final architecture**.

Eventually we want:

```text
TwinEntity
     │
     ▼
VisualizationComponent
     │
     ├── asset
     ├── material
     ├── color
     ├── animation
     └── representation
```

For example:

```text
VisualizationComponent
{
    assetId: "container_40ft",
    representation: "3d",
    material: "steel",
}
```

Then the generic scene builder doesn't need to understand:

```text
Container
```

at all.

We'll introduce this in a later step when we design the **schema/component system**.

---

# 4.19 What we should NOT do

Do not do this:

```dart
class TwinSceneBuilder {
  if (entity.type == 'container') ...
  if (entity.type == 'crane') ...
  if (entity.type == 'truck') ...
  if (entity.type == 'building') ...
}
```

That will eventually become:

```text
if container
if crane
if truck
if robot
if machine
if building
if room
if pipe
if sensor
if vehicle
...
```

and we've recreated the same domain coupling we're trying to remove.

Instead:

```text
TwinSceneBuilder
       │
       ├── ContainerSceneNodeBuilder
       ├── CraneSceneNodeBuilder
       ├── RobotSceneNodeBuilder
       ├── BuildingSceneNodeBuilder
       └── ...
```

This is an **extension mechanism**, not a giant conditional.

---

# 4.20 Add a builder registry

Create:

```text
lib/application/scene/scene_node_builder_registry.dart
```

```dart
import '../../domain/core/twin_core.dart';
import 'scene_node_builder.dart';

class SceneNodeBuilderRegistry {
  final List<SceneNodeBuilder> builders;

  const SceneNodeBuilderRegistry(
    this.builders,
  );

  SceneNodeBuilder? find(TwinEntity entity) {
    for (final builder in builders) {
      if (builder.supports(entity)) {
        return builder;
      }
    }

    return null;
  }
}
```

Then `TwinSceneBuilder` becomes:

```dart
class TwinSceneBuilder {
  final SceneNodeBuilderRegistry registry;

  const TwinSceneBuilder({
    required this.registry,
  });

  SceneGraph build(TwinState state) {
    final nodes = <String, SceneNode>{};

    for (final entity in state.entities.values) {
      final builder = registry.find(entity);

      if (builder == null) {
        continue;
      }

      final node = builder.build(entity);

      nodes[node.id] = node;
    }

    return SceneGraph(
      nodes: Map.unmodifiable(nodes),
    );
  }
}
```

Now registering a new domain looks like:

```dart
final registry = SceneNodeBuilderRegistry(
  const [
    ContainerSceneNodeBuilder(),
    CraneSceneNodeBuilder(),
    RobotSceneNodeBuilder(),
  ],
);
```

No changes to `TwinSceneBuilder`.

That is the extensibility we want.

---

# 4.21 Test multiple domains

This is a particularly important test for your platform vision.

Create fake entities:

```dart
final container = TwinEntity(
  id: const TwinEntityId('container-001'),
  type: 'container',
  components: {
    'spatial': const SpatialComponent(
      position: Vector3(1, 0, 1),
    ),
  },
);

final robot = TwinEntity(
  id: const TwinEntityId('robot-001'),
  type: 'robot',
  components: {
    'spatial': const SpatialComponent(
      position: Vector3(5, 0, 2),
    ),
  },
);
```

You don't need a robot builder yet.

The important behavior is:

```text
container
    ↓
SceneNode

robot
    ↓
no builder
    ↓
ignored
```

Then later:

```text
RobotSceneNodeBuilder
```

can be plugged in without modifying the core.

That is the test for **domain agnosticism**.

---

# 4.22 The current rendering migration

At the end of Step 4, don't remove:

```text
ContainerSceneBuilder
PlacedContainer
Lite3dSceneRenderAdapter
```

Instead:

```text
                     TwinState
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
      NEW SceneGraph          OLD Container path
             │                       │
             │                       ▼
             │                PlacedContainer
             │                       │
             └──────────┬────────────┘
                        ▼
                  existing renderer
```

Then in Step 5 we can start moving the renderer itself to:

```text
SceneGraph
```

without breaking the existing application.

---

# 4.23 Step 4 acceptance test

At the end, you should be able to run something equivalent to:

```dart
final runtime = TwinRuntime();

runtime.apply(
  EntityCreated(
    TwinEntity(
      id: const TwinEntityId('container-001'),
      type: 'container',
      components: {
        'spatial': const SpatialComponent(
          position: Vector3(10, 0, 5),
        ),
        'properties': PropertiesComponent(
          properties: {
            'size': TwinEnum('40ft'),
          },
        ),
      },
    ),
  ),
);

final sceneBuilder = TwinSceneBuilder(
  registry: SceneNodeBuilderRegistry(
    const [
      ContainerSceneNodeBuilder(),
    ],
  ),
);

final graph = sceneBuilder.build(
  runtime.state,
);

final node = graph.node('container-001');

expect(node, isNotNull);
expect(node!.position, const Vector3(10, 0, 5));
```

So:

```text
Live Twin
   ↓
TwinState
   ↓
SceneGraph
   ↓
SceneNode
```

is now working independently of Flutter's actual rendering implementation.

---

# Step 4 acceptance checklist

Before moving to Step 5:

```text
[ ] SceneNode exists

[ ] SceneGraph exists

[ ] SceneNodeBuilder exists

[ ] ContainerSceneNodeBuilder exists

[ ] SceneNodeBuilderRegistry exists

[ ] TwinSceneBuilder exists

[ ] TwinState → SceneGraph works

[ ] ContainerTwin is no longer required
    by the generic scene builder

[ ] SceneNode contains no ContainerTwin

[ ] SceneGraph contains no ContainerTwin

[ ] Scene renderer abstraction exists

[ ] SceneChange exists

[ ] SceneGraphUpdater exists

[ ] existing Canvas still works

[ ] existing 3D/GLB still works

[ ] flutter analyze passes

[ ] flutter test passes
```

---

## What Step 4 has accomplished

We've now separated **three fundamentally different things**:

```text
┌────────────────────────────────────┐
│ DOMAIN / DIGITAL TWIN              │
│                                    │
│ TwinEntity                          │
│ TwinState                           │
│ TwinRelationship                    │
└────────────────┬───────────────────┘
                 │
                 ▼
┌────────────────────────────────────┐
│ REPRESENTATION                     │
│                                    │
│ SceneNode                           │
│ SceneGraph                          │
└────────────────┬───────────────────┘
                 │
                 ▼
┌────────────────────────────────────┐
│ RENDERING                          │
│                                    │
│ Canvas                             │
│ 3D / GLB                           │
│ WebGL                              │
└────────────────────────────────────┘
```

That separation is one of the most important foundations for making the platform **domain-agnostic**.

### Step 5 should be the interaction layer

Once this is stable, we'll make the scene **interactive**, rather than merely visual:

```text
pointer / mouse / touch / controller
                 ↓
            Interaction
                 ↓
            SceneNode
                 ↓
             TwinEntity
                 ↓
          TwinCommand
                 ↓
            TwinRuntime
```

That is where things like **select, inspect, move, rotate, drag, command, focus, camera control, and eventually game-like interaction** start becoming generic platform capabilities rather than container-specific UI behavior.
