Yes. **Step 5 is the interaction layer.**

Up to now we've built:

```text
Step 1  Twin Core
Step 2  ContainerTwin → TwinEntity
Step 3  Repository → TwinRuntime
Step 4  TwinState → SceneGraph
```

Now we make the platform **interactive**:

```text
Pointer / Touch / Mouse / Controller
              ↓
       InteractionSystem
              ↓
          SceneNode
              ↓
         TwinEntity
              ↓
        TwinCommand
              ↓
         TwinRuntime
```

The important design decision is:

> **Interaction should operate on generic `TwinEntity` / `SceneNode`, not `ContainerTwin`.**

Your existing UI already has scene/render abstractions, so this is the right next seam rather than putting interaction logic into the current container widgets.  

---

# Step 5 — Generic Interaction System

## 5.1 What we want to support

Eventually the same interaction system should support:

```text
select
hover
focus
inspect
move
rotate
drag
drop
activate
deactivate
start
stop
open
close
connect
disconnect
delete
```

For different domains:

```text
container → move / inspect
robot     → move / start / stop
crane     → lift / rotate
machine   → start / stop
building  → enter / inspect
vehicle   → drive / route
```

The interaction engine shouldn't know any of those domain-specific meanings.

Instead:

```text
user action
    ↓
generic command
    ↓
domain/runtime decides whether valid
```

---

# 5.2 Create interaction primitives

Create:

```text
lib/domain/interaction/interaction_target.dart
```

```dart
class InteractionTarget {
  final String entityId;
  final String? nodeId;

  const InteractionTarget({
    required this.entityId,
    this.nodeId,
  });
}
```

This represents:

> "The user is interacting with this thing."

Not:

> "The user clicked a container."

---

# 5.3 Create interaction types

Create:

```text
lib/domain/interaction/interaction_type.dart
```

```dart
enum InteractionType {
  hover,
  select,
  inspect,
  focus,
  activate,
  deactivate,
  move,
  rotate,
  dragStart,
  drag,
  dragEnd,
  command,
}
```

Keep this list small for now.

Later we'll probably split:

```text
input events
interaction intents
commands
```

but this is sufficient for Step 5.

---

# 5.4 Create `InteractionEvent`

Create:

```text
lib/domain/interaction/interaction_event.dart
```

```dart
import 'interaction_target.dart';
import 'interaction_type.dart';

class InteractionEvent {
  final InteractionType type;

  final InteractionTarget target;

  final Map<String, Object?> data;

  const InteractionEvent({
    required this.type,
    required this.target,
    this.data = const {},
  });
}
```

Examples:

```dart
InteractionEvent(
  type: InteractionType.select,
  target: InteractionTarget(
    entityId: 'container-001',
  ),
);
```

Or:

```dart
InteractionEvent(
  type: InteractionType.move,
  target: InteractionTarget(
    entityId: 'robot-001',
  ),
  data: {
    'x': 10.0,
    'y': 0.0,
    'z': 5.0,
  },
);
```

---

# 5.5 Interaction is NOT command execution

This distinction is extremely important.

Suppose the user clicks:

```text
START MACHINE
```

The UI generates:

```text
InteractionEvent
```

not directly:

```text
start machine
```

The interaction system converts that into:

```text
TwinCommand
```

and the runtime decides what to do.

So:

```text
UI
 ↓
InteractionEvent
 ↓
InteractionSystem
 ↓
TwinCommand
 ↓
CommandHandler
 ↓
TwinState
```

This will eventually allow:

```text
UI
AI
simulation
automation
script
API
```

to all issue commands through the same mechanism.

---

# 5.6 Create `InteractionResult`

Create:

```text
lib/domain/interaction/interaction_result.dart
```

```dart
enum InteractionResultStatus {
  accepted,
  rejected,
  ignored,
}

class InteractionResult {
  final InteractionResultStatus status;

  final String? reason;

  const InteractionResult({
    required this.status,
    this.reason,
  });

  const InteractionResult.accepted()
      : status = InteractionResultStatus.accepted,
        reason = null;

  const InteractionResult.rejected(String reason)
      : status = InteractionResultStatus.rejected,
        reason = reason;

  const InteractionResult.ignored()
      : status = InteractionResultStatus.ignored,
        reason = null;
}
```

Why?

Because later the user might try:

