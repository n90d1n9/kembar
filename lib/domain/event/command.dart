import 'package:digital_twin_core/domain/entity.dart';

/// Abstract base class for all commands in the command pattern.
/// Supports execute, undo, and redo operations.
abstract class Command {
  final String id;
  final DateTime timestamp;
  bool _executed = false;
  bool _undone = false;
  
  Command({String? id})
      : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = DateTime.now();
  
  /// Execute the command
  void execute();
  
  /// Undo the command (reverse the effect)
  void undo();
  
  /// Redo the command (re-execute after undo)
  void redo() {
    execute();
  }
  
  /// Whether this command has been executed
  bool get executed => _executed;
  
  /// Whether this command has been undone
  bool get undone => _undone;
  
  /// Mark command as executed
  void _markExecuted() {
    _executed = true;
    _undone = false;
  }
  
  /// Mark command as undone
  void _markUndone() {
    _undone = true;
  }
  
  /// Human-readable description of the command
  String get description;
}

/// Command to move an entity
class MoveEntityCommand extends Command {
  final Entity entity;
  final Map<String, double> fromPosition;
  final Map<String, double> toPosition;
  final Function(Map<String, double>) updateCallback;
  
  MoveEntityCommand({
    required this.entity,
    required this.fromPosition,
    required this.toPosition,
    required this.updateCallback,
  });
  
  @override
  void execute() {
    updateCallback(toPosition);
    _markExecuted();
  }
  
  @override
  void undo() {
    updateCallback(fromPosition);
    _markUndone();
  }
  
  @override
  String get description => 'Move ${entity.name} from $fromPosition to $toPosition';
}

/// Command to create an entity
class CreateEntityCommand extends Command {
  final Entity entity;
  final Function(Entity) addCallback;
  final Function(String) removeCallback;
  
  CreateEntityCommand({
    required this.entity,
    required this.addCallback,
    required this.removeCallback,
  });
  
  @override
  void execute() {
    addCallback(entity);
    _markExecuted();
  }
  
  @override
  void undo() {
    removeCallback(entity.id);
    _markUndone();
  }
  
  @override
  String get description => 'Create entity ${entity.name}';
}

/// Command to delete an entity
class DeleteEntityCommand extends Command {
  final Entity entity;
  final Function(String) removeCallback;
  final Function(Entity) addCallback;
  
  DeleteEntityCommand({
    required this.entity,
    required this.removeCallback,
    required this.addCallback,
  });
  
  @override
  void execute() {
    removeCallback(entity.id);
    _markExecuted();
  }
  
  @override
  void undo() {
    addCallback(entity);
    _markUndone();
  }
  
  @override
  String get description => 'Delete entity ${entity.name}';
}

/// Command to change entity state
class ChangeStateCommand extends Command {
  final Entity entity;
  final Map<String, dynamic> fromState;
  final Map<String, dynamic> toState;
  final Function(Map<String, dynamic>) updateCallback;
  
  ChangeStateCommand({
    required this.entity,
    required this.fromState,
    required this.toState,
    required this.updateCallback,
  });
  
  @override
  void execute() {
    updateCallback(toState);
    _markExecuted();
  }
  
  @override
  void undo() {
    updateCallback(fromState);
    _markUndone();
  }
  
  @override
  String get description => 'Change state of ${entity.name}';
}

/// Manages command execution with undo/redo support
class CommandManager {
  final List<Command> _history = [];
  int _currentIndex = -1;
  final int _maxHistorySize;
  
  CommandManager({this._maxHistorySize = 50});
  
  /// Execute a command
  void execute(Command command) {
    // Remove any redo commands if we're not at the end
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Add to history
    _history.add(command);
    _currentIndex++;
    
    // Execute the command
    command.execute();
    
    // Trim history if too large
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }
  
  /// Undo the last command
  bool undo() {
    if (_currentIndex < 0) return false;
    
    final command = _history[_currentIndex];
    command.undo();
    _currentIndex--;
    
    return true;
  }
  
  /// Redo the last undone command
  bool redo() {
    if (_currentIndex >= _history.length - 1) return false;
    
    _currentIndex++;
    final command = _history[_currentIndex];
    command.redo();
    
    return true;
  }
  
  /// Check if undo is available
  bool get canUndo => _currentIndex >= 0;
  
  /// Check if redo is available
  bool get canRedo => _currentIndex < _history.length - 1;
  
  /// Get the current position in history
  int get currentPosition => _currentIndex;
  
  /// Get the total history size
  int get historySize => _history.length;
  
  /// Clear all history
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }
  
  /// Get a description of the command at a specific index
  String? getCommandDescription(int index) {
    if (index < 0 || index >= _history.length) return null;
    return _history[index].description;
  }
}
