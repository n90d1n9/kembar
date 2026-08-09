import 'package:digital_twin_core/domain/entity.dart';

/// Enum of available interaction tools
enum ToolType {
  select,
  move,
  rotate,
  scale,
  spawn,
  delete,
}

/// Abstract base class for all tools
abstract class Tool {
  String get name;
  ToolType get type;
  
  void activate();
  void deactivate();
  bool handleMouseDown(double x, double y);
  bool handleMouseUp(double x, double y);
  bool handleMouseMove(double x, double y, double deltaX, double deltaY);
}

/// Select tool - selects entities
class SelectTool implements Tool {
  Entity? selectedEntity;
  
  @override
  String get name => 'Select';
  
  @override
  ToolType get type => ToolType.select;
  
  @override
  void activate() => print('Select tool activated');
  
  @override
  void deactivate() {
    selectedEntity = null;
    print('Select tool deactivated');
  }
  
  @override
  bool handleMouseDown(double x, double y) {
    // Hit test and select entity
    print('Select tool: mouse down at ($x, $y)');
    return true;
  }
  
  @override
  bool handleMouseUp(double x, double y) => false;
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) => false;
}

/// Move tool - moves selected entities
class MoveTool implements Tool {
  Entity? targetEntity;
  bool _isDragging = false;
  
  @override
  String get name => 'Move';
  
  @override
  ToolType get type => ToolType.move;
  
  @override
  void activate() => print('Move tool activated');
  
  @override
  void deactivate() {
    targetEntity = null;
    _isDragging = false;
    print('Move tool deactivated');
  }
  
  @override
  bool handleMouseDown(double x, double y) {
    if (targetEntity != null) {
      _isDragging = true;
      print('Move tool: started dragging ${targetEntity!.name}');
      return true;
    }
    return false;
  }
  
  @override
  bool handleMouseUp(double x, double y) {
    if (_isDragging) {
      _isDragging = false;
      print('Move tool: finished dragging');
      return true;
    }
    return false;
  }
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) {
    if (_isDragging && targetEntity != null) {
      print('Move tool: moving ${targetEntity!.name} by ($deltaX, $deltaY)');
      return true;
    }
    return false;
  }
}

/// Rotate tool - rotates selected entities
class RotateTool implements Tool {
  Entity? targetEntity;
  
  @override
  String get name => 'Rotate';
  
  @override
  ToolType get type => ToolType.rotate;
  
  @override
  void activate() => print('Rotate tool activated');
  
  @override
  void deactivate() {
    targetEntity = null;
    print('Rotate tool deactivated');
  }
  
  @override
  bool handleMouseDown(double x, double y) {
    if (targetEntity != null) {
      print('Rotate tool: started rotating ${targetEntity!.name}');
      return true;
    }
    return false;
  }
  
  @override
  bool handleMouseUp(double x, double y) => false;
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) {
    if (targetEntity != null) {
      final rotationAngle = deltaX * 2.0; // Sensitivity factor
      print('Rotate tool: rotating ${targetEntity!.name} by $rotationAngle radians');
      return true;
    }
    return false;
  }
}

/// Scale tool - scales selected entities
class ScaleTool implements Tool {
  Entity? targetEntity;
  
  @override
  String get name => 'Scale';
  
  @override
  ToolType get type => ToolType.scale;
  
  @override
  void activate() => print('Scale tool activated');
  
  @override
  void deactivate() {
    targetEntity = null;
    print('Scale tool deactivated');
  }
  
  @override
  bool handleMouseDown(double x, double y) {
    if (targetEntity != null) {
      print('Scale tool: started scaling ${targetEntity!.name}');
      return true;
    }
    return false;
  }
  
  @override
  bool handleMouseUp(double x, double y) => false;
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) {
    if (targetEntity != null) {
      final scaleFactor = 1.0 + (deltaY * 0.01); // Sensitivity factor
      print('Scale tool: scaling ${targetEntity!.name} by $scaleFactor');
      return true;
    }
    return false;
  }
}

/// Spawn tool - creates new entities
class SpawnTool implements Tool {
  String? entityTypeToSpawn;
  Map<String, dynamic>? spawnParams;
  
  @override
  String get name => 'Spawn';
  
  @override
  ToolType get type => ToolType.spawn;
  
  @override
  void activate() => print('Spawn tool activated');
  
  @override
  void deactivate() {
    print('Spawn tool deactivated');
  }
  
  @override
  bool handleMouseDown(double x, double y) {
    if (entityTypeToSpawn != null) {
      print('Spawn tool: spawning $entityTypeToSpawn at ($x, $y)');
      return true;
    }
    return false;
  }
  
  @override
  bool handleMouseUp(double x, double y) => false;
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) => false;
}

/// Delete tool - removes entities
class DeleteTool implements Tool {
  @override
  String get name => 'Delete';
  
  @override
  ToolType get type => ToolType.delete;
  
  @override
  void activate() => print('Delete tool activated');
  
  @override
  void deactivate() => print('Delete tool deactivated');
  
  @override
  bool handleMouseDown(double x, double y) {
    print('Delete tool: click to delete at ($x, $y)');
    return true;
  }
  
  @override
  bool handleMouseUp(double x, double y) => false;
  
  @override
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) => false;
}

/// Manages active tools and tool switching
class ToolManager {
  final Map<ToolType, Tool> _tools = {};
  Tool? _activeTool;
  
  /// Register a tool
  void registerTool(Tool tool) {
    _tools[tool.type] = tool;
  }
  
  /// Get a tool by type
  Tool? getTool(ToolType type) => _tools[type];
  
  /// Get the active tool
  Tool? get activeTool => _activeTool;
  
  /// Activate a tool
  void activateTool(ToolType type) {
    // Deactivate current tool
    _activeTool?.deactivate();
    
    // Activate new tool
    final newTool = _tools[type];
    if (newTool != null) {
      _activeTool = newTool;
      newTool.activate();
      print('Activated tool: ${newTool.name}');
    }
  }
  
  /// Deactivate all tools
  void deactivateAll() {
    _activeTool?.deactivate();
    _activeTool = null;
  }
  
  /// Handle mouse down event
  bool handleMouseDown(double x, double y) {
    return _activeTool?.handleMouseDown(x, y) ?? false;
  }
  
  /// Handle mouse up event
  bool handleMouseUp(double x, double y) {
    return _activeTool?.handleMouseUp(x, y) ?? false;
  }
  
  /// Handle mouse move event
  bool handleMouseMove(double x, double y, double deltaX, double deltaY) {
    return _activeTool?.handleMouseMove(x, y, deltaX, deltaY) ?? false;
  }
  
  /// Set parameters for spawn tool
  void setSpawnParams(String entityType, Map<String, dynamic> params) {
    final spawnTool = _tools[ToolType.spawn] as SpawnTool?;
    if (spawnTool != null) {
      spawnTool.entityTypeToSpawn = entityType;
      spawnTool.spawnParams = params;
    }
  }
  
  /// Set target entity for move/rotate/scale tools
  void setTargetEntity(Entity? entity) {
    if (_activeTool is MoveTool) {
      (_activeTool as MoveTool).targetEntity = entity;
    } else if (_activeTool is RotateTool) {
      (_activeTool as RotateTool).targetEntity = entity;
    } else if (_activeTool is ScaleTool) {
      (_activeTool as ScaleTool).targetEntity = entity;
    }
  }
}
