/// Callback type for event listeners
typedef EventListener = void Function(String eventType, Map<String, dynamic> data);

/// Pub/Sub event bus for decoupled communication between simulation, UI, and AI layers.
class EventBus {
  final Map<String, List<EventListener>> _listeners = {};
  final List<_QueuedEvent> _eventQueue = [];
  
  /// Subscribe to an event type
  void subscribe(String eventType, EventListener listener) {
    _listeners.putIfAbsent(eventType, () => []);
    _listeners[eventType]!.add(listener);
  }
  
  /// Unsubscribe from an event type
  void unsubscribe(String eventType, EventListener listener) {
    _listeners[eventType]?.remove(listener);
  }
  
  /// Unsubscribe from all events
  void unsubscribeAll(EventListener listener) {
    for (final eventType in _listeners.keys) {
      _listeners[eventType]?.remove(listener);
    }
  }
  
  /// Publish an event immediately
  void publish(String eventType, Map<String, dynamic> data) {
    final listeners = _listeners[eventType];
    if (listeners == null || listeners.isEmpty) return;
    
    for (final listener in listeners) {
      try {
        listener(eventType, data);
      } catch (e) {
        print('Error in event listener for $eventType: $e');
      }
    }
  }
  
  /// Queue an event for later processing
  void queue(String eventType, Map<String, dynamic> data) {
    _eventQueue.add(_QueuedEvent(eventType, data));
  }
  
  /// Process all queued events
  void processQueue() {
    while (_eventQueue.isNotEmpty) {
      final event = _eventQueue.removeAt(0);
      publish(event.eventType, event.data);
    }
  }
  
  /// Clear the event queue
  void clearQueue() {
    _eventQueue.clear();
  }
  
  /// Get the number of queued events
  int get queuedEventCount => _eventQueue.length;
  
  /// Check if there are listeners for an event type
  bool hasListeners(String eventType) {
    final listeners = _listeners[eventType];
    return listeners != null && listeners.isNotEmpty;
  }
  
  /// Get all registered event types
  List<String> get registeredEventTypes => _listeners.keys.toList();
}

/// Internal class for queued events
class _QueuedEvent {
  final String eventType;
  final Map<String, dynamic> data;
  
  _QueuedEvent(this.eventType, this.data);
}
