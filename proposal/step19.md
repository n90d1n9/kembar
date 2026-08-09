# Step 5.5A.11 — Time & Simulation State

Now we turn the **world kernel** into an actual **digital-twin runtime**.

At 5.5A.10 we established:

```text
WorldState
   ↓
Transaction
   ↓
Validation
   ↓
Commit
   ↓
Event
```

But so far the world is essentially **timeless**.

An object has:

```text
position = X
status = running
temperature = 20°C
```

We now need to represent:

```text
position(t)
status(t)
temperature(t)
velocity(t)
inventory(t)
energy(t)
```

And, crucially, we need to distinguish **what is actually happening** from **what might happen in a simulation**.

---

# 5.5A.11.1 The fundamental distinction: World Time vs Simulation Time

This is the most important design decision in this step.

Imagine your real warehouse twin currently represents:

```text
World Time = 10:00:00
```

A user asks:

> What happens if I move this robot to Zone B?

We don't want to modify reality.

Instead:

```text
REAL WORLD
10:00
   │
   ▼
Snapshot
   │
   ├───────────────┐
   ▼               ▼
Live Twin       Simulation
                  │
                10:01
                  │
                10:02
                  │
                10:03
```

Therefore we need **two concepts**:

```text
World Clock
Simulation Clock
```

---

# 5.5A.11.2 `WorldTime`

Create:

```text
lib/domain/time/world_time.dart
```

Initially keep it simple:

```dart
class WorldTime {
  final DateTime instant;

  const WorldTime(this.instant);
}
```

But eventually I recommend making time more abstract:

```dart
abstract interface class TimePoint {
  double get value;
}
```

because some simulations don't necessarily use wall-clock time.

For example:

```text
warehouse:
2026-08-09 10:00

factory:
simulation tick 12342

game:
day 18 / hour 14

traffic:
t = 87.42 seconds
```

So don't hardwire `DateTime` throughout the engine.

---

# 5.5A.11.3 `SimulationTime`

Create:

```dart
class SimulationTime {
  final double seconds;

  const SimulationTime(this.seconds);

  SimulationTime advance(double dt) {
    return SimulationTime(
      seconds + dt,
    );
  }
}
```

Now:

```text
SimulationTime(0)
SimulationTime(1)
SimulationTime(2)
SimulationTime(3)
```

can represent:

```text
T0
T1
T2
T3
```

independently from real-world time.

---

# 5.5A.11.4 Don't make simulation time equal wall-clock time

Avoid:

```dart
DateTime.now()
```

inside simulation logic.

That would make simulation:

```text
dependent on computer speed
dependent on network latency
dependent on frame rate
```

Instead:

```text
Simulation
   │
   ▼
explicit dt
   │
   ▼
state transition
```

For example:

```dart
simulation.step(
  Duration(milliseconds: 100),
);
```

or:

```dart
simulation.step(
  0.1,
);
```

The simulation controls time.

---

# 5.5A.11.5 World clock

Add:

```dart
class WorldClock {
  WorldTime current;

  WorldClock(this.current);

  void advance(Duration duration) {
    current = WorldTime(
      current.instant.add(duration),
    );
  }
}
```

The live twin might therefore say:

```text
World clock:
2026-08-09 10:15:23
```

while simulation says:

```text
Scenario A:
T = 37.4 seconds
```

---

# 5.5A.11.6 Simulation clock

```dart
class SimulationClock {
  SimulationTime current;

  SimulationClock({
    this.current = const SimulationTime(0),
  });

  void advance(double dt) {
    current = current.advance(dt);
  }
}
```

Eventually we can add:

```text
pause
resume
reset
seek
step
speed
```

For example:

```text
simulation speed = 10x
```

means:

```text
1 real second
→
10 simulation seconds
```

while:

```text
speed = 0.1x
```

means:

```text
10 real seconds
→
1 simulation second
```

---

# 5.5A.11.7 `TemporalWorldState`

Now extend our world model.

Conceptually:

