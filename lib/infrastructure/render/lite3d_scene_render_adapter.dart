import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lite_3d_core/lite_3d_core.dart';

import '../../application/port_terminal/scene/placed_container.dart';
import '../../domain/entities/container_status.dart';
import '../../domain/entities/yard_block_layout.dart';
import 'scene_render_adapter.dart';

/// Builds a lite_3d_core [Scene3D] from placed containers and exports it
/// to GLB bytes via [GlbWriter] — the same "Scene Builder -> Mesh
/// Generator -> GLTF Scene" pipeline the tenun_3d chart engine already
/// uses, applied to yard containers instead of chart bars.
class Lite3dSceneRenderAdapter implements SceneRenderAdapter {
  const Lite3dSceneRenderAdapter();

  @override
  Uint8List buildGlb(List<PlacedContainer> containers,
      {YardBlockLayout? layout}) {
    final nodes = <Node3D>[];

    if (layout != null) {
      nodes.add(_groundPlateNode(layout));
    }

    for (final container in containers) {
      nodes.add(_containerNode(container));
    }

    final scene = Scene3D(nodes: nodes, name: 'terminal_yard_twin');
    return GlbWriter.build(scene);
  }

  Node3D _groundPlateNode(YardBlockLayout layout) {
    final width = layout.bayCount * layout.bayPitchM;
    final depth = layout.rowCount * layout.rowPitchM;

    // Center of the block's footprint in the block's own *local* (unrotated)
    // frame — same derivation as SlotPositionMapper's per-slot offset, just
    // for the whole span instead of one cell: each slot occupies a
    // bayPitchM x rowPitchM cell centered on its slot position, so the
    // half-cell subtraction re-centers the plate under those cells rather
    // than under the raw bayCount*bayPitchM rectangle.
    final localCenterX = width / 2 - layout.bayPitchM / 2;
    final localCenterZ = depth / 2 - layout.rowPitchM / 2;

    // Must go through the same rotation as every container on this block —
    // otherwise a rotated block's ground plate ends up offset from its own
    // containers instead of sitting under them.
    final rotated =
        _rotateXZ(localCenterX, localCenterZ, layout.orientationDeg);

    return Node3D(
      name: '${layout.blockId}_ground_plate',
      mesh: MeshBuilder.groundPlane(width: width, depth: depth),
      material: _groundMaterial,
      translation: Vec3(
        layout.origin.x + rotated.$1,
        layout.origin.y,
        layout.origin.z + rotated.$2,
      ),
      rotation: layout.orientationDeg == 0
          ? null
          : _yawQuaternionDeg(layout.orientationDeg),
      animatable: false,
    );
  }

  Node3D _containerNode(PlacedContainer container) {
    final mesh = MeshBuilder.cuboid(
      sizeX: container.lengthM,
      sizeY: container.heightM,
      sizeZ: container.widthM,
    );
    return Node3D(
      name: container.label,
      mesh: mesh,
      material: _materialFor(container.status),
      translation: Vec3(container.baseCenter.x, container.baseCenter.y,
          container.baseCenter.z),
      rotation: container.rotationYDeg == 0
          ? null
          : _yawQuaternionDeg(container.rotationYDeg),
      datumId: container.id,
      animatable: true,
    );
  }

  static const Material3D _groundMaterial = Material3D(
    baseColor: [0.35, 0.35, 0.37, 1.0],
    metallic: 0.0,
    roughness: 0.9,
    name: 'yard_ground',
  );

  static Material3D _materialFor(ContainerStatus status) {
    switch (status) {
      case ContainerStatus.laden:
        return const Material3D(
            baseColor: [0.16, 0.50, 0.83, 1.0], name: 'laden');
      case ContainerStatus.empty:
        return const Material3D(
            baseColor: [0.55, 0.55, 0.55, 1.0], name: 'empty');
      case ContainerStatus.onHold:
        return const Material3D(
            baseColor: [0.90, 0.65, 0.10, 1.0], name: 'on_hold');
      case ContainerStatus.reservedForLoad:
        return const Material3D(
            baseColor: [0.30, 0.70, 0.35, 1.0], name: 'reserved_for_load');
      case ContainerStatus.damaged:
        return const Material3D(
            baseColor: [0.80, 0.15, 0.15, 1.0], name: 'damaged');
    }
  }

  /// glTF quaternion [x, y, z, w] for a rotation of [deg] degrees around
  /// the vertical Y axis — used to orient a container's footprint with
  /// its block, not to be confused with MeshBuilder.quaternionFromUp
  /// (which tilts a mesh's local up axis, a different operation).
  static List<double> _yawQuaternionDeg(double deg) {
    final half = deg * math.pi / 180.0 / 2.0;
    return [0, math.sin(half), 0, math.cos(half)];
  }

  /// Rotates a local (x, z) offset by [deg] around the vertical axis —
  /// the exact same transform SlotPositionMapper applies per-slot, shared
  /// here so the ground plate and its containers can never drift apart.
  static (double, double) _rotateXZ(double x, double z, double deg) {
    if (deg == 0) return (x, z);
    final theta = deg * math.pi / 180.0;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);
    return (x * cosT - z * sinT, x * sinT + z * cosT);
  }
}
