/// Advanced time control for simulation with pause, step, speed control, and rewind.
class TimeWarp {
  /// Current simulation time in seconds
  double currentTime = 0.0;
  
  /// Speed multiplier (1.0 = real-time, 2.0 = 2x speed, 0.5 = half speed)
  double speedMultiplier = 1.0;
  
  /// Whether simulation is paused
  bool isPaused = false;
  
  /// Whether rewinding
  bool isRewinding = false;
  
  /// Rewind speed multiplier
  double rewindSpeed = 1.0;
  
  /// Callback when time changes
  Function(double time)? onTimeChanged;
  
  /// History of states for rewinding (simplified - just timestamps here)
  final List<double> _timeHistory = [];
  final int _maxHistorySize;
  
  TimeWarp({this._maxHistorySize = 1000});
  
  /// Get the actual delta time to apply based on speed and pause state
  double getDeltaTime(double baseDeltaTime) {
    if (isPaused) return 0.0;
    
    if (isRewinding) {
      return -baseDeltaTime * rewindSpeed;
    }
    
    return baseDeltaTime * speedMultiplier;
  }
  
  /// Check if time can be stepped
  bool get canStep => !isPaused;
  
  /// Advance time by a specific amount
  void advanceTime(double deltaTime) {
    final newTime = currentTime + deltaTime;
    if (newTime < 0) {
      currentTime = 0.0;
    } else {
      currentTime = newTime;
    }
    
    // Record history for potential rewind
    _recordHistory();
    
    onTimeChanged?.call(currentTime);
  }
  
  /// Set time to a specific value
  void setTime(double newTime) {
    if (newTime < 0) {
      currentTime = 0.0;
    } else {
      currentTime = newTime;
    }
    
    _recordHistory();
    onTimeChanged?.call(currentTime);
  }
  
  /// Pause the simulation
  void pause() {
    isPaused = true;
    print('Simulation paused at t=${currentTime.toStringAsFixed(2)}s');
  }
  
  /// Resume the simulation
  void resume() {
    isPaused = false;
    isRewinding = false;
    print('Simulation resumed at ${speedMultiplier}x speed');
  }
  
  /// Toggle pause state
  void togglePause() {
    if (isPaused) {
      resume();
    } else {
      pause();
    }
  }
  
  /// Set simulation speed
  void setSpeed(double multiplier) {
    if (multiplier <= 0) {
      throw ArgumentError('Speed multiplier must be positive');
    }
    speedMultiplier = multiplier;
    print('Speed set to ${speedMultiplier}x');
  }
  
  /// Step forward by one frame (useful when paused)
  void stepForward(double frameTime) {
    if (!isPaused) return;
    
    advanceTime(frameTime);
  }
  
  /// Start rewinding
  void startRewind({double speed = 1.0}) {
    isRewinding = true;
    isPaused = false;
    rewindSpeed = speed;
    print('Rewinding at ${rewindSpeed}x speed');
  }
  
  /// Stop rewinding
  void stopRewind() {
    isRewinding = false;
    print('Stopped rewinding');
  }
  
  /// Rewind by a specific amount
  void rewindBy(double seconds) {
    setTime(currentTime - seconds);
  }
  
  /// Rewind to a specific time
  void rewindTo(double targetTime) {
    setTime(targetTime);
  }
  
  /// Fast forward by a specific amount
  void fastForwardBy(double seconds) {
    setTime(currentTime + seconds);
  }
  
  /// Reset time to zero
  void reset() {
    currentTime = 0.0;
    isPaused = false;
    isRewinding = false;
    speedMultiplier = 1.0;
    _timeHistory.clear();
    print('Time reset to 0');
    onTimeChanged?.call(0.0);
  }
  
  /// Get formatted time string (MM:SS.ms)
  String get formattedTime {
    final minutes = (currentTime / 60).floor();
    final seconds = (currentTime % 60).floor();
    final milliseconds = ((currentTime * 100) % 100).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }
  
  /// Record current time in history
  void _recordHistory() {
    _timeHistory.add(currentTime);
    
    // Trim history if too large
    if (_timeHistory.length > _maxHistorySize) {
      _timeHistory.removeAt(0);
    }
  }
  
  /// Get number of recorded time states
  int get historySize => _timeHistory.length;
  
  /// Clear time history
  void clearHistory() {
    _timeHistory.clear();
  }
}
