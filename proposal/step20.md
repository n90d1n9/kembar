# Step 5.5A.12 — State Machines, Behaviors & Rules

Now we move from:

> **“What exists and where is it?”**

to:

> **“What can it do, what state is it in, and what should happen next?”**

This is the layer that makes your digital twin **dynamic and game-like** while remaining domain-agnostic.

The key architecture should be:

```text
Entity
  │
  ├── Components / Properties
  │
  ├── Current State
  │
  ├── Available Actions
  │
  ├── Conditions
  │
  └── Behavior
          │
          ▼
      State Transition
          │
          ▼
       Transaction
          │
          ▼
       World State
```

---

# 5.5A.12.1 Don't put behavior inside the entity

Avoid this:

```dart
class Robot {
  void moveToRack() {}
  void pickCargo() {}
  void chargeBattery() {}
}
```

That immediately makes your core domain-specific.

Instead, an entity should mostly contain **data and identity**:

```text
robot-01
  ├── transform
  ├── velocity
  ├── battery
  ├── capabilities
  └── state
```

Behavior belongs to the simulation/application layer.

That allows exactly the same architecture for:

```text
robot
customer
truck
machine
employee
aircraft
animal
building
room
warehouse
restaurant
```

---

# 5.5A.12.2 Generic state machine

Create:

```text
lib/domain/behavior/state_machine/
```

with:

```text
state.dart
state_transition.dart
state_machine.dart
transition_condition.dart
transition_action.dart
```

Start with:

```dart
class StateDefinition {
  final String id;

  const StateDefinition({
    required this.id,
  });
}
```

Example:

```text
idle
moving
loading
unloading
charging
maintenance
```

The engine doesn't care what those names mean.

---

# 5.5A.12.3 State transition

```dart
class StateTransition {
  final String from;

  final String to;

  final List<TransitionCondition> conditions;

  final List<TransitionAction> actions;

  const StateTransition({
    required this.from,
    required this.to,
    this.conditions = const [],
    this.actions = const [],
  });
}
```

Now we can define:

```text
idle
 ↓
moving
```

with:

```text
condition:
target exists
```

And:

```text
moving
 ↓
loading
```

with:

```text
condition:
distanceToTarget < threshold
```

---

# 5.5A.12.4 Conditions

Conditions should be generic.

Create:

```dart
abstract interface class TransitionCondition {
  bool evaluate(
    BehaviorContext context,
  );
}
```

Examples:

```text
PropertyCondition
DistanceCondition
RelationCondition
CapacityCondition
CollisionCondition
TimeCondition
ResourceCondition
ExpressionCondition
```

But don't build all of them immediately.

Start with three:

```text
PropertyCondition
DistanceCondition
TimeCondition
```

---

# 5.5A.12.5 Property condition

For example:

```text
battery.level < 20
```

could trigger:

```text
moving → charging
```

Generic representation:

```dart
class PropertyCondition
    implements TransitionCondition {

  final String entityId;

  final String property;

  final dynamic expected;

  const PropertyCondition({
    required this.entityId,
    required this.property,
    required this.expected,
  });

  @override
  bool evaluate(
    BehaviorContext context,
  ) {
    // evaluate against snapshot
    return true;
  }
}
```

Eventually don't restrict this to equality.

You'll want:

```text
==
!=
>
<
>=
<=
```

---

# 5.5A.12.6 Expression conditions

This becomes much more powerful.

Instead of hardcoding:

```dart
if (battery < 20) ...
```

we can represent:

```text
battery.level < 20
```

or:

```text
occupancy.current >= occupancy.capacity
```

or:

```text
distance(robot, target) < 1.0
```

This suggests eventually creating a tiny **rule/expression engine**.

For example:

```text
Expression
    ├── Property
    ├── Constant
    ├── Comparison
    ├── AND
    ├── OR
    └── NOT
```

Then:

```text
battery.level < 20 AND state == moving
```

can be represented structurally rather than as arbitrary code.

This is important for your future **dynamic generation**.

---

# 5.5A.12.7 Actions

Conditions decide:

> Can this transition happen?

Actions decide:

