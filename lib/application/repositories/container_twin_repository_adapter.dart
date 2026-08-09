import '../../domain/core/twin_core.dart';
import '../../domain/entities/container_twin.dart';
import '../../domain/repositories/container_repository.dart';
import '../mappers/container_twin_mapper.dart';
import 'twin_repository.dart';

/// Adapter that converts ContainerRepository (domain-specific) into TwinRepository (generic).
/// 
/// This allows the container-terminal domain to plug into the platform-agnostic Twin Kernel.
/// 
/// The adapter handles:
/// - Converting ContainerTwin → TwinEntity via ContainerTwinMapper
/// - Detecting entity lifecycle (Created/Updated/Removed) from snapshots
/// - Emitting generic TwinEvents for the TwinRuntime to consume
class ContainerTwinRepositoryAdapter implements TwinRepository {
  final ContainerRepository source;
  final ContainerTwinMapper mapper;

  const ContainerTwinRepositoryAdapter({
    required this.source,
    required this.mapper,
  });

  @override
  Stream<TwinEvent> watch() async* {
    final knownIds = <String>{};

    await for (final containers in source.watchContainers(blockId: 'default')) {
      final currentIds = <String>{};

      for (final container in containers) {
        final entity = mapper.toEntity(container);
        final id = entity.id.value;

        currentIds.add(id);

        if (knownIds.contains(id)) {
          yield EntityUpdated(entity);
        } else {
          yield EntityCreated(entity);
        }
      }

      // Detect removed entities
      for (final removedId in knownIds.difference(currentIds)) {
        yield EntityRemoved(
          TwinEntityId(removedId),
        );
      }

      knownIds
        ..clear()
        ..addAll(currentIds);
    }
  }

  @override
  Future<List<TwinEntity>> fetchEntities({
    String? type,
  }) async {
    if (type != null && type != 'container') {
      return const [];
    }

    final containers = await source.fetchContainers(blockId: 'default');

    return containers
        .map(mapper.toEntity)
        .toList(growable: false);
  }
}
