import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// [SceneNodeBuilder] implementation for parking spot entities.
///
/// Converts generic parking spot twin entities into scene nodes with
/// appropriate visual representation based on occupancy status.
class ParkingSpotSceneNodeBuilder implements SceneNodeBuilder {
  const ParkingSpotSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'parking_spot';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;
    final properties = entity.component('properties') as PropertiesComponent?;

    final isOccupied = properties?.get('is_occupied');
    final spotType = properties?.get('type');
    final vehicleType = properties?.get('vehicle_type');

    String? assetId;

    // Determine asset based on occupancy and type
    if (isOccupied is TwinBoolean && isOccupied.value) {
      assetId = _getOccupiedAsset(spotType, vehicleType);
    } else {
      assetId = _getEmptyAsset(spotType);
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

  String _getOccupiedAsset(dynamic spotType, dynamic vehicleType) {
    final typeStr = vehicleType is TwinEnum || vehicleType is TwinString
        ? (vehicleType is TwinEnum ? vehicleType.value : vehicleType.value).toLowerCase()
        : 'default';

    switch (typeStr) {
      case 'car':
        return 'parking_spot_occupied_car';
      case 'truck':
        return 'parking_spot_occupied_truck';
      case 'motorcycle':
        return 'parking_spot_occupied_motorcycle';
      case 'ev':
      case 'electric':
        return 'parking_spot_occupied_ev';
      default:
        return 'parking_spot_occupied_default';
    }
  }

  String _getEmptyAsset(dynamic spotType) {
    final typeStr = spotType is TwinEnum || spotType is TwinString
        ? (spotType is TwinEnum ? spotType.value : spotType.value).toLowerCase()
        : 'default';

    switch (typeStr) {
      case 'handicapped':
      case 'accessible':
        return 'parking_spot_empty_handicapped';
      case 'ev':
      case 'electric':
        return 'parking_spot_empty_ev';
      case 'compact':
        return 'parking_spot_empty_compact';
      case 'large':
      case 'truck':
        return 'parking_spot_empty_large';
      default:
        return 'parking_spot_empty_default';
    }
  }
}
