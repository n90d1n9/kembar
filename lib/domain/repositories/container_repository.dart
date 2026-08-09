import '../entities/container_twin.dart';

/// Source of container twin data for one yard block. The "live" nature of
/// a digital twin comes from [watchContainers] — a real implementation
/// would back this with a WebSocket/event-bus subscription instead of the
/// polling fake used for the demo.
abstract class ContainerRepository {
  Stream<List<ContainerTwin>> watchContainers({required String blockId});

  Future<List<ContainerTwin>> fetchContainers({required String blockId});
}
