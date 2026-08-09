import 'package:digital_twin_core/domain/event/event_bus.dart';

/// Cross-Twin Event Bus for propagating events across federation boundaries
/// 
/// Enables event-driven communication between independent twins
/// (e.g., "Ship Delayed" in Port → "Truck Delayed" in Warehouse)
class CrossTwinEventBus {
  final EventBus _globalBus = EventBus();
  final Map<String, List<EventSubscription>> _twinSubscriptions = {};
  final Map<String, EventTransformationFn> _transformations = {};
  
  /// Function type for transforming events between twins
  typedef EventTransformationFn = dynamic Function(dynamic event);
  
  /// Subscribe a twin to global events
  void subscribeTwin(String twinId, String eventType, void Function(dynamic) handler) {
    final subscription = _globalBus.subscribe(eventType, handler);
    
    _twinSubscriptions.putIfAbsent(twinId, () => []);
    _twinSubscriptions[twinId]!.add(subscription);
    
    print('Twin $twinId subscribed to $eventType');
  }
  
  /// Unsubscribe a twin from all events
  void unsubscribeTwin(String twinId) {
    final subscriptions = _twinSubscriptions.remove(twinId);
    if (subscriptions != null) {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      print('Twin $twinId unsubscribed from all events');
    }
  }
  
  /// Register an event transformation rule
  void linkEvents({
    required String sourceTwin,
    required String sourceEventType,
    required String targetTwin,
    required String targetEventType,
    EventTransformationFn? transformation,
  }) {
    final key = '$sourceTwin:$sourceEventType->$targetTwin:$targetEventType';
    
    _transformations[key] = transformation ?? (event) => event;
    
    // Subscribe to source events and forward to target
    subscribeTwin(sourceTwin, sourceEventType, (event) {
      if (_transformations.containsKey(key)) {
        final transformed = _transformations[key]!(event);
        publish(targetTwin, targetEventType, transformed);
        print('Transformed and forwarded event: $sourceEventType → $targetEventType');
      }
    });
    
    print('Linked events: $key');
  }
  
  /// Publish an event from a specific twin
  void publish(String twinId, String eventType, dynamic data) {
    final event = _createEvent(twinId, eventType, data);
    _globalBus.publish(eventType, event);
  }
  
  /// Publish an event to all twins
  void broadcast(String eventType, dynamic data, {String? excludeTwin}) {
    final event = _createEvent('broadcast', eventType, data);
    
    for (final twinId in _twinSubscriptions.keys) {
      if (twinId != excludeTwin) {
        _globalBus.publish(eventType, event);
      }
    }
  }
  
  dynamic _createEvent(String twinId, String eventType, dynamic data) {
    return {
      'source_twin': twinId,
      'event_type': eventType,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
  }
  
  /// Get event statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_subscriptions': _twinSubscriptions.values.fold(0, (sum, list) => sum + list.length),
      'twin_count': _twinSubscriptions.length,
      'transformation_rules': _transformations.length,
      'twins': _twinSubscriptions.keys.toList(),
    };
  }
}

/// Event subscription handle for cancellation
class EventSubscription {
  final String eventType;
  final VoidCallback cancel;
  
  EventSubscription(this.eventType, this.cancel);
}