```text
move crane
```

while:

```text
crane.locked == true
```

The system should be able to say:

```text
rejected
reason = crane is locked
```

rather than silently failing.

---

# 5.7 Create `InteractionHandler`

Create:

```text
lib/application/interaction/interaction_handler.dart
```

```dart
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';

abstract class InteractionHandler {
  bool supports(InteractionEvent event);

  Future<InteractionResult> handle(
    InteractionEvent event,
  );
}
```

Now we can plug in different behaviors.

---

# 5.8 Selection handler

Selection is a platform-level behavior, not domain behavior.

Create:

```text
lib/application/interaction/select_interaction_handler.dart
```

```dart
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';
import '../../domain/interaction/interaction_type.dart';
import 'interaction_handler.dart';

class SelectInteractionHandler
    implements InteractionHandler {
  const SelectInteractionHandler();

  @override
  bool supports(InteractionEvent event) {
    return event.type == InteractionType.select;
  }

  @override
  Future<InteractionResult> handle(
    InteractionEvent event,
  ) async {
    return const InteractionResult.accepted();
  }
}
```

At first this doesn't do anything.

That's intentional.

The selection state will come next.

---

# 5.9 Create `InteractionSystem`

Create:

```text
lib/application/interaction/interaction_system.dart
```

```dart
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_result.dart';
import 'interaction_handler.dart';

class InteractionSystem {
  final List<InteractionHandler> handlers;

  const InteractionSystem({
    required this.handlers,
  });

  Future<InteractionResult> handle(
    InteractionEvent event,
  ) async {
    for (final handler in handlers) {
      if (handler.supports(event)) {
        return handler.handle(event);
      }
    }

    return const InteractionResult.ignored();
  }
}
```

Now we have a generic interaction pipeline:

```text
InteractionEvent
       ↓
InteractionSystem
       ↓
matching handler
       ↓
InteractionResult
```

---

# 5.10 Add selection state

We need somewhere to remember:

```text
which entity is selected?
which entity is hovered?
which entity has focus?
```

Create:

```text
lib/domain/interaction/interaction_state.dart
```

```dart
class InteractionState {
  final String? hoveredEntityId;

  final String? selectedEntityId;

  final String? focusedEntityId;

  const InteractionState({
    this.hoveredEntityId,
    this.selectedEntityId,
    this.focusedEntityId,
  });

  InteractionState copyWith({
    String? hoveredEntityId,
    String? selectedEntityId,
    String? focusedEntityId,
    bool clearHovered = false,
    bool clearSelected = false,
    bool clearFocused = false,
  }) {
    return InteractionState(
      hoveredEntityId:
          clearHovered
              ? null
              : hoveredEntityId ?? this.hoveredEntityId,

      selectedEntityId:
          clearSelected
              ? null
              : selectedEntityId ?? this.selectedEntityId,

      focusedEntityId:
          clearFocused
              ? null
              : focusedEntityId ?? this.focusedEntityId,
    );
  }
}
```

---

# 5.11 Create `InteractionRuntime`

Now create:

```text
lib/application/interaction/interaction_runtime.dart
```

```dart
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_state.dart';

class InteractionRuntime {
  InteractionState _state =
      const InteractionState();

  InteractionState get state => _state;

  void apply(InteractionEvent event) {
    switch (event.type) {
      case InteractionType.hover:
        _state = _state.copyWith(
          hoveredEntityId: event.target.entityId,
        );

      case InteractionType.select:
        _state = _state.copyWith(
          selectedEntityId: event.target.entityId,
        );

      case InteractionType.focus:
        _state = _state.copyWith(
          focusedEntityId: event.target.entityId,
        );

      default:
        break;
    }
  }
}
```

You'll need:

```dart
import '../../domain/interaction/interaction_type.dart';
```

Now:

```text
InteractionRuntime
       │
       ▼
InteractionState
       │
       ├── hovered
       ├── selected
       └── focused
```

---

# 5.12 Selection should not modify the Twin

This is another important architectural boundary.

If the user selects:

```text
container-001
```

we do **not** change:

```text
TwinState
```

because selection is not part of the physical digital twin.

Instead:

```text
TwinState
    │
    └── container-001

InteractionState
    │
    └── selected = container-001
```

This separation becomes important when multiple users/viewports exist.

For example:

