import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_digital_twin/runtime/twin_runtime.dart';
import 'package:terminal_digital_twin/domain/core/twin_component.dart';
import 'package:terminal_digital_twin/domain/core/twin_entity.dart';
import 'package:terminal_digital_twin/domain/core/twin_entity_id.dart';
import 'package:terminal_digital_twin/domain/core/twin_event.dart';
import 'package:terminal_digital_twin/domain/core/twin_property.dart';

void main() {
  group('TwinRuntime', () {
    test('creates an entity', () {
      final runtime = TwinRuntime();

      final entity = TwinEntity(
        id: const TwinEntityId('machine-001'),
        type: 'machine',
      );

      runtime.apply(
        EntityCreated(entity),
      );

      expect(
        runtime.state.entity('machine-001'),
        same(entity),
      );
    });

    test('updates an entity', () {
      final runtime = TwinRuntime();

      final initial = TwinEntity(
        id: const TwinEntityId('machine-001'),
        type: 'machine',
      );

      runtime.apply(
        EntityCreated(initial),
      );

      final updated = TwinEntity(
        id: const TwinEntityId('machine-001'),
        type: 'robot',
      );

      runtime.apply(
        EntityUpdated(updated),
      );

      expect(
        runtime.state.entity('machine-001')!.type,
        'robot',
      );
    });

    test('removes an entity', () {
      final runtime = TwinRuntime();

      final entity = TwinEntity(
        id: const TwinEntityId('machine-001'),
        type: 'machine',
      );

      runtime.apply(
        EntityCreated(entity),
      );

      runtime.apply(
        EntityRemoved(
          const TwinEntityId('machine-001'),
        ),
      );

      expect(
        runtime.state.entity('machine-001'),
        isNull,
      );
    });

    test('runtime is domain agnostic', () {
      final runtime = TwinRuntime();

      runtime.apply(
        EntityCreated(
          TwinEntity(
            id: const TwinEntityId('container-001'),
            type: 'container',
          ),
        ),
      );

      runtime.apply(
        EntityCreated(
          TwinEntity(
            id: const TwinEntityId('robot-001'),
            type: 'robot',
          ),
        ),
      );

      runtime.apply(
        EntityCreated(
          TwinEntity(
            id: const TwinEntityId('building-001'),
            type: 'building',
          ),
        ),
      );

      expect(
        runtime.state.entitiesOfType('container').length,
        1,
      );

      expect(
        runtime.state.entitiesOfType('robot').length,
        1,
      );

      expect(
        runtime.state.entitiesOfType('building').length,
        1,
      );
    });

    test('entity can contain generic properties', () {
      final entity = TwinEntity(
        id: const TwinEntityId('machine-001'),
        type: 'machine',
        components: {
          'properties': const PropertiesComponent(
            properties: {
              'temperature': TwinNumber(72.5),
              'running': TwinBoolean(true),
              'status': TwinEnum('operational'),
            },
          ),
        },
      );

      final component = entity.component('properties') as PropertiesComponent;

      expect(
        (component.get('temperature') as TwinNumber).value,
        72.5,
      );

      expect(
        (component.get('running') as TwinBoolean).value,
        true,
      );

      expect(
        (component.get('status') as TwinEnum).value,
        'operational',
      );
    });
  });
}