```dart
class TemporalWorldState {
  final WorldState world;

  final WorldTime worldTime;

  final SimulationTime? simulationTime;

  const TemporalWorldState({
    required this.world,
    required this.worldTime,
    this.simulationTime,
  });
}
```

But I recommend a slightly different architecture.

Don't embed simulation state directly into the live `WorldState`.

Instead:

```text
WorldState
     │
     ├── live twin
     │
     └── snapshots / branches
```

This keeps the core clean.

---

# 5.5A.11.8 World Snapshot

From 5.5A.10 we introduced:

```text
WorldSnapshot
```

Now make it temporal:

```dart
class TemporalSnapshot {
  final WorldSnapshot snapshot;

  final WorldTime worldTime;

  final SimulationTime? simulationTime;

  final WorldVersion version;

  const TemporalSnapshot({
    required this.snapshot,
    required this.worldTime,
    required this.version,
    this.simulationTime,
  });
}
```

Now we can say:

```text
Snapshot A
worldTime = 10:00
version = 42
```

and:

```text
Snapshot B
worldTime = 10:05
version = 47
```

---

# 5.5A.11.9 State is not just position

This is where the digital twin becomes substantially more powerful.

An entity may have:

```text
Transform
Position
Rotation
Velocity
Acceleration
Temperature
Pressure
Battery
Health
Inventory
Occupancy
OperatingState
```

We don't want special-case code for each domain.

So these should remain **components/properties**.

Example:

```json
{
  "id": "robot-01",
  "components": {
    "transform": {
      "position": [10, 2, 4]
    },
    "motion": {
      "velocity": [1.2, 0, 0]
    },
    "battery": {
      "level": 82
    },
    "operating": {
      "state": "moving"
    }
  }
}
```

The runtime doesn't need to know that this is a robot.

---

# 5.5A.11.10 State evolution

Now we introduce a very important concept:

```text
State Transition
```

A simulation takes:

```text
State(t)
```

and produces:

```text
State(t + dt)
```

Conceptually:

```text
S(t + dt) = F(S(t), inputs, dt)
```

Where:

```text
S = world state
F = simulation rules
inputs = external forces/events
dt = elapsed simulation time
```

---

# 5.5A.11.11 `SimulationSystem`

Create:

```text
lib/domain/simulation/simulation_system.dart
```

```dart
abstract interface class SimulationSystem {

  String get id;

  void update(
    SimulationContext context,
    double dt,
  );
}
```

A system could be:

```text
MotionSystem
CollisionSystem
TrafficSystem
InventorySystem
EnergySystem
ProductionSystem
WeatherSystem
CrowdSystem
```

But again:

**the core engine doesn't know these domains.**

They are plugins/systems.

---

# 5.5A.11.12 Simulation context

```dart
class SimulationContext {
  final WorldSnapshot world;

  final SimulationTime time;

  final SimulationCommandBuffer commands;

  const SimulationContext({
    required this.world,
    required this.time,
    required this.commands,
  });
}
```

Notice the system doesn't directly mutate:

```text
WorldState
```

Instead it produces commands.

This is extremely important.

---

# 5.5A.11.13 Why systems should not directly mutate world state

Avoid:

```dart
entity.position += velocity * dt;
```

inside the live world.

Instead:

```text
Simulation System
       │
       ▼
Calculate result
       │
       ▼
Command
       │
       ▼
Transaction
       │
       ▼
Validation
       │
       ▼
State update
```

This means simulation changes use the **same transaction architecture** we built in 5.5A.10.

That's exactly what we want.

---

# 5.5A.11.14 Simulation command buffer

Create:

```dart
class SimulationCommandBuffer {
  final List<WorldChange> _changes = [];

  void add(WorldChange change) {
    _changes.add(change);
  }

  List<WorldChange> flush() {
    final result = List<WorldChange>.from(
      _changes,
    );

    _changes.clear();

    return result;
  }
}
```

Now a simulation system can calculate:

```text
robot moves 1.2m
```

