import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';
import 'container_spatial_mapper.dart';

/// Maps domain-specific [ContainerTwin] to generic [TwinEntity].
///
/// This is the bridge between the container-terminal domain model
/// and the platform-agnostic twin kernel.
class ContainerTwinMapper {
  final ContainerSpatialMapper spatialMapper;

  const ContainerTwinMapper({
    required this.spatialMapper,
  });

  TwinEntity toEntity(ContainerTwin container) {
    final position = spatialMapper.map(container);

    return TwinEntity(
      id: TwinEntityId(container.id.value),
      type: 'container',
      components: {
        'properties': _properties(container),
        'spatial': SpatialComponent(
          position: position,
        ),
      },
      updatedAt: container.lastUpdated,
      sourceId: 'container-repository',
    );
  }

  PropertiesComponent _properties(ContainerTwin container) {
    return PropertiesComponent(
      properties: {
        'size': TwinEnum(container.size.name),
        'status': TwinEnum(container.status.name),
        'weightKg': TwinNumber(container.weightKg),
        'lastUpdated': TwinDateTime(container.lastUpdated),
        if (container.ownerLine != null)
          'ownerLine': TwinString(container.ownerLine!),
      },
    );
  }
}
