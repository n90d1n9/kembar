/// Enum of supported gesture types
enum GestureType {
  tap,
  doubleTap,
  longPress,
  swipeUp,
  swipeDown,
  swipeLeft,
  swipeRight,
  pinchIn,
  pinchOut,
  rotate,
}

/// Represents a detected gesture event
class GestureEvent {
  final GestureType type;
  final double x;
  final double y;
  final double? magnitude; // For pinch/rotate
  final DateTime timestamp;
  
  GestureEvent({
    required this.type,
    required this.x,
    required this.y,
    this.magnitude,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() => 'GestureEvent(type: $type, pos: ($x, $y), magnitude: $magnitude)';
}

/// Callback types for gestures
typedef GestureCallback = void Function(GestureEvent event);

/// Interprets touch/mouse input as high-level gestures.
/// Supports tap, double-tap, long-press, swipe, pinch, and rotate.
class GestureHandler {
  /// Threshold for considering a movement as a swipe (pixels)
  final double swipeThreshold;
  
  /// Minimum duration for a long press (milliseconds)
  final int longPressDuration;
  
  /// Maximum time between taps for double-tap (milliseconds)
  final int doubleTapTimeout;
  
  /// Callbacks for different gestures
  GestureCallback? onTap;
  GestureCallback? onDoubleTap;
  GestureCallback? onLongPress;
  GestureCallback? onSwipe;
  GestureCallback? onPinch;
  GestureCallback? onRotate;
  
  /// State tracking
  bool _isTouching = false;
  double _startX = 0;
  double _startY = 0;
  double _lastX = 0;
  double _lastY = 0;
  DateTime? _touchStartTime;
  int _tapCount = 0;
  DateTime? _lastTapTime;
  
  /// Pinch state
  double? _initialPinchDistance;
  
  GestureHandler({
    this.swipeThreshold = 50.0,
    this.longPressDuration = 500,
    this.doubleTapTimeout = 300,
  });
  
  /// Handle touch/mouse down event
  void handleDown(double x, double y) {
    _isTouching = true;
    _startX = x;
    _startY = y;
    _lastX = x;
    _lastY = y;
    _touchStartTime = DateTime.now();
    
    // Check for double-tap
    final now = DateTime.now();
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!).inMilliseconds < doubleTapTimeout) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
  }
  
  /// Handle touch/mouse move event
  void handleMove(double x, double y) {
    if (!_isTouching) return;
    
    final deltaX = x - _lastX;
    final deltaY = y - _lastY;
    
    _lastX = x;
    _lastY = y;
    
    // Check for swipe during move
    final totalDeltaX = x - _startX;
    final totalDeltaY = y - _startY;
    final distance = _distance(totalDeltaX, totalDeltaY);
    
    if (distance > swipeThreshold) {
      // Will be finalized on handleUp
    }
  }
  
  /// Handle touch/mouse up event
  void handleUp(double x, double y) {
    if (!_isTouching) return;
    
    final now = DateTime.now();
    final duration = now.difference(_touchStartTime!);
    final deltaX = x - _startX;
    final deltaY = y - _startY;
    final distance = _distance(deltaX, deltaY);
    
    _isTouching = false;
    
    // Determine gesture type
    GestureType? gestureType;
    
    // Long press
    if (duration.inMilliseconds >= longPressDuration && distance < swipeThreshold) {
      gestureType = GestureType.longPress;
      onLongPress?.call(GestureEvent(
        type: gestureType,
        x: _startX,
        y: _startY,
        timestamp: _touchStartTime,
      ));
    }
    // Swipe
    else if (distance >= swipeThreshold) {
      gestureType = _getSwipeDirection(deltaX, deltaY);
      onSwipe?.call(GestureEvent(
        type: gestureType,
        x: _startX,
        y: _startY,
        magnitude: distance,
      ));
    }
    // Tap or Double-tap
    else if (distance < swipeThreshold) {
      if (_tapCount >= 2) {
        gestureType = GestureType.doubleTap;
        onDoubleTap?.call(GestureEvent(
          type: gestureType,
          x: x,
          y: y,
        ));
        _tapCount = 0;
        _lastTapTime = null;
      } else {
        gestureType = GestureType.tap;
        onTap?.call(GestureEvent(
          type: gestureType,
          x: x,
          y: y,
        ));
        _lastTapTime = now;
      }
    }
    
    _touchStartTime = null;
  }
  
  /// Handle two-finger pinch gesture
  void handlePinch(double distance) {
    if (_initialPinchDistance == null) {
      _initialPinchDistance = distance;
    } else {
      final delta = distance - _initialPinchDistance!;
      
      if (delta.abs() > 10) { // Pinch threshold
        final gestureType = delta > 0 ? GestureType.pinchOut : GestureType.pinchIn;
        onPinch?.call(GestureEvent(
          type: gestureType,
          x: 0,
          y: 0,
          magnitude: delta.abs(),
        ));
        _initialPinchDistance = distance;
      }
    }
  }
  
  /// Handle two-finger rotate gesture
  void handleRotate(double angle) {
    if (angle.abs() > 5) { // Rotate threshold (degrees)
      onRotate?.call(GestureEvent(
        type: GestureType.rotate,
        x: 0,
        y: 0,
        magnitude: angle,
      ));
    }
  }
  
  /// Reset all gesture state
  void reset() {
    _isTouching = false;
    _tapCount = 0;
    _lastTapTime = null;
    _touchStartTime = null;
    _initialPinchDistance = null;
  }
  
  /// Get swipe direction from delta values
  GestureType _getSwipeDirection(double deltaX, double deltaY) {
    if (deltaX.abs() > deltaY.abs()) {
      return deltaX > 0 ? GestureType.swipeRight : GestureType.swipeLeft;
    } else {
      return deltaY > 0 ? GestureType.swipeDown : GestureType.swipeUp;
    }
  }
  
  /// Calculate distance between two points
  double _distance(double dx, double dy) {
    return (dx * dx + dy * dy).sqrt();
  }
}

// Extension to add sqrt to double
extension on double {
  double sqrt() {
    if (this < 0) return double.nan;
    if (this == 0) return 0;
    
    double guess = this / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + this / guess) / 2;
    }
    return guess;
  }
}