and emit:

```text
TransformChange
```

rather than directly changing the world.

---

# 5.5A.11.15 First real simulation system: motion

Let's implement the simplest one.

Entity:

```text
position = (0, 0, 0)
velocity = (2, 0, 0)
```

For:

```text
dt = 0.5
```

we calculate:

```text
position += velocity × dt
```

Therefore:

```text
position = (1, 0, 0)
```

System:

```dart
class MotionSystem
    implements SimulationSystem {

  @override
  String get id => 'motion';

  @override
  void update(
    SimulationContext context,
    double dt,
  ) {
    // query entities with motion component
    // calculate new transform
    // emit TransformChange
  }
}
```

The system is generic.

It doesn't know:

```text
robot
car
ship
drone
person
```

It knows:

```text
transform + velocity
```

---

# 5.5A.11.16 Fixed timestep

For deterministic simulation, don't normally run:

```text
dt = arbitrary frame duration
```

Instead use:

```text
fixed timestep
```

For example:

```text
dt = 0.02 seconds
```

which gives:

```text
50 simulation updates / second
```

Architecture:

```text
Render frame
      │
      ▼
accumulator
      │
      ├── 0.02
      ├── 0.02
      ├── 0.02
      └── ...
      │
      ▼
Simulation step
```

This is important for:

```text
determinism
collision
physics
network synchronization
replay
```

---

# 5.5A.11.17 `SimulationRunner`

Create:

```dart
class SimulationRunner {

  final List<SimulationSystem> systems;

  SimulationRunner({
    required this.systems,
  });

  void step(
    SimulationContext context,
    double dt,
  ) {
    for (final system in systems) {
      system.update(
        context,
        dt,
      );
    }
  }
}
```

Eventually this becomes the heart of the simulation engine.

---

# 5.5A.11.18 But system ordering matters

Consider:

```text
Motion
Collision
Navigation
```

If collision runs before motion:

```text
old position
```

is tested.

If motion runs first:

```text
new position
```

can be tested.

Therefore we need execution phases.

---

# 5.5A.11.19 Simulation phases

Start with:

```dart
enum SimulationPhase {
  input,
  preUpdate,
  update,
  physics,
  postUpdate,
  commit,
}
```

Pipeline:

```text
INPUT
  ↓
PRE_UPDATE
  ↓
UPDATE
  ↓
PHYSICS
  ↓
POST_UPDATE
  ↓
COMMIT
```

Later we can make this configurable.

---

# 5.5A.11.20 Example

Warehouse simulation:

```text
Input
 ↓
Orders arrive

PreUpdate
 ↓
Robot decisions

Update
 ↓
Robot movement

Physics
 ↓
Collision detection

PostUpdate
 ↓
Inventory changes

Commit
 ↓
World state
```

Restaurant simulation:

```text
Input
 ↓
Customers arrive

Update
 ↓
Customer movement

PostUpdate
 ↓
Seat occupancy

Commit
 ↓
World state
```

Same engine.

Different systems.

---

# 5.5A.11.21 Simulation branches

Now implement the concept we discussed earlier.

```dart
class SimulationBranch {

  final String id;

  TemporalSnapshot initial;

  TemporalSnapshot current;

  SimulationClock clock;

  SimulationBranch({
    required this.id,
    required this.initial,
    required this.current,
    required this.clock,
  });
}
```

A branch is:

> A hypothetical timeline starting from a known world snapshot.

---

# 5.5A.11.22 Forking a scenario

Suppose live world:

```text
Version 100
10:00
```

User asks:

> What if we add 20 more trucks?

We create:

```text
Scenario-01
    base = Version 100
```

Then:

```text
Scenario-01
   ↓
Add 20 trucks
   ↓
Run simulation
   ↓
T + 30 min
```

The real world remains:

```text
Version 100
```

This is the foundation for **what-if analysis**.

---

# 5.5A.11.23 Branch API

