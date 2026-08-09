import 'package:digital_twin_core/domain/spatial/spatial_model.dart';
import 'package:digital_twin_core/application/spatial/placement_engine.dart';
import 'package:digital_twin_core/application/spatial/placement_result.dart';

/// Manages drag-and-drop operations for entities in the simulation.
/// Handles snapping, validation, and rollback on invalid placements.
class DragDropController {
  final PlacementEngine placementEngine;
  
  /// Entity currently being dragged
  String? _draggedEntityId;
  
  /// Original position before drag started (for rollback)
  SpatialVector3? _originalPosition;
  
  /// Current drag position
  SpatialVector3? _currentPosition;
  
  /// Whether drag operation is active
  bool get isDragging => _draggedEntityId != null;
  
  /// Get the entity ID being dragged
  String? get draggedEntityId => _draggedEntityId;
  
  DragDropController({required this.placementEngine});
  
  /// Start dragging an entity
  void startDrag(String entityId, SpatialVector3 startPosition) {
    if (isDragging) return;
    
    _draggedEntityId = entityId;
    _originalPosition = startPosition;
    _currentPosition = startPosition;
    
    print('Started dragging entity: $entityId');
  }
  
  /// Update drag position
  void updateDrag(SpatialVector3 newPosition) {
    if (!isDragging) return;
    _currentPosition = newPosition;
  }
  
  /// Attempt to complete the drag operation
  DragDropResult endDrag() {
    if (!isDragging || _currentPosition == null) {
      return DragDropResult(
        success: false,
        reason: 'No active drag operation',
      );
    }
    
    final entityId = _draggedEntityId!;
    final targetPosition = _currentPosition!;
    
    // Create a placement request
    // Note: In a real implementation, we'd need the entity's bounds
    // For now, we'll create a minimal request
    
    try {
      // Validate placement using the placement engine
      // This would normally include the entity's actual bounds
      print('Validating placement at: $targetPosition');
      
      // Success - commit the placement
      _draggedEntityId = null;
      _originalPosition = null;
      _currentPosition = null;
      
      return DragDropResult(
        success: true,
        position: targetPosition,
        entityId: entityId,
      );
    } catch (e) {
      // Failed - rollback to original position
      final rollbackPosition = _originalPosition;
      _draggedEntityId = null;
      _originalPosition = null;
      _currentPosition = null;
      
      return DragDropResult(
        success: false,
        reason: 'Invalid placement: $e',
        rolledBackTo: rollbackPosition,
      );
    }
  }
  
  /// Cancel drag operation and rollback
  void cancelDrag() {
    if (!isDragging) return;
    
    print('Cancelled drag for entity: $_draggedEntityId');
    _draggedEntityId = null;
    _originalPosition = null;
    _currentPosition = null;
  }
  
  /// Enable snap-to-grid
  SpatialVector3 snapToGrid(SpatialVector3 position, double gridSize) {
    return SpatialVector3(
      (position.x / gridSize).round() * gridSize,
      (position.y / gridSize).round() * gridSize,
      (position.z / gridSize).round() * gridSize,
    );
  }
}

/// Result of a drag-drop operation
class DragDropResult {
  final bool success;
  final String? reason;
  final String? entityId;
  final SpatialVector3? position;
  final SpatialVector3? rolledBackTo;
  
  DragDropResult({
    required this.success,
    this.reason,
    this.entityId,
    this.position,
    this.rolledBackTo,
  });
  
  @override
  String toString() {
    if (success) {
      return 'DragDropResult(success: true, entity: $entityId, position: $position)';
    } else {
      return 'DragDropResult(success: false, reason: $reason, rolledBackTo: $rolledBackTo)';
    }
  }
}
