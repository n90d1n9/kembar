import '../../../domain/value_objects/position3d.dart';
import 'cuboid_geometry.dart';
import 'orbit_camera.dart';
import 'placed_container.dart';

/// One visible face of one container, already projected to screen-
/// relative coordinates (origin at viewport center, same convention as
/// OrbitCamera.project) — ready for either drawing or hit-testing.
class ProjectedFace {
  final List<double> screenX;
  final List<double> screenY;
  final double shade;

  const ProjectedFace(this.screenX, this.screenY, this.shade);
}

/// One container's full projected result: its visible faces plus a depth
/// value for painter's-algorithm sorting.
class ProjectedContainerScene {
  final String id;
  final double depth;
  final List<ProjectedFace> faces;

  const ProjectedContainerScene(this.id, this.depth, this.faces);
}

/// Projects every container's visible faces through [camera] once. Both
/// [YardCanvasPainter] (drawing) and hitTestProjectedScene (tap
/// selection) build on this single function rather than each doing their
/// own projection — so "what you can tap" and "what you see" can never
/// quietly drift apart from each other.
List<ProjectedContainerScene> projectYardScene({
  required List<PlacedContainer> containers,
  required OrbitCamera camera,
}) {
  final results = <ProjectedContainerScene>[];

  for (final container in containers) {
    final corners = cuboidWorldCorners(container);
    // Centroid = midpoint between the bottom-front-left (0) and
    // top-back-right (6) corners — a cheap stand-in for the box's
    // center, good enough for depth-sorting between containers.
    final centroid = Position3D(
      (corners[0].x + corners[6].x) / 2,
      (corners[0].y + corners[6].y) / 2,
      (corners[0].z + corners[6].z) / 2,
    );
    final projectedCentroid = camera.project(centroid);
    if (!projectedCentroid.visible)
      continue; // whole container is behind the camera

    final faceDefs = visibleCuboidFaces(container, corners, camera.eye);
    if (faceDefs.isEmpty) continue;

    final projectedCorners =
        corners.map(camera.project).toList(growable: false);

    final faces = <ProjectedFace>[];
    for (final face in faceDefs) {
      if (face.cornerIndices.any((i) => !projectedCorners[i].visible)) {
        continue; // a corner behind the camera would make a garbage polygon
      }
      final xs = face.cornerIndices
          .map((i) => projectedCorners[i].x)
          .toList(growable: false);
      final ys = face.cornerIndices
          .map((i) => projectedCorners[i].y)
          .toList(growable: false);
      faces.add(ProjectedFace(xs, ys, face.shade));
    }
    if (faces.isEmpty) continue;

    results.add(
        ProjectedContainerScene(container.id, projectedCentroid.depth, faces));
  }

  return results;
}