> What should happen when it happens?

Create:

```dart
abstract interface class TransitionAction {
  List<WorldChange> execute(
    BehaviorContext context,
  );
}
```

For example:

```text
SetStateAction
SetPropertyAction
MoveAction
CreateRelationAction
RemoveRelationAction
TriggerEventAction
```

Again, these produce changes.

They don't directly mutate the world.

---

# 5.5A.12.8 The crucial rule

A behavior must **not** do:

```dart
entity.state = 'charging';
```

Instead:

```text
Behavior
   ↓
SetStateAction
   ↓
StateChange
   ↓
Transaction
   ↓
Validation
   ↓
Commit
```

So behavior remains compatible with:

```text
undo
simulation
replay
multiplayer
AI
history
```

---

# 5.5A.12.9 Behavior context

Create:

```dart
class BehaviorContext {
  final WorldSnapshot world;

  final String entityId;

  final SimulationTime time;

  final List<WorldChange> changes;

  const BehaviorContext({
    required this.world,
    required this.entityId,
    required this.time,
    required this.changes,
  });
}
```

This gives behavior access to the world **without giving it direct mutation privileges**.

---

# 5.5A.12.10 State machine runtime

Now:

```dart
class StateMachineRuntime {

  void evaluate(
    BehaviorContext context,
    StateMachineDefinition machine,
  ) {
    final currentState =
        machine.currentState(context.entityId);

    final transitions =
        machine.transitionsFrom(currentState);

    for (final transition in transitions) {
      if (_conditionsPass(
        transition,
        context,
      )) {
        _execute(
          transition,
          context,
        );

        break;
      }
    }
  }
}
```

This evaluates:

```text
current state
     ↓
candidate transitions
     ↓
conditions
     ↓
first valid transition
     ↓
actions
     ↓
changes
```

---

# 5.5A.12.11 Don't automatically allow multiple transitions

Suppose:

```text
idle → moving
moving → loading
loading → unloading
```

If the runtime evaluates recursively in the same tick, one entity could accidentally go:

```text
idle
→ moving
→ loading
→ unloading
```

in a single frame.

Usually we want:

```text
T0:
idle

T1:
moving

T2:
loading
```

So introduce:

```text
maxTransitionsPerTick = 1
```

as the initial default.

Later we can support explicit chained transitions.

---

# 5.5A.12.12 Example: warehouse robot

Define states:

```text
idle
moving-to-pickup
loading
moving-to-dropoff
unloading
charging
```

Transitions:

```text
idle
 └─ if task exists
       ↓
moving-to-pickup

moving-to-pickup
 └─ if distance < threshold
       ↓
loading

loading
 └─ if cargo loaded
       ↓
moving-to-dropoff

moving-to-dropoff
 └─ if distance < threshold
       ↓
unloading

unloading
 └─ if cargo unloaded
       ↓
idle
```

The platform doesn't know what a warehouse is.

It simply executes the state graph.

---

# 5.5A.12.13 Restaurant example

Exactly the same machinery:

```text
table
 ├── available
 ├── reserved
 ├── occupied
 └── cleaning
```

Transitions:

```text
available
 ↓ reservation
reserved

reserved
 ↓ customer arrives
occupied

occupied
 ↓ customer leaves
cleaning

cleaning
 ↓ cleaned
available
```

No new engine code.

Only configuration.

That is what **domain agnostic** should mean.

---

# 5.5A.12.14 Factory example

Machine:

```text
idle
processing
completed
maintenance
failed
```

Rules:

```text
idle → processing
    if production order exists

processing → completed
    if production progress >= 100%

processing → failed
    if health <= 0

failed → maintenance
    if technician assigned

maintenance → idle
    if repaired
```

Again:

**same state machine engine.**

---

# 5.5A.12.15 Entity-specific state machine

Some entities need their own machine.

Others may share a template.

This is important.

For example:

```text
Robot Type A
    ↓
WarehouseRobotBehavior
```

and:

```text
Robot Type B
    ↓
WarehouseRobotBehavior
```

Both instances can share:

```text
StateMachineDefinition
```

while storing separate:

