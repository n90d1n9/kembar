import 'dart:async';

import '../../domain/entities/container_twin.dart';
import '../../domain/repositories/container_repository.dart';
import '../../domain/value_objects/container_id.dart';
import '../../domain/value_objects/container_size.dart';
import '../../domain/value_objects/yard_slot.dart';
import '../entities/container_status.dart';

/// Fake ContainerRepository for testing.
/// 
/// Allows manual emission of container snapshots to test adapters and providers.
class FakeContainerRepository implements ContainerRepository {
  final StreamController<List<ContainerTwin>> _controller =
      StreamController<List<ContainerTwin>>.broadcast();

  List<ContainerTwin> _containers = [];

  @override
  Stream<List<ContainerTwin>> watchContainers({required String blockId}) {
    return _controller.stream;
  }

  @override
  Future<List<ContainerTwin>> fetchContainers({required String blockId}) async {
    return _containers;
  }

  /// Emit a new snapshot of containers.
  Future<void> emit(List<ContainerTwin> containers) async {
    _containers = containers;
    _controller.add(containers);
  }

  /// Add a single container to the current snapshot.
  Future<void> add(ContainerTwin container) async {
    _containers = [..._containers, container];
    _controller.add(_containers);
  }

  /// Remove a container from the current snapshot.
  Future<void> remove(ContainerId id) async {
    _containers = _containers.where((c) => c.id != id).toList();
    _controller.add(_containers);
  }

  /// Clear all containers.
  Future<void> clear() async {
    _containers = [];
    _controller.add(_containers);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Helper to create test ContainerTwin instances.
class TestContainerBuilder {
  String _id = 'TEST001';
  IsoContainerSize _size = IsoContainerSize.size20ft;
  YardSlot? _slot;
  ContainerStatus _status = ContainerStatus.stored;
  double _weightKg = 10000.0;
  String? _ownerLine;
  DateTime _lastUpdated = DateTime.now();

  TestContainerBuilder withId(String id) {
    _id = id;
    return this;
  }

  TestContainerBuilder withSize(IsoContainerSize size) {
    _size = size;
    return this;
  }

  TestContainerBuilder withSlot(YardSlot slot) {
    _slot = slot;
    return this;
  }

  TestContainerBuilder withStatus(ContainerStatus status) {
    _status = status;
    return this;
  }

  TestContainerBuilder withWeight(double weightKg) {
    _weightKg = weightKg;
    return this;
  }

  TestContainerBuilder withOwner(String? ownerLine) {
    _ownerLine = ownerLine;
    return this;
  }

  TestContainerBuilder withLastUpdated(DateTime lastUpdated) {
    _lastUpdated = lastUpdated;
    return this;
  }

  ContainerTwin build() {
    return ContainerTwin(
      id: ContainerId(_id),
      size: _size,
      slot: _slot ?? const YardSlot(bay: 1, row: 1, tier: 0),
      status: _status,
      weightKg: _weightKg,
      ownerLine: _ownerLine,
      lastUpdated: _lastUpdated,
    );
  }
}
