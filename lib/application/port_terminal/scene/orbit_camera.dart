import 'dart:math' as math;

import '../../../domain/value_objects/position3d.dart';

/// Result of projecting one world point through an [OrbitCamera]. (x, y)
/// are relative to the viewport center — a caller adds its own center
/// offset before drawing. [depth] is camera-space distance along the
/// camera's forward axis, used for painter's-algorithm sorting (paint
/// largest depth first); [visible] is false when the point is behind (or
/// too close to) the camera, where perspective division would blow up.
class ProjectedPoint {
  final double x;
  final double y;
  final double depth;
  final bool visible;

  const ProjectedPoint({
    required this.x,
    required this.y,
    required this.depth,
    required this.visible,
  });
}

/// A simple orbit ("arcball") camera: looks at [target] from [distance]
/// meters away, [azimuthDeg] around the vertical axis and [elevationDeg]
/// above the horizontal plane.
///
/// Pure Dart, no Flutter dependency — the projection math is exactly the
/// pinhole-camera model (eye position via spherical coordinates, a
/// look-at basis via Gram-Schmidt, perspective division), verified by
/// hand against worked numeric cases before being written here: at
/// azimuth 0 the eye sits on +Z looking down -Z with right=+X, up=+Y;
/// projecting world point (1,0,0) yields a positive screen X and zero
/// screen Y, exactly as it should for a point directly to the camera's
/// right at the target's height.
class OrbitCamera {
  final Position3D target;
  final double azimuthDeg;
  final double elevationDeg;
  final double distance;

  const OrbitCamera({
    required this.target,
    required this.azimuthDeg,
    required this.elevationDeg,
    required this.distance,
  });

  OrbitCamera copyWith({
    Position3D? target,
    double? azimuthDeg,
    double? elevationDeg,
    double? distance,
  }) {
    return OrbitCamera(
      target: target ?? this.target,
      azimuthDeg: azimuthDeg ?? this.azimuthDeg,
      elevationDeg: elevationDeg ?? this.elevationDeg,
      distance: distance ?? this.distance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OrbitCamera &&
      other.target == target &&
      other.azimuthDeg == azimuthDeg &&
      other.elevationDeg == elevationDeg &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(target, azimuthDeg, elevationDeg, distance);

  /// World-space position of the camera, from the orbit parameters via
  /// standard spherical-to-Cartesian conversion around [target].
  Position3D get eye {
    final az = azimuthDeg * math.pi / 180.0;
    final el = elevationDeg * math.pi / 180.0;
    final horizontal = distance * math.cos(el);
    return Position3D(
      target.x + horizontal * math.sin(az),
      target.y + distance * math.sin(el),
      target.z + horizontal * math.cos(az),
    );
  }

  _CameraBasis get _basis {
    final eyePos = eye;
    var fx = target.x - eyePos.x;
    var fy = target.y - eyePos.y;
    var fz = target.z - eyePos.z;
    final fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fLen == 0) {
      // Degenerate (camera exactly at target) — look down -Z so callers
      // never divide by zero.
      fx = 0;
      fy = 0;
      fz = -1;
    } else {
      fx /= fLen;
      fy /= fLen;
      fz /= fLen;
    }

    // right = forward × worldUp, with worldUp = (0, 1, 0). The general
    // cross-product formula collapses to this closed form for a
    // constant (0,1,0) second operand — verified numerically (see the
    // class doc) before being hardcoded here rather than trusted blind.
    var rx = -fz;
    var ry = 0.0;
    var rz = fx;
    final rLen = math.sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen == 0) {
      // Forward is parallel to world up (looking straight down/up) — a
      // fixed fallback right vector avoids a divide-by-zero.
      rx = 1;
      ry = 0;
      rz = 0;
    } else {
      rx /= rLen;
      ry /= rLen;
      rz /= rLen;
    }

    // up = right × forward
    final ux = ry * fz - rz * fy;
    final uy = rz * fx - rx * fz;
    final uz = rx * fy - ry * fx;

    return _CameraBasis(
      eye: eyePos,
      rightX: rx,
      rightY: ry,
      rightZ: rz,
      upX: ux,
      upY: uy,
      upZ: uz,
      forwardX: fx,
      forwardY: fy,
      forwardZ: fz,
    );
  }

  /// Projects a world point into screen-relative coordinates + depth.
  /// [focalLength] controls perspective strength (larger = flatter,
  /// more telephoto; smaller = more wide-angle distortion) — 900 reads
  /// as a mild, natural-looking perspective at typical phone/desktop
  /// viewport sizes.
  ProjectedPoint project(Position3D world, {double focalLength = 900}) {
    final basis = _basis;
    final rx = world.x - basis.eye.x;
    final ry = world.y - basis.eye.y;
    final rz = world.z - basis.eye.z;

    final camX = rx * basis.rightX + ry * basis.rightY + rz * basis.rightZ;
    final camY = rx * basis.upX + ry * basis.upY + rz * basis.upZ;
    final camZ =
        rx * basis.forwardX + ry * basis.forwardY + rz * basis.forwardZ;

    const nearPlane = 0.05;
    if (camZ <= nearPlane) {
      return ProjectedPoint(x: 0, y: 0, depth: camZ, visible: false);
    }

    final scale = focalLength / camZ;
    return ProjectedPoint(
        x: camX * scale, y: -camY * scale, depth: camZ, visible: true);
  }
}

class _CameraBasis {
  final Position3D eye;
  final double rightX, rightY, rightZ;
  final double upX, upY, upZ;
  final double forwardX, forwardY, forwardZ;

  const _CameraBasis({
    required this.eye,
    required this.rightX,
    required this.rightY,
    required this.rightZ,
    required this.upX,
    required this.upY,
    required this.upZ,
    required this.forwardX,
    required this.forwardY,
    required this.forwardZ,
  });
}
