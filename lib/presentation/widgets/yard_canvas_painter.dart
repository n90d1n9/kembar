import 'package:flutter/material.dart';

import '../../application/port_terminal/scene/orbit_camera.dart';
import '../../application/port_terminal/scene/placed_container.dart';
import '../../application/port_terminal/scene/projected_scene.dart';

/// Draws a yard scene straight from live [PlacedContainer] data using
/// Flutter's own Canvas — no GLB, no WebView, no reload. This is the
/// actual mechanism behind true instant updates: when the underlying
/// container data changes, this repaints on the next frame like any
/// other Flutter widget, not on the next "regenerate a scene file and
/// reload a 3D viewer" cycle.
///
/// Built entirely on [projectYardScene] — the same function
/// `hitTestProjectedScene` uses for tap selection — so what you can tap
/// and what you see are structurally guaranteed to agree.
class YardCanvasPainter extends CustomPainter {
  final List<PlacedContainer> containers;
  final OrbitCamera camera;
  final Color Function(PlacedContainer) colorFor;
  final Set<String> highlightedIds;

  YardCanvasPainter({
    required this.containers,
    required this.camera,
    required this.colorFor,
    this.highlightedIds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerOffset = Offset(size.width / 2, size.height / 2);
    final containerById = {for (final c in containers) c.id: c};

    final scene = projectYardScene(containers: containers, camera: camera);
    // Painter's algorithm: farthest first, so nearer containers correctly
    // overdraw farther ones.
    final byFarthest = List<ProjectedContainerScene>.of(scene)
      ..sort((a, b) => b.depth.compareTo(a.depth));

    for (final entry in byFarthest) {
      final container = containerById[entry.id];
      if (container == null) continue; // defensive — shouldn't happen
      final baseColor = colorFor(container);
      final isHighlighted = highlightedIds.contains(entry.id);

      for (final face in entry.faces) {
        final path = Path();
        for (var i = 0; i < face.screenX.length; i++) {
          final offset =
              centerOffset + Offset(face.screenX[i], face.screenY[i]);
          if (i == 0) {
            path.moveTo(offset.dx, offset.dy);
          } else {
            path.lineTo(offset.dx, offset.dy);
          }
        }
        path.close();

        final shaded = Color.lerp(Colors.black, baseColor, face.shade)!;
        final fillPaint = Paint()
          ..color = shaded
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);

        final strokePaint = Paint()
          // .withOpacity (not the newer .withValues) deliberately — this
          // project's pubspec floor is flutter '>=3.19.0', and I'm not
          // certain .withValues exists that far back, whereas
          // .withOpacity has been available since early Flutter and is
          // safe across the whole declared range even though it's the
          // now-deprecated spelling on the newest SDKs.
          ..color =
              isHighlighted ? Colors.white : Colors.black.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 2.5 : 0.75;
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant YardCanvasPainter oldDelegate) {
    return !identical(oldDelegate.containers, containers) ||
        oldDelegate.camera != camera ||
        !_setEquals(oldDelegate.highlightedIds, highlightedIds);
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
