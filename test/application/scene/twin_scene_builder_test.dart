import 'package:flutter_test/flutter_test.dart';
import 'package:twin_kernel/domain/core/twin_core.dart';
import 'package:twin_kernel/domain/scene/scene_graph.dart';
import 'package:twin_kernel/domain/scene/scene_node.dart';
import 'package:twin_kernel/application/scene/scene_node_builder.dart';
import 'package:twin_kernel/application/scene/container_scene_node_builder.dart';
import 'package:twin_kernel/application/scene/twin_scene_builder.dart';

void main() {
  group('SceneNodeBuilder', () {
    test('ContainerSceneNodeBuilder supports container entities', () {
      final builder = const ContainerSceneNodeBuilder();
      final entity = TwinEntity(
        id: const TwinEntityId('container-001'),
        type: 'container',
        components: {},
      );

      expect(builder.supports(entity), isTrue);
    });

    test('ContainerSceneNodeBuilder does not support non-container entities',
        () {
      final builder = const ContainerSceneNodeBuilder();
      final entity = TwinEntity(
        id: const TwinEntityId('crane-001'),
        type: 'crane',
        components: {},
      );

      expect(builder.supports(entity), isFalse);
    });
  });

  group('TwinSceneBuilder', () {
    test('builds a scene node from a generic container entity with 40ft size',
        () {
      final entity = TwinEntity(
        id: const TwinEntityId('container-001'),
        type: 'container',
        components: {
          'spatial': const SpatialComponent(
            position: Vector3(10, 0, 5),
          ),
          'properties': PropertiesComponent(
            properties: {
              'size': TwinEnum('40ft'),
            },
          ),
        },
      );

      final builder = TwinSceneBuilder(
        builders: const [
          ContainerSceneNodeBuilder(),
        ],
      );

      final graph = builder.build(
        TwinState(
          entities: {
            entity.id.value: entity,
          },
        ),
      );

      final node = graph.node('container-001');

      expect(node, isNotNull);
      expect(node!.position, const Vector3(10, 0, 5));
      expect(node.assetId, 'container_40ft');
      expect(node.entityType, 'container');
    });

    test('builds a scene node from a generic container entity with 20ft size',
        () {
      final entity = TwinEntity(
        id: const TwinEntityId('container-002'),
        type: 'container',
        components: {
          'spatial': const SpatialComponent(
            position: Vector3(20, 0, 10),
          ),
          'properties': PropertiesComponent(
            properties: {
              'size': TwinEnum('20ft'),
            },
          ),
        },
      );

      final builder = TwinSceneBuilder(
        builders: const [
          ContainerSceneNodeBuilder(),
        ],
      );

      final graph = builder.build(
        TwinState(
          entities: {
            entity.id.value: entity,
          },
        ),
      );

      final node = graph.node('container-002');

      expect(node, isNotNull);
      expect(node!.position, const Vector3(20, 0, 10));
      expect(node.assetId, 'container_20ft');
    });

    test('handles multiple entities of different types', () {
      final container = TwinEntity(
        id: const TwinEntityId('container-001'),
        type: 'container',
        components: {
          'spatial': const SpatialComponent(
            position: Vector3(10, 0, 5),
          ),
          'properties': PropertiesComponent(
            properties: {
              'size': TwinEnum('40ft'),
            },
          ),
        },
      );

      // Create a mock builder for another entity type
      final mockBuilder = _MockCraneBuilder();

      final crane = TwinEntity(
        id: const TwinEntityId('crane-001'),
        type: 'crane',
        components: {
          'spatial': const SpatialComponent(
            position: Vector3(0, 0, 0),
          ),
        },
      );

      final builder = TwinSceneBuilder(
        builders: [
          const ContainerSceneNodeBuilder(),
          mockBuilder,
        ],
      );

      final graph = builder.build(
        TwinState(
          entities: {
            container.id.value: container,
            crane.id.value: crane,
          },
        ),
      );

      expect(graph.nodes.length, 2);
      expect(graph.node('container-001'), isNotNull);
      expect(graph.node('crane-001'), isNotNull);
    });

    test('skips entities without a matching builder', () {
      final unknownEntity = TwinEntity(
        id: const TwinEntityId('unknown-001'),
        type: 'unknown_type',
        components: {},
      );

      final builder = TwinSceneBuilder(
        builders: const [
          ContainerSceneNodeBuilder(),
        ],
      );

      final graph = builder.build(
        TwinState(
          entities: {
            unknownEntity.id.value: unknownEntity,
          },
        ),
      );

      expect(graph.nodes.length, 0);
    });
  });

  group('SceneGraph', () {
    test('visibleNodes returns only visible nodes', () {
      final node1 = SceneNode(
        id: 'node-1',
        entityType: 'container',
        position: const Vector3(0, 0, 0),
        visible: true,
      );

      final node2 = SceneNode(
        id: 'node-2',
        entityType: 'container',
        position: const Vector3(10, 0, 0),
        visible: false,
      );

      final graph = SceneGraph(
        nodes: {
          'node-1': node1,
          'node-2': node2,
        },
      );

      expect(graph.visibleNodes.length, 1);
      expect(graph.visibleNodes.first.id, 'node-1');
    });

    test('nodesOfType filters by entity type', () {
      final containerNode = SceneNode(
        id: 'container-1',
        entityType: 'container',
        position: const Vector3(0, 0, 0),
      );

      final craneNode = SceneNode(
        id: 'crane-1',
        entityType: 'crane',
        position: const Vector3(10, 0, 0),
      );

      final graph = SceneGraph(
        nodes: {
          'container-1': containerNode,
          'crane-1': craneNode,
        },
      );

      final containers = graph.nodesOfType('container');
      expect(containers.length, 1);
      expect(containers.first.id, 'container-1');

      final cranes = graph.nodesOfType('crane');
      expect(cranes.length, 1);
      expect(cranes.first.id, 'crane-1');
    });
  });
}

/// Mock builder for testing purposes
class _MockCraneBuilder implements SceneNodeBuilder {
  const _MockCraneBuilder();

  @override
  bool supports(TwinEntity entity) => entity.type == 'crane';

  @override
  SceneNode build(TwinEntity entity) {
    final spatial = entity.component('spatial') as SpatialComponent?;
    return SceneNode(
      id: entity.id.value,
      entityType: entity.type,
      position: spatial?.position ?? const Vector3(0, 0, 0),
      assetId: 'crane_default',
    );
  }
}
