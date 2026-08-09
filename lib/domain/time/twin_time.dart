/// Time modes for the digital twin runtime
enum TimeMode {
  /// Real-time live mode
  live,

  /// Paused state
  paused,

  /// Playing back historical data
  replay,

  /// Running a simulation
  simulation,

  /// Fast-forward mode
  fastForward,

  /// Jumping to arbitrary time points
  timeTravel,
}

/// Manages time in the digital twin
/// 
/// Supports both wall-clock time and simulation time,
/// enabling features like:
/// - Live monitoring
/// - Historical replay
/// - Future simulation
/// - What-if scenarios
class TwinTime {
  /// Current real-world time
  final DateTime wallClock;

  /// Current simulation time (relative to simulation start)
  final Duration simulationTime;

  /// Time scale factor (1.0 = real-time, 2.0 = 2x speed, 0.5 = half speed)
  final double speed;

  /// Current time mode
  final TimeMode mode;

  /// Start time of the simulation/replay
  final DateTime? startTime;

  /// End time for replay/simulation
  final DateTime? endTime;

  const TwinTime({
    required this.wallClock,
    this.simulationTime = Duration.zero,
    this.speed = 1.0,
    this.mode = TimeMode.live,
    this.startTime,
    this.endTime,
  });

  /// Create a TwinTime instance for live mode
  factory TwinTime.live() {
    return TwinTime(
      wallClock: DateTime.now(),
      mode: TimeMode.live,
      speed: 1.0,
    );
  }

  /// Create a TwinTime instance for paused state
  factory TwinTime.paused({
    DateTime? wallClock,
    Duration simulationTime = Duration.zero,
  }) {
    return TwinTime(
      wallClock: wallClock ?? DateTime.now(),
      simulationTime: simulationTime,
      mode: TimeMode.paused,
      speed: 0.0,
    );
  }

  /// Create a TwinTime instance for replay mode
  factory TwinTime.replay({
    required DateTime startTime,
    required DateTime endTime,
    double speed = 1.0,
  }) {
    return TwinTime(
      wallClock: DateTime.now(),
      simulationTime: Duration.zero,
      mode: TimeMode.replay,
      speed: speed,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Create a TwinTime instance for simulation mode
  factory TwinTime.simulation({
    DateTime? startTime,
    double speed = 1.0,
  }) {
    return TwinTime(
      wallClock: DateTime.now(),
      simulationTime: Duration.zero,
      mode: TimeMode.simulation,
      speed: speed,
      startTime: startTime ?? DateTime.now(),
    );
  }

  /// Get the current effective time based on mode
  DateTime get effectiveTime {
    switch (mode) {
      case TimeMode.live:
        return wallClock;
      case TimeMode.paused:
        return wallClock;
      case TimeMode.replay:
      case TimeMode.simulation:
      case TimeMode.fastForward:
      case TimeMode.timeTravel:
        if (startTime == null) return wallClock;
        return startTime!.add(simulationTime);
    }
  }

  /// Check if currently in a playback mode (not live)
  bool get isPlayback => mode != TimeMode.live && mode != TimeMode.paused;

  /// Check if time is advancing
  bool get isRunning => mode != TimeMode.paused && speed > 0;

  /// Calculate next simulation time step
  Duration step(Duration delta) {
    if (!isRunning) return simulationTime;
    return simulationTime + (delta * speed);
  }

  /// Check if we've reached the end time
  bool hasReachedEnd() {
    if (endTime == null || startTime == null) return false;
    return effectiveTime.isAfter(endTime!);
  }

  /// Progress time by a delta
  TwinTime progress(Duration delta) {
    if (!isRunning) return this;

    final newSimulationTime = step(delta);
    final newWallClock = wallClock.add(delta);

    return copyWith(
      wallClock: newWallClock,
      simulationTime: newSimulationTime,
    );
  }

  /// Set a specific time point (for time travel)
  TwinTime setTime(DateTime time) {
    if (startTime == null) {
      return copyWith(
        wallClock: time,
        mode: TimeMode.timeTravel,
      );
    }

    final newSimulationTime = time.difference(startTime!);
    return copyWith(
      wallClock: time,
      simulationTime: newSimulationTime,
      mode: TimeMode.timeTravel,
    );
  }

  /// Change the speed
  TwinTime setSpeed(double newSpeed) {
    return copyWith(speed: newSpeed.clamp(0.0, 1000.0));
  }

  /// Pause time
  TwinTime pause() {
    return copyWith(mode: TimeMode.paused, speed: 0.0);
  }

  /// Resume time
  TwinTime resume() {
    return copyWith(
      mode: mode == TimeMode.replay ? TimeMode.replay : TimeMode.simulation,
      speed: speed > 0 ? speed : 1.0,
    );
  }

  TwinTime copyWith({
    DateTime? wallClock,
    Duration? simulationTime,
    double? speed,
    TimeMode? mode,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TwinTime(
      wallClock: wallClock ?? this.wallClock,
      simulationTime: simulationTime ?? this.simulationTime,
      speed: speed ?? this.speed,
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  String toString() {
    return 'TwinTime(mode: $mode, wall: $wallClock, sim: $simulationTime, speed: ${speed}x)';
  }
}