```text
currentState
```

So:

```text
Definition
    │
    ├── Robot 01 → moving
    ├── Robot 02 → charging
    └── Robot 03 → loading
```

This is more efficient than duplicating definitions.

---

# 5.5A.12.16 Separate definition from runtime state

Very important.

### Definition

```text
states
transitions
conditions
actions
```

### Runtime

```text
currentState
stateEnteredAt
transitionHistory
```

So:

```dart
class StateMachineDefinition {
  final String id;
  final List<StateDefinition> states;
  final List<StateTransition> transitions;
}
```

while:

```dart
class StateMachineState {
  final String currentState;
  final SimulationTime enteredAt;
}
```

This allows thousands of entities to share one definition.

---

# 5.5A.12.17 State transition history

Every transition should be observable.

Example event:

```json
{
  "type": "state.changed",
  "entityId": "robot-01",
  "from": "moving",
  "to": "loading",
  "simulationTime": 182.4
}
```

Now your UI can show:

```text
Robot 01
● Loading
```

and analytics can calculate:

```text
average loading duration
```

without modifying the simulation engine.

---

# 5.5A.12.18 State duration

This becomes useful immediately.

If:

```text
enteredStateAt = 100
currentTime = 135
```

then:

```text
stateDuration = 35 seconds
```

Now a generic rule can be:

```text
if state == loading
AND stateDuration > 120s
→ raise alert
```

This is useful in almost every domain.

---

# 5.5A.12.19 Rules should be independent of behaviors

Now we introduce a second concept:

> **Rules observe the world and determine whether something should happen.**

Behavior:

```text
"how does this entity behave?"
```

Rule:

```text
"what condition is true?"
```

These should not be mixed.

Architecture:

```text
World
 │
 ├── Behavior System
 │
 ├── Rule System
 │
 └── Simulation Systems
```

---

# 5.5A.12.20 Rule engine

Create:

```text
lib/domain/rules/
```

Start:

```dart
class RuleDefinition {
  final String id;

  final RuleCondition condition;

  final List<RuleAction> actions;

  const RuleDefinition({
    required this.id,
    required this.condition,
    required this.actions,
  });
}
```

Then:

```dart
abstract interface class RuleCondition {
  bool evaluate(
    RuleContext context,
  );
}
```

---

# 5.5A.12.21 Difference between State Machine and Rule Engine

This distinction matters.

### State machine

Usually:

```text
current state
      ↓
possible transition
      ↓
next state
```

### Rule engine

Can be:

```text
world condition
      ↓
action
```

without changing state.

For example:

```text
If rack occupancy > 90%
→ raise warning
```

No state transition is required.

---

# 5.5A.12.22 Rule severity

Rules should eventually support:

```text
info
warning
critical
error
```

Example:

```text
Rack utilization:
85% → info
90% → warning
100% → critical
```

This becomes useful for the game-like UI too.

---

# 5.5A.12.23 Rule outputs should be events or proposed changes

A rule should not directly change the world.

Instead:

```text
Rule
 ↓
RuleResult
 ↓
Event / Change Proposal
 ↓
Transaction
```

Example:

```text
Temperature > threshold
        ↓
OverheatDetected
        ↓
Set machine state = emergency
        ↓
Transaction
```

This preserves the architecture.

---

# 5.5A.12.24 Priorities

Rules may conflict.

Example:

```text
Rule A:
if battery < 20 → charge

Rule B:
if emergency → stop

Rule C:
if task urgent → continue
```

So rules need priority:

```dart
class RuleDefinition {
  final int priority;
  ...
}
```

Higher priority first.

For example:

```text
1000 = emergency
500  = safety
100  = operational
10   = optimization
```

Don't hardcode these numbers globally yet; just establish the concept.

---

# 5.5A.12.25 Safety rules must dominate optimization

This is particularly important for the eventual AI layer.

Suppose AI says:

> Put this cargo here because it minimizes walking distance.

But:

```text
placement violates safety clearance
```

The AI proposal must lose.

Architecture:

```text
Optimization
     ↓
Candidate
     ↓
Safety rules
     ↓
❌ reject
```