```dart
abstract interface class SimulationService {

  SimulationBranch fork(
    TemporalSnapshot snapshot,
  );

  void step(
    SimulationBranch branch,
    double dt,
  );

  TemporalSnapshot snapshot(
    SimulationBranch branch,
  );
}
```

Later:

```dart
void runUntil(
  SimulationBranch branch,
  double targetTime,
);
```

---

# 5.5A.11.24 Simulation speed

The simulation should be independent of rendering.

For example:

```text
1x
10x
100x
1000x
```

The renderer might update at:

```text
60 FPS
```

while simulation runs:

```text
1000 simulation seconds / second
```

for large-scale planning.

Or:

```text
0.1x
```

for detailed inspection.

---

# 5.5A.11.25 Pause, resume, seek

Eventually:

```dart
enum SimulationStatus {
  stopped,
  paused,
  running,
  completed,
}
```

And:

```dart
pause()
resume()
reset()
seek()
step()
```

These are not UI-only features.

They belong to the simulation runtime.

---

# 5.5A.11.26 Recording simulation state

For debugging and replay, capture:

```text
T0
T1
T2
T3
...
```

But don't necessarily store full world state every frame.

That would become huge.

Instead use:

```text
checkpoint + transactions
```

Example:

```text
Checkpoint @ T0

TX1
TX2
TX3
TX4

Checkpoint @ T10

TX5
TX6
...
```

This is much more scalable.

---

# 5.5A.11.27 Temporal event

Our previous events can now contain time:

```dart
class GenericWorldEvent {

  final String type;

  final String transactionId;

  final WorldTime worldTime;

  final SimulationTime? simulationTime;

  final Map<String, dynamic> data;

  ...
}
```

Now an event can say:

```json
{
  "type": "occupancy.changed",
  "worldTime": "2026-08-09T10:30:00",
  "simulationTime": 1842.4
}
```

---

# 5.5A.11.28 Real-world sensor ingestion

This becomes extremely useful for a true digital twin.

Suppose an IoT sensor says:

```text
Machine temperature = 82°C
```

That isn't a simulation.

It's an **external observation**.

Architecture:

```text
Sensor
  ↓
Observation
  ↓
Validation
  ↓
Transaction
  ↓
World State
```

So we need another concept:

```text
Observation
```

---

# 5.5A.11.29 Observation vs simulation

This distinction is critical:

```text
Observation
= what the real world says happened

Simulation
= what our model predicts may happen
```

Example:

```text
Real machine:
temperature = 82°C
```

versus:

```text
Simulation:
temperature predicted = 87°C
```

Don't mix these.

---

# 5.5A.11.30 `WorldObservation`

```dart
class WorldObservation {
  final String sourceId;

  final String entityId;

  final String property;

  final dynamic value;

  final WorldTime timestamp;

  final double? confidence;

  const WorldObservation({
    required this.sourceId,
    required this.entityId,
    required this.property,
    required this.value,
    required this.timestamp,
    this.confidence,
  });
}
```

Now the platform can ingest:

```text
IoT
GPS
ERP
WMS
camera
weather API
manual input
external system
```

without changing the world kernel.

---

# 5.5A.11.31 Observation pipeline

```text
External World
      │
      ▼
Sensor / API
      │
      ▼
Observation
      │
      ▼
Normalize
      │
      ▼
Validate
      │
      ▼
Transaction
      │
      ▼
World State
```

This is what begins turning the system into a **real digital twin**, rather than just a simulation.

---

# 5.5A.11.32 Prediction

Now we can introduce prediction later without corrupting the model.

Prediction:

```text
Current State
      │
      ▼
Simulation / Model
      │
      ▼
Future State
```

For example:

```text
Current:
battery = 80%

Prediction:
battery = 62% after 30 minutes
```

But prediction should live in a branch:

```text
Live World
    │
    ▼
Snapshot
    │
    ▼
Prediction Branch
    │
    ▼
Simulation
    │
    ▼
Predicted State
```

Never overwrite live state with prediction.

---

