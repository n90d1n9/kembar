import 'projected_scene.dart';

/// Point-in-polygon via the standard ray-casting ("PNPOLY") algorithm,
/// verified numerically against several hand-checked cases (axis-aligned
/// square, a rotated diamond, near-edge points) before being written here.
bool _pointInPolygon(double x, double y, List<double> polyX, List<double> polyY) {
  var inside = false;
  final n = polyX.length;
  var j = n - 1;
  for (var i = 0; i < n; i++) {
    final xi = polyX[i], yi = polyY[i];
    final xj = polyX[j], yj = polyY[j];
    final crosses = (yi > y) != (yj > y);
    if (crosses && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

/// Returns the id of the topmost (nearest-camera) container whose
/// projected silhouette contains screen-relative point (x, y), or null if
/// none does. Tests nearest-first (ascending depth) regardless of the
/// order [scene] was built in, so a caller doesn't need to pre-sort —
/// this always finds the container that would actually be visible at
/// that point, not whichever happens to be listed first.
String? hitTestProjectedScene(List<ProjectedContainerScene> scene, double x, double y) {
  final byNearest = List<ProjectedContainerScene>.of(scene)..sort((a, b) => a.depth.compareTo(b.depth));

  for (final entry in byNearest) {
    for (final face in entry.faces) {
      if (_pointInPolygon(x, y, face.screenX, face.screenY)) {
        return entry.id;
      }
    }
  }
  return null;
}