```text
User A → selected container-001
User B → selected crane-002
```

while:

```text
TwinState
```

remains identical.

---

# 5.13 Connect SceneNode to interaction

Our current `SceneNode` has:

```dart
id
entityType
position
rotation
scale
assetId
visible
```

Add:

```dart
final bool interactive;
```

So:

```dart
class SceneNode {
  final String id;
  final String entityType;

  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  final String? assetId;

  final bool visible;

  final bool interactive;

  const SceneNode({
    required this.id,
    required this.entityType,
    required this.position,
    this.rotation = Vector3.zero,
    this.scale = Vector3.one,
    this.assetId,
    this.visible = true,
    this.interactive = true,
  });
}
```

Now the renderer knows:

```text
this object can receive interaction
```

but it still doesn't know what the object actually is.

---

# 5.14 Add interaction metadata

There's a second improvement I recommend.

Eventually different scene representations might expose different actions.

So add:

```dart
final Set<InteractionType> supportedInteractions;
```

Then:

```dart
class SceneNode {
  ...
  
  final Set<InteractionType> supportedInteractions;

  const SceneNode({
    ...
    this.supportedInteractions = const {
      InteractionType.select,
      InteractionType.inspect,
    },
  });
}
```

For a container:

```text
select
inspect
move
```

For a building:

```text
select
inspect
focus
```

For a robot:

```text
select
inspect
move
activate
deactivate
```

But the scene node doesn't execute those operations.

It simply advertises what the visual representation supports.

---

# 5.15 Update `ContainerSceneNodeBuilder`

Your current builder can now specify:

```dart
return SceneNode(
  id: entity.id.value,
  entityType: entity.type,
  position: spatial?.position ?? Vector3.zero,
  assetId: assetId,
  interactive: true,
  supportedInteractions: const {
    InteractionType.select,
    InteractionType.inspect,
    InteractionType.move,
  },
);
```

Add:

```dart
import '../../domain/interaction/interaction_type.dart';
```

Now a renderer can ask:

```text
Can this object be interacted with?
```

without knowing it is a container.

---

# 5.16 Create a generic hit result

The rendering engine will eventually tell us:

> "The user clicked this scene object."

Create:

```text
lib/domain/interaction/hit_test_result.dart
```

```dart
class HitTestResult {
  final String nodeId;

  final String? entityId;

  final double distance;

  const HitTestResult({
    required this.nodeId,
    this.entityId,
    this.distance = 0,
  });
}
```

For example:

```text
mouse click
    ↓
3D engine raycast
    ↓
nodeId = container-001
```

The interaction layer then resolves:

```text
nodeId
  ↓
entityId
```

---

# 5.17 Create `InteractionTargetResolver`

Create:

```text
lib/application/interaction/interaction_target_resolver.dart
```

```dart
import '../../domain/interaction/interaction_target.dart';
import '../../domain/scene/scene_graph.dart';

class InteractionTargetResolver {
  final SceneGraph scene;

  const InteractionTargetResolver({
    required this.scene,
  });

  InteractionTarget? resolve(String nodeId) {
    final node = scene.node(nodeId);

    if (node == null) {
      return null;
    }

    return InteractionTarget(
      entityId: node.id,
      nodeId: node.id,
    );
  }
}
```

This is deliberately simple because currently:

```text
SceneNode.id == TwinEntity.id
```

Later we can support:

```text
SceneNode.id = visual-object-123
TwinEntity.id = crane-001
```

which becomes useful when one entity has multiple visual objects.

---

# 5.18 Now connect input

Eventually your Canvas/3D adapter will produce something like:

```dart
final target = resolver.resolve(hit.nodeId);

if (target != null) {
  await interactionSystem.handle(
    InteractionEvent(
      type: InteractionType.select,
      target: target,
    ),
  );
}
```

So the actual UI layer becomes:

```text
Pointer
   ↓
Renderer hit-test
   ↓
nodeId
   ↓
InteractionTargetResolver
   ↓
InteractionEvent
   ↓
InteractionSystem
```

This is the correct boundary.

---

# 5.19 Don't put Flutter gestures in the domain

Avoid this:

```dart
class ContainerTwin {
  void onTap() {}
  void onDrag() {}
}
```

And avoid:

```dart
ContainerSceneBuilder(
  onTap: ...
)
```

as the long-term architecture.

Instead:

