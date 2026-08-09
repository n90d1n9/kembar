import 'package:flutter_test/flutter_test.dart';

import '../../application/mappers/container_spatial_mapper.dart';
import '../../application/mappers/container_twin_mapper.dart';
import '../../application/repositories/container_twin_repository_adapter.dart';
import '../../domain/core/twin_core.dart';
import '../../domain/value_objects/yard_slot.dart';
import '../fakes/fake_container_repository.dart';

void main() {
  group('ContainerTwinRepositoryAdapter', () {
    late FakeContainerRepository fakeRepository;
    late ContainerTwinMapper mapper;
    late ContainerTwinRepositoryAdapter adapter;

    setUp(() {
      fakeRepository = FakeContainerRepository();
      mapper = const ContainerTwinMapper(
        spatialMapper: ContainerSpatialMapper(),
      );
      adapter = ContainerTwinRepositoryAdapter(
        source: fakeRepository,
        mapper: mapper,
      );
    });

    tearDown(() async {
      await fakeRepository.dispose();
    });

    test('emits EntityCreated for new containers', () async {
      final events = <TwinEvent>[];
      final subscription = adapter.watch().listen(events.add);

      final container = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      await fakeRepository.emit([container]);

      // Allow async processing
      await Future.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events.first, isA<EntityCreated>());
      
      final created = events.first as EntityCreated;
      expect(created.entity.id.value, equals('CONT001'));
      expect(created.entity.type, equals('container'));

      await subscription.cancel();
    });

    test('emits EntityUpdated for existing containers', () async {
      final events = <TwinEvent>[];
      final subscription = adapter.watch().listen(events.add);

      final container1 = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      // First emission - should be Created
      await fakeRepository.emit([container1]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events.first, isA<EntityCreated>());

      // Second emission with same container - should be Updated
      final container1Updated = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 2, row: 1, tier: 0))
          .withLastUpdated(DateTime.now())
          .build();

      await fakeRepository.emit([container1Updated]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(2));
      expect(events.last, isA<EntityUpdated>());

      final updated = events.last as EntityUpdated;
      expect(updated.entity.id.value, equals('CONT001'));

      await subscription.cancel();
    });

    test('emits EntityRemoved when container disappears', () async {
      final events = <TwinEvent>[];
      final subscription = adapter.watch().listen(events.add);

      final container1 = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      // First emission - create container
      await fakeRepository.emit([container1]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(1));
      expect(events.first, isA<EntityCreated>());

      // Second emission - container removed
      await fakeRepository.emit([]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(2));
      expect(events.last, isA<EntityRemoved>());

      final removed = events.last as EntityRemoved;
      expect(removed.id.value, equals('CONT001'));

      await subscription.cancel();
    });

    test('handles multiple containers correctly', () async {
      final events = <TwinEvent>[];
      final subscription = adapter.watch().listen(events.add);

      final container1 = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      final container2 = TestContainerBuilder()
          .withId('CONT002')
          .withSlot(const YardSlot(bay: 1, row: 2, tier: 0))
          .build();

      // First emission - two new containers
      await fakeRepository.emit([container1, container2]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(2));
      expect(events.every((e) => e is EntityCreated), isTrue);

      // Second emission - one update, one removal, one addition
      final container1Updated = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 2, row: 1, tier: 0))
          .withLastUpdated(DateTime.now())
          .build();

      final container3 = TestContainerBuilder()
          .withId('CONT003')
          .withSlot(const YardSlot(bay: 1, row: 3, tier: 0))
          .build();

      await fakeRepository.emit([container1Updated, container3]);
      await Future.delayed(Duration.zero);

      expect(events.length, equals(5)); // 2 created + 1 updated + 1 removed + 1 created

      final eventTypes = events.map((e) => e.runtimeType).toList();
      expect(eventTypes.contains(EntityCreated), isTrue);
      expect(eventTypes.contains(EntityUpdated), isTrue);
      expect(eventTypes.contains(EntityRemoved), isTrue);

      await subscription.cancel();
    });

    test('fetchEntities returns mapped entities', () async {
      final container1 = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      final container2 = TestContainerBuilder()
          .withId('CONT002')
          .withSlot(const YardSlot(bay: 1, row: 2, tier: 0))
          .build();

      await fakeRepository.emit([container1, container2]);

      final entities = await adapter.fetchEntities();

      expect(entities.length, equals(2));
      expect(entities.map((e) => e.id.value), contains('CONT001'));
      expect(entities.map((e) => e.id.value), contains('CONT002'));
      expect(entities.every((e) => e.type == 'container'), isTrue);
    });

    test('fetchEntities filters by type', () async {
      final container = TestContainerBuilder()
          .withId('CONT001')
          .withSlot(const YardSlot(bay: 1, row: 1, tier: 0))
          .build();

      await fakeRepository.emit([container]);

      // Filter for non-matching type
      final filtered = await adapter.fetchEntities(type: 'warehouse');
      expect(filtered, isEmpty);

      // Filter for matching type
      final matching = await adapter.fetchEntities(type: 'container');
      expect(matching.length, equals(1));

      // No filter
      final all = await adapter.fetchEntities();
      expect(all.length, equals(1));
    });
  });
}
