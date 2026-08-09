import '../../domain/entities/container_twin.dart';
import '../../domain/entities/yard_block_layout.dart';
import '../mapping/container_position_mapper.dart';
import 'placed_container.dart';
import 'yard_bounding_box.dart';

/// Turns a list of container twins into placed, render-agnostic view
/// models. This is the "Twin state -> Scene" step, deliberately separated
/// from both the twin's own state (domain) and how it eventually gets
/// drawn (infrastructure/render) — single responsibility, easy to unit
/// test on its own.
class ContainerSceneBuilder {
  final ContainerPositionMapper mapper;

  const ContainerSceneBuilder(this.mapper);

  List<PlacedContainer> build({
    required List<ContainerTwin> containers,
    required YardBlockLayout layout,
    YardBoundingBox? visibleRegion,
  }) {
    final placed = <PlacedContainer>[];
    for (final container in containers) {
      if (visibleRegion != null && !visibleRegion.contains(container.slot)) {
        continue;
      }
      final basePosition = mapper.positionOf(container.slot, layout);
      placed.add(
        PlacedContainer(
          id: container.id.value,
          label: container.id.value,
          baseCenter: basePosition,
          lengthM: container.size.lengthM,
          widthM: container.size.widthM,
          heightM: container.size.heightM,
          rotationYDeg: layout.orientationDeg,
          status: container.status,
        ),
      );
    }
    return placed;
  }
}
