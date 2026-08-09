import 'dart:math' as math;

import '../../domain/value_objects/position3d.dart';
import 'placed_container.dart';

/// The 8 world-space corners of a [PlacedContainer]'s box, in a fixed
/// order: 0-3 are the bottom face (matching MeshBuilder.cuboid's
/// bottom-center-origin convention — baseCenter sits at the middle of
/// corners 0-3), 4-7 are the same X/Z positions at the top.
///
/// Corner layout (before yaw rotation, local to the box):
/// ```
///   7-------6      4-------5
///  /|      /|     /|      /|
/// 4-------5 |    (top, y=h)
/// | 3-----|-2
/// |/      |/      0-------1
/// 0-------1      (bottom, y=0)
/// ```
List<Position3D> cuboidWorldCorners(PlacedContainer container) {
  final halfLength = container.lengthM / 2;
  final halfWidth = container.widthM / 2;
  final height = container.heightM;

  const local = [
    [-1.0, 0.0, -1.0], // 0: bottom, -X -Z
    [1.0, 0.0, -1.0], // 1: bottom, +X -Z
    [1.0, 0.0, 1.0], // 2: bottom, +X +Z
    [-1.0, 0.0, 1.0], // 3: bottom, -X +Z
    [-1.0, 1.0, -1.0], // 4: top, -X -Z
    [1.0, 1.0, -1.0], // 5: top, +X -Z
    [1.0, 1.0, 1.0], // 6: top, +X +Z
    [-1.0, 1.0, 1.0], // 7: top, -X +Z
  ];

  final theta = container.rotationYDeg * math.pi / 180.0;
  final cosT = math.cos(theta);
  final sinT = math.sin(theta);
  final center = container.baseCenter;

  return local.map((corner) {
    final localX = corner[0] * halfLength;
    final localY = corner[1] * height;
    final localZ = corner[2] * halfWidth;
    // Same yaw convention as SlotPositionMapper / Lite3dSceneRenderAdapter
    // — one rotation formula used everywhere a container's own facing
    // matters, so this canvas renderer can never visually disagree with
    // the GLB one about which way a container points.
    final worldX = center.x + (localX * cosT - localZ * sinT);
    final worldZ = center.z + (localX * sinT + localZ * cosT);
    final worldY = center.y + localY;
    return Position3D(worldX, worldY, worldZ);
  }).toList(growable: false);
}

/// One face of a box, ready to draw: which 4 of the 8 corners (in
/// perimeter order, so they trace a simple, non-self-intersecting quad)
/// and a fixed shade multiplier standing in for directional lighting —
/// there's no real light source here, just "top brighter than sides,
/// sides brighter than bottom", enough to read as a 3D box.
class CuboidFace {
  final List<int> cornerIndices;
  final double shade;

  const CuboidFace(this.cornerIndices, this.shade);
}

const List<_FaceDef> _faceDefs = [
  _FaceDef([4, 5, 6, 7], [0, 1, 0], 1.0), // top
  _FaceDef([0, 1, 5, 4], [0, 0, -1], 0.72), // front (-Z)
  _FaceDef([3, 2, 6, 7], [0, 0, 1], 0.72), // back (+Z)
  _FaceDef([1, 2, 6, 5], [1, 0, 0], 0.55), // right (+X)
  _FaceDef([0, 4, 7, 3], [-1, 0, 0], 0.55), // left (-X)
  _FaceDef([0, 1, 2, 3], [0, -1, 0], 0.3), // bottom
];

class _FaceDef {
  final List<int> cornerIndices;
  final List<double> localNormal;
  final double shade;

  const _FaceDef(this.cornerIndices, this.localNormal, this.shade);
}

/// Returns only the faces actually facing the camera (standard backface
/// culling: a face is visible when its outward normal points at least
/// partly *toward* the camera, i.e. normal · (cameraEye - faceCenter) is
/// positive). For a convex box viewed from outside itself, this is
/// exactly the up-to-3 faces that should be drawn — the other 3 are
/// always hidden behind the box itself, so there's no need for a full
/// z-buffer to get correct-looking output.
List<CuboidFace> visibleCuboidFaces(
  PlacedContainer container,
  List<Position3D> worldCorners,
  Position3D cameraEye,
) {
  final theta = container.rotationYDeg * math.pi / 180.0;
  final cosT = math.cos(theta);
  final sinT = math.sin(theta);

  final faces = <CuboidFace>[];
  for (final def in _faceDefs) {
    final localNormalX = def.localNormal[0];
    final localNormalY = def.localNormal[1];
    final localNormalZ = def.localNormal[2];
    // Rotate the face's local outward normal by the same yaw as the box
    // itself, so culling is checked in world space.
    final worldNormalX = localNormalX * cosT - localNormalZ * sinT;
    final worldNormalY = localNormalY;
    final worldNormalZ = localNormalX * sinT + localNormalZ * cosT;

    var centerX = 0.0, centerY = 0.0, centerZ = 0.0;
    for (final index in def.cornerIndices) {
      centerX += worldCorners[index].x;
      centerY += worldCorners[index].y;
      centerZ += worldCorners[index].z;
    }
    centerX /= 4;
    centerY /= 4;
    centerZ /= 4;

    final towardCameraX = cameraEye.x - centerX;
    final towardCameraY = cameraEye.y - centerY;
    final towardCameraZ = cameraEye.z - centerZ;

    final facing = worldNormalX * towardCameraX +
        worldNormalY * towardCameraY +
        worldNormalZ * towardCameraZ;

    if (facing > 0) {
      faces.add(CuboidFace(def.cornerIndices, def.shade));
    }
  }
  return faces;
}