# 5.5A.11.33 This gives us three kinds of state

We now have:

### Observed

```text
What the real world reports.
```

### Current

```text
What the digital twin currently believes.
```

### Predicted

```text
What a model thinks may happen.
```

Potential architecture:

```text
             REAL WORLD
                 │
                 ▼
            Observations
                 │
                 ▼
          ┌──────────────┐
          │  LIVE TWIN  │
          └──────┬───────┘
                 │
              Snapshot
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Simulation A      Simulation B
        │                 │
        ▼                 ▼
   Prediction A      Prediction B
```

That is a very powerful foundation.

---

# 5.5A.11.34 Simulation systems should be pluggable

Don't create:

```text
WarehouseSimulation
RestaurantSimulation
FactorySimulation
```

inside the core.

Instead:

```text
SimulationSystem
```

is the plugin boundary.

Example:

```text
Core
├── MotionSystem
├── ResourceSystem
├── StateMachineSystem
└── CollisionSystem

Domain plugins
├── WarehouseRobotSystem
├── RestaurantServiceSystem
├── FactoryProductionSystem
└── TrafficSystem
```

The core remains domain agnostic.

---

# 5.5A.11.35 Generic state machines

Another useful system now becomes possible.

Entities can have states:

```text
idle
moving
loading
unloading
charging
maintenance
```

But again, don't hardcode these.

Create generic:

```dart
class StateMachineComponent {
  final String currentState;

  const StateMachineComponent({
    required this.currentState,
  });
}
```

Then transitions:

```text
idle
 ↓
moving
 ↓
loading
 ↓
unloading
 ↓
idle
```

This can work for:

```text
robot
customer
machine
vehicle
employee
aircraft
```

because the engine only understands:

```text
state + transition
```

---

# 5.5A.11.36 Simulation + state machine

For example:

```text
Robot
state = moving
velocity = 1.5 m/s
```

Motion system updates:

```text
position
```

When robot reaches target:

```text
distance <= threshold
```

State system generates:

```text
moving → loading
```

That becomes a transaction.

So:

```text
Physics
   ↓
Condition
   ↓
State transition
   ↓
Transaction
   ↓
World event
```

Now we have emergent behavior from simple systems.

---

# 5.5A.11.37 Simulation should use the same placement engine

This is another major architectural win.

Suppose a robot wants to move to:

```text
Rack B
```

Simulation shouldn't implement its own placement logic.

Instead:

```text
Robot planner
    ↓
Placement engine
    ↓
Candidate
    ↓
Collision
    ↓
Clearance
    ↓
Semantic validation
    ↓
Transaction
```

Thus:

```text
Manual placement
AI placement
Simulation placement
```

all share the same spatial kernel.

---

# 5.5A.11.38 This avoids the "two worlds" problem

A common architecture mistake is:

```text
Editor engine
    └── placement logic

Simulation engine
    └── separate placement logic
```

Eventually they disagree.

You get:

```text
Editor says:
✓ fits

Simulation says:
❌ collision
```

We don't want that.

Instead:

```text
                  Spatial Kernel
                 /      |       \
                /       |        \
             Editor      AI      Simulation
```

One authoritative geometry/constraint engine.

---

# 5.5A.11.39 The complete architecture after 5.5A.11

We're now roughly here:

```text
                       DIGITAL TWIN PLATFORM
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
           EDITOR              AI             SIMULATION
              │                 │                 │
              └─────────────────┼─────────────────┘
                                ▼
                              INTENT
                                │
                                ▼
                       PLANNING / PLACEMENT
                                │
                                ▼
                      SPATIAL + SEMANTIC
                         VALIDATION
                                │
                                ▼
                           TRANSACTION
                                │
                                ▼
                         WORLD STATE
                                │
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
                  Events     Snapshot    History
                     │          │
                     │          └──────┐
                     │                 ▼
                     │            SIMULATION
                     │                 │
                     │                 ▼
                     │            PREDICTION
                     │
                     ▼
                  UI / 3D
```