```text
Flutter / Canvas / 3D
       ↓
platform input
       ↓
generic interaction
       ↓
TwinCommand
```

That allows:

```text
mouse
touch
VR controller
gamepad
keyboard
AI agent
automation
REST API
```

to eventually use the same command system.

---

# 5.20 Convert interaction into `TwinCommand`

We already created:

```dart
class TwinCommand {
  final TwinEntityId entityId;
  final String action;
  final Map<String, Object?> parameters;
}
```

Now create:

```text
lib/application/interaction/interaction_command_mapper.dart
```

```dart
import '../../domain/core/twin_command.dart';
import '../../domain/interaction/interaction_event.dart';
import '../../domain/interaction/interaction_type.dart';

class InteractionCommandMapper {
  const InteractionCommandMapper();

  TwinCommand? map(
    InteractionEvent event,
  ) {
    switch (event.type) {
      case InteractionType.move:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'move',
          parameters: event.data,
        );

      case InteractionType.activate:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'activate',
        );

      case InteractionType.deactivate:
        return TwinCommand(
          entityId: TwinEntityId(
            event.target.entityId,
          ),
          action: 'deactivate',
        );

      default:
        return null;
    }
  }
}
```

This gives us:

```text
InteractionEvent
        ↓
InteractionCommandMapper
        ↓
TwinCommand
```

---

# 5.21 Selection does NOT become a TwinCommand

For example:

```text
select
```

should remain:

```text
InteractionState
```

while:

```text
move
activate
stop
open
close
```

become:

```text
TwinCommand
```

So:

```text
UI state
────────────
select
hover
focus

Twin commands
────────────
move
start
stop
activate
open
close
```

This distinction will save us a lot of trouble later.

---

# 5.22 Create a `CommandHandler`

Now we need somewhere for commands to go.

Create:

```text
lib/application/runtime/twin_command_handler.dart
```

```dart
import '../../domain/core/twin_command.dart';

abstract class TwinCommandHandler {
  bool supports(TwinCommand command);

  Future<void> handle(
    TwinCommand command,
  );
}
```

Examples later:

```text
MoveCommandHandler
StartMachineCommandHandler
RobotCommandHandler
CraneCommandHandler
```

Again, the core doesn't know what they mean.

---

# 5.23 Generic command bus

Create:

```text
lib/application/runtime/twin_command_bus.dart
```

```dart
import '../../domain/core/twin_command.dart';
import 'twin_command_handler.dart';

class TwinCommandBus {
  final List<TwinCommandHandler> handlers;

  const TwinCommandBus({
    required this.handlers,
  });

  Future<bool> dispatch(
    TwinCommand command,
  ) async {
    for (final handler in handlers) {
      if (handler.supports(command)) {
        await handler.handle(command);
        return true;
      }
    }

    return false;
  }
}
```

Now we have:

```text
Interaction
      ↓
TwinCommand
      ↓
CommandBus
      ↓
appropriate handler
```

---

# 5.24 Why the command bus matters for your future AI

This architecture gives you something very valuable.

Today:

```text
User
 ↓
click
 ↓
InteractionEvent
 ↓
TwinCommand
```

Later:

```text
AI Agent
 ↓
TwinCommand
```

Or:

```text
Simulation
 ↓
TwinCommand
```

Or:

```text
Automation Rule
 ↓
TwinCommand
```

Or:

```text
REST API
 ↓
TwinCommand
```

All converge:

```text
                  ┌── User
                  ├── AI
                  ├── Simulation
                  ├── Automation
                  └── API
                        │
                        ▼
                  TwinCommand
                        │
                        ▼
                  CommandBus
                        │
                        ▼
                    Runtime
```

This is a major foundation for the intelligent platform you described.

---

# 5.25 First real command: move

Let's implement one concrete generic command.

Create:

```text
lib/application/runtime/move_entity_command_handler.dart
```

