import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// [SceneNodeBuilder] implementation for warehouse pallet/rack entities.
///
/// Converts generic warehouse storage entities into scene nodes with
/// appropriate visual representation based on fill level and type.
class WarehouseStorageSceneNodeBuilder implements SceneNodeBuilder {
  const WarehouseStorageSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'storage_location' || 
           entity.type == 'rack' || 
           entity.type == 'pallet_position';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;
    final properties = entity.component('properties') as PropertiesComponent?;

    final isEmpty = properties?.get('is_empty');
    final fillLevel = properties?.get('fill_level');
    final locationType = properties?.get('location_type');

    String? assetId;

    // Determine asset based on occupancy
    if (isEmpty is TwinBoolean && isEmpty.value) {
      assetId = _getEmptyAsset(locationType);
    } else if (fillLevel is TwinNumber) {
      assetId = _getPartialAsset(locationType, fillLevel.value);
    } else {
      assetId = _getFullAsset(locationType);
    }

    return SceneNode(
      id: entity.id.value,
      entityType: entity.type,
      position: spatial?.position ?? const Vector3(0, 0, 0),
      rotation: spatial?.rotation ?? const Vector3(0, 0, 0),
      scale: spatial?.scale ?? const Vector3(1, 1, 1),
      assetId: assetId,
    );
  }

  String _getEmptyAsset(dynamic locationType) {
    final typeStr = locationType is TwinEnum || locationType is TwinString
        ? (locationType is TwinEnum ? locationType.value : locationType.value).toLowerCase()
        : 'default';

    switch (typeStr) {
      case 'floor':
      case 'ground':
        return 'warehouse_floor_empty';
      case 'rack_low':
        return 'warehouse_rack_low_empty';
      case 'rack_mid':
        return 'warehouse_rack_mid_empty';
      case 'rack_high':
        return 'warehouse_rack_high_empty';
      default:
        return 'warehouse_storage_empty';
    }
  }

  String _getPartialAsset(dynamic locationType, double fillLevel) {
    if (fillLevel < 0.25) {
      return _getEmptyAsset(locationType);
    } else if (fillLevel < 0.75) {
      return _getHalfAsset(locationType);
    } else {
      return _getFullAsset(locationType);
    }
  }

  String _getHalfAsset(dynamic locationType) {
    final typeStr = locationType is TwinEnum || locationType is TwinString
        ? (locationType is TwinEnum ? locationType.value : locationType.value).toLowerCase()
        : 'default';

    switch (typeStr) {
      case 'rack_low':
        return 'warehouse_rack_low_half';
      case 'rack_mid':
        return 'warehouse_rack_mid_half';
      case 'rack_high':
        return 'warehouse_rack_high_half';
      default:
        return 'warehouse_storage_half';
    }
  }

  String _getFullAsset(dynamic locationType) {
    final typeStr = locationType is TwinEnum || locationType is TwinString
        ? (locationType is TwinEnum ? locationType.value : locationType.value).toLowerCase()
        : 'default';

    switch (typeStr) {
      case 'floor':
      case 'ground':
        return 'warehouse_floor_full';
      case 'rack_low':
        return 'warehouse_rack_low_full';
      case 'rack_mid':
        return 'warehouse_rack_mid_full';
      case 'rack_high':
        return 'warehouse_rack_high_full';
      default:
        return 'warehouse_storage_full';
    }
  }
}