This is now a serious runtime architecture.

---

# 5.5A.11.40 The first implementation slice

Don't implement everything above at once.

The actual coding sequence should be:

### A — Time primitives

```text
world_time.dart
simulation_time.dart
world_clock.dart
simulation_clock.dart
```

### B — Temporal snapshot

```text
temporal_snapshot.dart
```

### C — Simulation system interface

```text
simulation_system.dart
simulation_context.dart
```

### D — Command buffer

```text
simulation_command_buffer.dart
```

### E — Simulation runner

```text
simulation_runner.dart
```

### F — One simple system

```text
motion_system.dart
```

### G — Simulation branch

```text
simulation_branch.dart
```

### H — Observation

```text
world_observation.dart
```

Don't implement prediction/AI yet.

---

# 5.5A.11.41 First end-to-end test

Create:

```text
Robot-01
```

with:

```text
position = (0,0,0)
velocity = (1,0,0)
```

Create:

```text
SimulationBranch
```

from the current world.

Run:

```text
dt = 1 second
```

Expected:

```text
T = 1

position = (1,0,0)
```

Run another:

```text
dt = 1
```

Expected:

```text
T = 2

position = (2,0,0)
```

Meanwhile:

```text
LIVE WORLD
position = (0,0,0)
```

must remain unchanged.

This single test verifies a very important architectural property:

> **Simulation cannot accidentally mutate the live digital twin.**

---

# 5.5A.11.42 Second test: simulation collision

Now put:

```text
Robot
position = 0
velocity = +X
```

and:

```text
Wall
position = 5
```

Run simulation.

At some point:

```text
Robot
→
→
→
Wall
```

The existing collision engine should detect:

```text
collision
```

and prevent the invalid transform transaction.

This proves:

```text
Simulation
    +
Spatial Kernel
```

are actually integrated rather than being separate systems.

---

# 5.5A.11.43 Third test: what-if scenario

Live world:

```text
10 trucks
```

Fork:

```text
Scenario A
```

Add:

```text
20 trucks
```

Run:

```text
30 minutes
```

Observe:

```text
queue length
dock utilization
parking occupancy
```

Then compare:

```text
Live baseline
vs
Scenario A
```

This is the first primitive form of **digital-twin scenario analysis**.

---

# 5.5A.11.44 What 5.5A.11 unlocks

After this step, the platform can conceptually support:

```text
✓ Live world state
✓ Historical snapshots
✓ Transactions
✓ Replay
✓ Simulation branches
✓ What-if scenarios
✓ Fixed timestep simulation
✓ Pluggable simulation systems
✓ Sensor observations
✓ Prediction branches
✓ Shared spatial/semantic validation
```

And importantly, these capabilities all use the same underlying world model.

---

# 5.5A.11.45 One architectural rule to keep

From this point onward, I strongly recommend this rule:

> **Nothing changes the world without going through the World Transaction Engine.**

That includes:

```text
User
AI
Simulation
Sensor
Automation
Import
Network synchronization
Game interaction
```

Everything becomes:

```text
Intent
 ↓
Change proposal
 ↓
Transaction
 ↓
Validation
 ↓
Commit
 ↓
Event
```

This single rule will protect the architecture as the project gets much more complex.

---

## Next: Step 5.5A.12 — State Machines, Behaviors & Rules

With time now available, the next layer should make entities **behave**, not merely move.

We'll introduce:

```text
Entity
   │
   ├── State
   ├── Behavior
   ├── Conditions
   ├── Actions
   └── Transitions
```

which lets the same engine model things like:

```text
Warehouse:
idle → picking → carrying → delivering

Restaurant:
available → reserved → occupied → cleaning

Factory:
idle → processing → completed → maintenance

Traffic:
stopped → accelerating → cruising → braking

Building:
unoccupied → occupied → overloaded → evacuated
```

The important part will be designing this as a **generic behavior/state-machine system**, rather than embedding warehouse/restaurant/factory logic into the core.