```dart
import '../../domain/core/twin_command.dart';
import '../../domain/core/twin_entity.dart';
import '../../domain/core/twin_event.dart';
import '../../domain/core/twin_property.dart';
import '../../domain/core/spatial_component.dart';
import '../../domain/core/twin_entity_id.dart';
import 'twin_command_handler.dart';
import 'twin_runtime.dart';

class MoveEntityCommandHandler
    implements TwinCommandHandler {
  final TwinRuntime runtime;

  const MoveEntityCommandHandler({
    required this.runtime,
  });

  @override
  bool supports(TwinCommand command) {
    return command.action == 'move';
  }

  @override
  Future<void> handle(
    TwinCommand command,
  ) async {
    final entity = runtime.state.entity(
      command.entityId.value,
    );

    if (entity == null) {
      throw StateError(
        'Entity not found: ${command.entityId.value}',
      );
    }

    final spatial =
        entity.component('spatial') as SpatialComponent?;

    if (spatial == null) {
      throw StateError(
        'Entity has no spatial component: '
        '${command.entityId.value}',
      );
    }

    final position = Vector3(
      _number(command.parameters['x']),
      _number(command.parameters['y']),
      _number(command.parameters['z']),
    );

    final updated = entity.copyWith(
      components: {
        ...entity.components,
        'spatial': spatial.copyWith(
          position: position,
        ),
      },
    );

    runtime.apply(
      EntityUpdated(updated),
    );
  }

  double _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    throw ArgumentError(
      'Expected numeric coordinate, got $value',
    );
  }
}
```

This is our first **actual interactive state mutation**.

---

# 5.26 Test the move command

```dart
test('move command updates spatial state', () async {
  final runtime = TwinRuntime();

  final entity = TwinEntity(
    id: const TwinEntityId('robot-001'),
    type: 'robot',
    components: {
      'spatial': const SpatialComponent(
        position: Vector3(0, 0, 0),
      ),
    },
  );

  runtime.apply(
    EntityCreated(entity),
  );

  final handler = MoveEntityCommandHandler(
    runtime: runtime,
  );

  await handler.handle(
    const TwinCommand(
      entityId: TwinEntityId('robot-001'),
      action: 'move',
      parameters: {
        'x': 10,
        'y': 0,
        'z': 5,
      },
    ),
  );

  final updated =
      runtime.state.entity('robot-001')!;

  final spatial =
      updated.component('spatial') as SpatialComponent;

  expect(
    spatial.position,
    const Vector3(10, 0, 5),
  );
});
```

Now we have a complete loop:

```text
TwinEntity
   ↓
TwinCommand(move)
   ↓
CommandHandler
   ↓
EntityUpdated
   ↓
TwinRuntime
   ↓
TwinState
```

---

# 5.27 This is where Step 4 comes alive

Combine the scene system:

```text
TwinState
    ↓
TwinSceneBuilder
    ↓
SceneGraph
```

After moving:

```text
TwinCommand
    ↓
TwinRuntime
    ↓
TwinState changed
    ↓
SceneGraph rebuilt/diffed
    ↓
SceneNode position changed
    ↓
Renderer moves object
```

So eventually a user dragging a robot will produce:

```text
mouse drag
   ↓
move InteractionEvent
   ↓
TwinCommand
   ↓
MoveEntityCommandHandler
   ↓
TwinState
   ↓
SceneNode
   ↓
3D object moves
```

That's the beginning of the **game-like interaction model** you want.

---

# 5.28 Don't directly mutate the scene during drag

This is an important performance/design decision.

You may be tempted to do:

```text
drag
 ↓
SceneNode.position = ...
```

Don't make that the authoritative state.

The authoritative state should remain:

```text
TwinState
```

The scene is a representation.

So:

```text
❌ pointer → scene mutation

✅ pointer → command → twin state → scene update
```

There can later be a **preview layer** for smooth drag feedback, but the authoritative state should stay in the Twin runtime.

---

# 5.29 Add interaction events to the runtime architecture

You now effectively have three streams:

```text
TwinRuntime
├── TwinState
├── TwinEvent
└── TwinCommand
```

and:

```text
InteractionRuntime
└── InteractionState
```

The overall architecture becomes:

```text
                         USER
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
           hover        select        drag
             │            │            │
             └────────────┼────────────┘
                          ▼
                  InteractionEvent
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
      InteractionState          TwinCommand
                                      │
                                      ▼
                               CommandBus
                                      │
                                      ▼
                                  Handler
                                      │
                                      ▼
                                TwinRuntime
                                      │
                         ┌────────────┴────────────┐
                         ▼                         ▼
                    TwinState                  TwinEvent
                         │
                         ▼
                    SceneGraph
                         │
                         ▼
                     Renderer
```