This is one reason our transaction validation architecture is so important.

---

# 5.5A.12.26 Behavior + Rules + Constraints

We now have three different concepts:

### Behavior

```text
What does an entity try to do?
```

### Rule

```text
What condition/action applies?
```

### Constraint

```text
What is allowed?
```

Example:

```text
Robot wants:
move to Rack B

Behavior:
generate movement

Rule:
if battery < 20%, prefer charging

Constraint:
robot cannot pass through wall
```

That separation will keep the platform clean.

---

# 5.5A.12.27 Goal-driven behavior

Now we're ready for a more advanced concept.

Instead of defining every action manually:

```text
move
load
unload
charge
```

we can define:

```text
Goal:
deliver cargo-123 to Zone-B
```

Then behavior/planning determines:

```text
find cargo
→ move to cargo
→ load cargo
→ find route
→ move
→ unload
→ verify goal
```

This is the bridge between:

```text
State Machines
```

and eventually:

```text
AI Planning
```

---

# 5.5A.12.28 Introduce `Goal`

```dart
class Goal {
  final String id;

  final String entityId;

  final GoalCondition completion;

  const Goal({
    required this.id,
    required this.entityId,
    required this.completion,
  });
}
```

Example:

```text
Goal:
entity = robot-01

condition:
cargo-123 stored-in zone-B
```

The goal itself doesn't tell the robot exactly how to achieve it.

That's important.

---

# 5.5A.12.29 Goal vs Action

Don't confuse:

```text
Goal:
deliver cargo
```

with:

```text
Action:
move forward
```

Goal is **desired outcome**.

Action is **specific change**.

This gives us:

```text
Goal
 ↓
Planner
 ↓
Actions
 ↓
Transactions
```

Later the planner can be:

```text
deterministic
rule-based
heuristic
AI
LLM-assisted
optimization-based
```

without changing the world kernel.

---

# 5.5A.12.30 Goal evaluation

At each simulation tick:

```text
Goal
 ↓
Is completed?
 ├── yes → finish
 └── no
       ↓
    continue
```

Potential statuses:

```dart
enum GoalStatus {
  pending,
  active,
  completed,
  failed,
  cancelled,
}
```

This becomes very useful for automation.

---

# 5.5A.12.31 Behavior trees later

Eventually, some domains will need more than state machines.

For example:

```text
Selector
 ├── charge
 ├── deliver
 └── wait
```

or:

```text
Sequence
 ├── find cargo
 ├── move
 ├── pick
 ├── move
 └── drop
```

That is essentially a **behavior tree**.

Don't implement it yet.

But design your architecture so:

```text
BehaviorProvider
```

can later support:

```text
StateMachine
BehaviorTree
Planner
Policy
AI Agent
```

---

# 5.5A.12.32 `BehaviorProvider`

Create a generic abstraction:

```dart
abstract interface class BehaviorProvider {

  List<WorldChange> evaluate(
    BehaviorContext context,
  );
}
```

Then:

```text
StateMachineBehavior
BehaviorTreeBehavior
PlannerBehavior
AIBehavior
```

can all implement it.

This is much better than locking the whole system into state machines.

---

# 5.5A.12.33 The behavior pipeline

Now we can define:

```text
Entity
  │
  ▼
Behavior Provider
  │
  ├── State Machine
  ├── Behavior Tree
  ├── Planner
  └── AI
  │
  ▼
Candidate Changes
  │
  ▼
Spatial / Semantic Validation
  │
  ▼
Transaction
  │
  ▼
World
```

That's a very strong architecture.

---

# 5.5A.12.34 Game-style interaction

This step also unlocks your "game-like" requirement.

Imagine the user selects:

```text
Robot 01
```

The UI can display:

```text
STATE
Moving

GOAL
Deliver Cargo 123

BATTERY
72%

TASK
Zone B

AVAILABLE ACTIONS
[Pause]
[Charge]
[Cancel]
[Inspect]
```

Those buttons don't directly manipulate the world.

They issue:

```text
commands
```

which become transactions.

---

# 5.5A.12.35 Player interaction and AI interaction become identical

