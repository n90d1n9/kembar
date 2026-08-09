import 'dart:async';
import 'dart:math' as math;

import '../../domain/entities/container_status.dart';
import '../../domain/entities/container_twin.dart';
import '../../domain/repositories/container_repository.dart';
import '../../domain/value_objects/container_id.dart';
import '../../domain/value_objects/container_size.dart';
import '../../domain/value_objects/yard_slot.dart';

/// Generates a synthetic but internally-consistent yard occupancy and then
/// mutates a random container's status every few seconds, so the "living,
/// synchronized" nature of a digital twin is visible without a real
/// backend. Bay/row ranges match FakeYardLayoutRepository's block "A" —
/// a real repository wouldn't need to know layout bounds at all, since it
/// would just report whatever containers actually exist.
///
/// Note: the periodic timers here are never cancelled, which is fine for
/// this demo's single long-lived screen but would leak in a real app —
/// a production repository should tie its update source's lifetime to
/// subscriber count (e.g. cancel in the StreamController's onCancel).
class FakeContainerRepository implements ContainerRepository {
  final _random = math.Random(7);
  final Map<String, List<ContainerTwin>> _byBlock = {};
  final Map<String, StreamController<List<ContainerTwin>>> _controllers = {};

  List<ContainerTwin> _seed(String blockId) {
    final containers = <ContainerTwin>[];
    var idCounter = 1;
    for (var bay = 1; bay <= 20; bay++) {
      for (var row = 1; row <= 6; row++) {
        final stackHeight = _random.nextInt(4); // 0..3 containers stacked here
        for (var tier = 1; tier <= stackHeight; tier++) {
          if (_random.nextDouble() > 0.85) continue; // occasional gaps
          containers.add(
            ContainerTwin(
              id: ContainerId('DEMO${idCounter.toString().padLeft(7, '0')}'),
              size: _random.nextBool() ? IsoContainerSize.ft40 : IsoContainerSize.ft20,
              slot: YardSlot(blockId: blockId, bay: bay, row: row, tier: tier),
              status: ContainerStatus.values[_random.nextInt(ContainerStatus.values.length)],
              weightKg: (4000 + _random.nextInt(22000)).toDouble(),
              lastUpdated: DateTime.now(),
            ),
          );
          idCounter++;
        }
      }
    }
    return containers;
  }

  @override
  Stream<List<ContainerTwin>> watchContainers({required String blockId}) {
    final existing = _controllers[blockId];
    if (existing != null) return existing.stream;

    _byBlock[blockId] = _seed(blockId);

    // Seeding from `onListen` (rather than e.g. scheduleMicrotask right
    // after creating the controller) is deliberate: onListen fires exactly
    // when a subscriber attaches — whenever that happens — instead of
    // relying on an assumption about how soon after this method returns
    // the caller (Riverpod's StreamProvider) actually calls .listen().
    // Directly calling controller.add() *inside* onListen isn't safe
    // (the controller is still finishing its own setup), so the emission
    // itself is still deferred by one microtask — but the *decision* to
    // emit now happens at the right moment, not an assumed one.
    late final StreamController<List<ContainerTwin>> controller;
    controller = StreamController<List<ContainerTwin>>.broadcast(
      onListen: () {
        final current = _byBlock[blockId];
        if (current != null) {
          scheduleMicrotask(() {
            if (!controller.isClosed) controller.add(current);
          });
        }
      },
    );
    _controllers[blockId] = controller;

    Timer.periodic(const Duration(seconds: 6), (_) => _mutate(blockId));

    return controller.stream;
  }

  void _mutate(String blockId) {
    final list = _byBlock[blockId];
    final controller = _controllers[blockId];
    if (list == null || list.isEmpty || controller == null || controller.isClosed) return;

    final index = _random.nextInt(list.length);
    final current = list[index];
    final next = current.copyWith(
      status: ContainerStatus.values[_random.nextInt(ContainerStatus.values.length)],
      lastUpdated: DateTime.now(),
    );
    final updated = List<ContainerTwin>.of(list);
    updated[index] = next;
    _byBlock[blockId] = updated;
    controller.add(updated);
  }

  @override
  Future<List<ContainerTwin>> fetchContainers({required String blockId}) async {
    return _byBlock[blockId] ?? _seed(blockId);
  }
}
