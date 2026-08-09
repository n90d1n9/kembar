import '../../domain/core/twin_core.dart';
import '../../domain/scene/scene_node.dart';
import 'scene_node_builder.dart';

/// [SceneNodeBuilder] implementation for container entities.
///
/// Converts generic container twin entities into scene nodes with
/// appropriate asset IDs based on container size.
class ContainerSceneNodeBuilder implements SceneNodeBuilder {
  const ContainerSceneNodeBuilder();

  @override
  bool supports(TwinEntity entity) {
    return entity.type == 'container';
  }

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;

    final properties = entity.component('properties') as PropertiesComponent?;

    final size = properties?.get('size');

    String? assetId;

    // Map TwinEnum values to asset IDs
    if (size is TwinEnum) {
      assetId = _mapSizeToAsset(sizes.value);
    } else if (size is String) {
      assetId = _mapSizeToAsset(size);
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

  String _mapSizeToAsset(String sizeValue) {
    switch (sizeValue.toLowerCase()) {
      case '20ft':
      case 'twenty':
        return 'container_20ft';
      case '40ft':
      case 'forty':
        return 'container_40ft';
      case '45ft':
      case 'fortyfive':
        return 'container_45ft';
      case '20ft_highcube':
      case '20ft_high_cube':
        return 'container_20ft_hc';
      case '40ft_highcube':
      case '40ft_high_cube':
        return 'container_40ft_hc';
      default:
        return 'container_default';
    }
  }
}