User:

```text
"Move robot to Zone B"
```

AI:

```text
"Move robot to Zone B"
```

Automation:

```text
"Move robot to Zone B"
```

All can become:

```text
Goal / Intent
```

then:

```text
Planner
```

then:

```text
Transaction
```

This is a major step toward a truly unified platform.

---

# 5.5A.12.36 Domain configuration example

Eventually a restaurant could be described with configuration like:

```json
{
  "entityType": "table",
  "behavior": {
    "states": [
      "available",
      "reserved",
      "occupied",
      "cleaning"
    ],
    "transitions": [
      {
        "from": "available",
        "to": "reserved",
        "when": "reservation.exists"
      },
      {
        "from": "reserved",
        "to": "occupied",
        "when": "customer.arrived"
      },
      {
        "from": "occupied",
        "to": "cleaning",
        "when": "customer.left"
      },
      {
        "from": "cleaning",
        "to": "available",
        "when": "cleaning.completed"
      }
    ]
  }
}
```

The engine itself doesn't contain:

```text
RestaurantTable
```

logic.

It interprets the configuration.

That's the level of domain agnosticism we're aiming for.

---

# 5.5A.12.37 Even more important: relationships can trigger behavior

Because we already built the semantic graph, conditions can reference relationships.

For example:

```text
cargo
    stored-in
slot
    part-of
rack
    located-in
cold-storage
```

A rule can ask:

```text
Is cargo stored in cold storage?
```

or:

```text
Does this machine belong to production line A?
```

or:

```text
Is this customer seated at a VIP table?
```

So behavior doesn't only depend on geometry.

It can depend on:

```text
geometry
+
properties
+
relationships
+
time
+
resources
```

That's where the platform becomes much more expressive.

---

# 5.5A.12.38 Context query

Eventually conditions should use a generic query API:

```dart
abstract interface class WorldQuery {

  Entity? entity(String id);

  dynamic property(
    String entityId,
    String path,
  );

  bool hasRelation(
    String subject,
    String predicate,
    String object,
  );

  double distance(
    String entityA,
    String entityB,
  );

  bool contains(
    String container,
    String entity,
  );
}
```

Then a rule doesn't need to understand the underlying database.

This will become important when we later add spatial indexes and optimized queries.

---

# 5.5A.12.39 Deterministic behavior

For simulation and replay, the same input should produce the same result.

Avoid:

```dart
Random()
```

without controlled seeds.

Instead:

```dart
SimulationRandom(seed)
```

so:

```text
Scenario A
seed = 12345
```

can be reproduced exactly.

This matters enormously for:

```text
simulation debugging
AI evaluation
prediction comparison
replay
multiplayer
testing
```

---

# 5.5A.12.40 Event ordering

Once behavior is added, event ordering matters.

A good initial order:

```text
1. External inputs
2. Sensor observations
3. Goal evaluation
4. Behavior evaluation
5. Simulation systems
6. Constraint validation
7. Transaction commit
8. State transitions
9. Events
10. Derived-state updates
```

You may eventually change this, but establish an explicit execution model.

Don't let execution order emerge accidentally from Dart import/class ordering.

---

# 5.5A.12.41 Proposed runtime loop

The runtime now looks like:

```text
                 SIMULATION TICK
                       │
                       ▼
                 Read Inputs
                       │
                       ▼
                Apply Observations
                       │
                       ▼
                  Evaluate Goals
                       │
                       ▼
                Evaluate Behaviors
                       │
                       ▼
               Run Simulation Systems
                       │
                       ▼
                 Produce Changes
                       │
                       ▼
              Validate Transactions
                       │
                       ▼
                    Commit
                       │
                       ▼
                 Emit Events
                       │
                       ▼
               Update Derived State
                       │
                       ▼
                  Next Tick
```

This is starting to look like an actual **digital-twin operating system**.

---

# 5.5A.12.42 Actual code structure

I'd now extend the project toward:

