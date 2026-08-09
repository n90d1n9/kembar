import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// [SceneNodeBuilder] implementation for restaurant table entities.
///
/// Converts generic table twin entities into scene nodes with
/// appropriate visual representation based on occupancy and reservation status.
class RestaurantTableSceneNodeBuilder implements SceneNodeBuilder {
  const RestaurantTableSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'table';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;
    final properties = entity.component('properties') as PropertiesComponent?;

    final isOccupied = properties?.get('is_occupied');
    final isReserved = properties?.get('is_reserved');
    final tableSize = properties?.get('size');
    final partyCount = properties?.get('party_count');

    String? assetId;

    // Determine asset based on status
    if (isOccupied is TwinBoolean && isOccupied.value) {
      assetId = _getTableAsset(tableSize, 'occupied');
    } else if (isReserved is TwinBoolean && isReserved.value) {
      assetId = _getTableAsset(tableSize, 'reserved');
    } else {
      assetId = _getTableAsset(tableSize, 'available');
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

  String _getTableAsset(dynamic tableSize, String status) {
    final sizeStr = tableSize is TwinEnum || tableSize is TwinString
        ? (tableSize is TwinEnum ? tableSize.value : tableSize.value).toLowerCase()
        : 'default';

    switch (sizeStr) {
      case '2':
      case 'two':
      case 'small':
        return 'table_2_$status';
      case '4':
      case 'four':
      case 'medium':
        return 'table_4_$status';
      case '6':
      case 'six':
      case 'large':
        return 'table_6_$status';
      case '8':
      case 'eight':
      case 'xlarge':
        return 'table_8_$status';
      default:
        return 'table_default_$status';
    }
  }
}
