import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// [SceneNodeBuilder] implementation for crane entities.
///
/// Converts generic crane twin entities into scene nodes with
/// appropriate asset IDs based on crane type.
class CraneSceneNodeBuilder implements SceneNodeBuilder {
  const CraneSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'crane';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;
    final properties = entity.component('properties') as PropertiesComponent?;

    final craneType = properties?.get('type');
    final isMoving = properties?.get('is_moving');

    String? assetId;

    if (craneType is TwinEnum || craneType is TwinString) {
      final typeValue = craneType is TwinEnum ? craneType.value : craneType.value;
      assetId = _mapTypeToAsset(typeValue);
    } else {
      assetId = 'crane_default';
    }

    // Cranes might have animation state based on movement
    return SceneNode(
      id: entity.id.value,
      entityType: entity.type,
      position: spatial?.position ?? const Vector3(0, 0, 0),
      rotation: spatial?.rotation ?? const Vector3(0, 0, 0),
      scale: spatial?.scale ?? const Vector3(1, 1, 1),
      assetId: assetId,
    );
  }

  String _mapTypeToAsset(String typeValue) {
    switch (typeValue.toLowerCase()) {
      case 'quay':
      case 'ship_to_shore':
        return 'crane_quay';
      case 'rtg':
      case 'rubber_tired_gantry':
        return 'crane_rtg';
      case 'rmg':
      case 'rail_mounted_gantry':
        return 'crane_rmg';
      case 'straddle':
      case 'straddle_carrier':
        return 'crane_straddle';
      default:
        return 'crane_default';
    }
  }
}