```text
lib/
├── domain/
│
│   ├── entity/
│   │
│   ├── spatial/
│   │
│   ├── semantic/
│   │
│   ├── world/
│   │
│   ├── time/
│   │   ├── world_time.dart
│   │   ├── simulation_time.dart
│   │   ├── world_clock.dart
│   │   └── simulation_clock.dart
│   │
│   ├── simulation/
│   │   ├── simulation_system.dart
│   │   ├── simulation_context.dart
│   │   ├── simulation_runner.dart
│   │   ├── simulation_branch.dart
│   │   └── command_buffer.dart
│   │
│   ├── behavior/
│   │   ├── behavior_provider.dart
│   │   │
│   │   ├── state_machine/
│   │   │   ├── state.dart
│   │   │   ├── transition.dart
│   │   │   ├── condition.dart
│   │   │   ├── action.dart
│   │   │   └── runtime.dart
│   │   │
│   │   └── goals/
│   │       ├── goal.dart
│   │       ├── goal_status.dart
│   │       └── goal_evaluator.dart
│   │
│   └── rules/
│       ├── rule.dart
│       ├── rule_condition.dart
│       ├── rule_action.dart
│       └── rule_engine.dart
```

---

# 5.5A.12.43 What to implement now

Don't implement the entire tree.

The first concrete slice should be:

### 1. State definition

```dart
StateDefinition
```

### 2. Transition

```dart
StateTransition
```

### 3. Condition

```dart
TransitionCondition
```

### 4. Action

```dart
TransitionAction
```

### 5. Runtime state

```dart
StateMachineState
```

### 6. Runtime

```dart
StateMachineRuntime
```

### 7. One real condition

Start with:

```text
PropertyCondition
```

### 8. One real action

Start with:

```text
SetStateAction
```

That's enough to prove the architecture.

---

# 5.5A.12.44 First end-to-end test

Create an entity:

```text
robot-01
```

with:

```text
state = idle
battery = 80
```

Define:

```text
idle → moving
```

condition:

```text
goal.exists == true
```

Then:

```text
moving → charging
```

condition:

```text
battery < 20
```

Then:

```text
charging → idle
```

condition:

```text
battery >= 90
```

Now run simulation ticks.

You should see:

```text
idle
 ↓
moving
 ↓
...
battery drops
 ↓
charging
 ↓
battery rises
 ↓
idle
```

All state changes should appear as transactions/events.

---

# 5.5A.12.45 The bigger picture

At this point your platform is evolving into five major engines:

```text
┌───────────────────────────────────────────┐
│           DIGITAL TWIN KERNEL             │
├───────────────────────────────────────────┤
│                                           │
│  1. ENTITY ENGINE                         │
│     What exists?                          │
│                                           │
│  2. SPATIAL ENGINE                        │
│     Where is it?                          │
│     Does it fit?                          │
│                                           │
│  3. SEMANTIC ENGINE                       │
│     What is related to what?              │
│                                           │
│  4. TRANSACTION ENGINE                    │
│     How does the world change safely?     │
│                                           │
│  5. BEHAVIOR/SIMULATION ENGINE            │
│     What happens next?                    │
│                                           │
└───────────────────────────────────────────┘
```

And above that we can later build:

```text
AI / PLANNING / PREDICTION
```

---

# 5.5A.12.46 The next major step

The next step should be **5.5A.13 — Query, Rule & Constraint Expression Engine**.

This is where we make the system truly **dynamic/configurable instead of code-defined**.

The goal is to eventually express things like:

```text
IF
    cargo.weight > rack.remainingCapacity
THEN
    placement = invalid
```

or:

```text
IF
    table.capacity >= party.size
    AND table.status == available
    AND distance(table, kitchen) < 20m
THEN
    table.score += 10
```

or:

```text
IF
    machine.temperature > 80
THEN
    machine.state = emergency
```

or even:

```text
IF
    room.occupancy > room.capacity
THEN
    reject(new_person)
```

**without writing a new Dart class for every domain rule.**

That expression layer is the bridge between your hard-coded engine and the eventual **AI-generated digital twin**: AI can generate entities, relationships, behaviors, constraints, placement rules, and simulation policies as data/configuration, while your deterministic kernel remains responsible for validating and executing them.