That's a very strong foundation.

---

# 5.30 Connect it to your existing UI later

Your current project has Flutter screens and providers around the terminal visualization. 

**Do not immediately rewrite those screens.**

Instead, the first migration should be one tiny interaction:

> Click a rendered container → generic `select` → `InteractionState.selectedEntityId`.

No movement yet in the actual UI.

The first working UI path should be:

```text
Canvas/3D click
      ↓
nodeId
      ↓
InteractionTarget
      ↓
InteractionEvent(select)
      ↓
InteractionRuntime
      ↓
selectedEntityId
```

Then a UI panel can read:

```text
selectedEntityId
       ↓
TwinState.entity(id)
       ↓
PropertiesComponent
```

This gives you a generic inspector.

---

# 5.31 The first generic inspector

This is worth implementing conceptually now.

Don't create:

```text
ContainerDetailsPanel
```

for the new architecture.

Instead create:

```text
TwinInspector
```

which understands:

```text
TwinEntity
PropertiesComponent
```

So:

```text
click container
      ↓
selectedEntityId
      ↓
TwinEntity
      ↓
properties
      ↓
generic inspector
```

And tomorrow:

```text
click crane
      ↓
TwinEntity
      ↓
properties
      ↓
same inspector
```

No new inspector architecture required.

---

# 5.32 Step 5 acceptance checklist

Before Step 6, I would want:

```text
[ ] InteractionTarget exists

[ ] InteractionEvent exists

[ ] InteractionType exists

[ ] InteractionState exists

[ ] InteractionRuntime exists

[ ] InteractionHandler exists

[ ] InteractionSystem exists

[ ] SceneNode supports interaction metadata

[ ] HitTestResult exists

[ ] InteractionTargetResolver exists

[ ] InteractionEvent → TwinCommand works

[ ] TwinCommandBus exists

[ ] MoveEntityCommandHandler exists

[ ] move command updates TwinState

[ ] selection does NOT modify TwinState

[ ] existing renderer still works

[ ] existing container UI still works

[ ] flutter analyze passes

[ ] flutter test passes
```

---

# The bigger picture after Step 5

We now have the beginnings of a **real platform kernel**, rather than just a refactored container application:

```text
                 ┌─────────────────────────┐
                 │       TWIN CORE          │
                 │                         │
                 │ TwinEntity              │
                 │ TwinComponent           │
                 │ TwinState               │
                 │ TwinEvent               │
                 │ TwinRelationship        │
                 │ TwinCommand             │
                 └────────────┬────────────┘
                              │
              ┌───────────────┼────────────────┐
              │               │                │
              ▼               ▼                ▼
         Data/Sync        Interaction       Simulation
              │               │                │
              ▼               ▼                ▼
        Repositories       Commands         Future
              │               │                │
              └───────────────┼────────────────┘
                              ▼
                        SceneGraph
                              │
                              ▼
                         Renderers
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
                  Canvas      3D       WebGL
```

And this is the key transformation:

```text
BEFORE

Container
   ↓
Container UI
   ↓
Container Renderer


AFTER

                    Twin
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
      Data       Interaction    Simulation
       │             │             │
       └─────────────┼─────────────┘
                     ▼
                 TwinState
                     │
                     ▼
                SceneGraph
                     │
                     ▼
                 Renderer
```

### Step 6 should be the **Schema & Component System**.

That's the next major piece because right now we still have hardcoded things like:

```text
type = 'container'
properties = manually defined
size = TwinEnum(...)
status = TwinEnum(...)
assetId = hardcoded
```

To become genuinely **agnostic and dynamically generatable**, we need to introduce:

```text
TwinType
TwinSchema
PropertyDefinition
ComponentDefinition
RelationshipDefinition
ActionDefinition
VisualizationDefinition
```

so that a definition such as:

```yaml
type: robot

properties:
  battery:
    type: number
    unit: percent

  speed:
    type: number
    unit: m/s

components:
  spatial: true
  telemetry: true

actions:
  - move
  - stop
  - charge

visualization:
  asset: robot.glb
```

can dynamically produce a functioning twin **without writing a new `RobotTwin`, `RobotSceneBuilder`, `RobotPanel`, and `RobotCommandHandler` for every domain**.

That is the step where your platform starts moving from **"generic architecture"** toward **"dynamic digital-twin platform."**
