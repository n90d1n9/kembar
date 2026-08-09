import 'package:flutter/material.dart';

import '../../application/port_terminal/scene/cuboid_hit_test.dart';
import '../../application/port_terminal/scene/orbit_camera.dart';
import '../../application/port_terminal/scene/placed_container.dart';
import '../../application/port_terminal/scene/projected_scene.dart';
import '../../domain/value_objects/position3d.dart';
import 'yard_canvas_painter.dart';

/// Native-Canvas alternative to [DigitalTwinViewport]. Renders straight
/// from live [PlacedContainer] data on every rebuild — no GLB export, no
/// WebView, no network hop, no "reload the whole model" step. This is
/// what makes container status changes feel instant rather than like a
/// scene reload: a Riverpod state change flows into a normal widget
/// rebuild, which repaints a Canvas, exactly like any other Flutter UI.
///
/// The tradeoff for that immediacy is visual fidelity: this is flat-
/// shaded boxes with a fixed pseudo-light, not PBR materials, textures,
/// or true perspective-correct blending — a legitimate different tool,
/// not a strictly-better replacement for the GLB path.
///
/// Camera orbit/zoom state is deliberately local widget state, not
/// Riverpod — it's ephemeral viewport state, not digital-twin data.
///
/// Tap-to-select deliberately does NOT use `onTap`/`onTapUp` alongside
/// `onScaleStart`/`onScaleUpdate` on the same GestureDetector. Flutter's
/// own docs note scale is a strict superset of pan, and there are
/// confirmed reports of onScale firing for gestures that look like plain
/// taps — mixing Tap-family and Scale-family recognizers on one
/// GestureDetector is genuinely ambiguous territory, not something to
/// guess at. Instead, a tap is detected *from inside* the scale gesture
/// itself: if total pointer movement between onScaleStart and onScaleEnd
/// stays under a small threshold, it's treated as a tap at the gesture's
/// starting point.
class YardCanvasView extends StatefulWidget {
  final List<PlacedContainer> containers;
  final Color Function(PlacedContainer) colorFor;
  final Set<String> highlightedIds;
  final Position3D initialTarget;
  final ValueChanged<String>? onContainerTap;

  const YardCanvasView({
    super.key,
    required this.containers,
    required this.colorFor,
    this.highlightedIds = const {},
    this.initialTarget = const Position3D(0, 0, 0),
    this.onContainerTap,
  });

  @override
  State<YardCanvasView> createState() => YardCanvasViewState();
}

class YardCanvasViewState extends State<YardCanvasView> {
  static const double _tapMovementThresholdPx = 12;

  late OrbitCamera _camera = OrbitCamera(
    target: widget.initialTarget,
    azimuthDeg: -35,
    elevationDeg: 32,
    distance: 45,
  );

  // Captured at gesture start so zoom (which Flutter reports as
  // cumulative-since-gesture-start via `scale`) recomputes against a
  // stable baseline each update.
  late OrbitCamera _cameraAtGestureStart;

  Offset? _gestureStartFocalPoint;
  double _totalMovement = 0;

  /// Re-centers the camera on a world point — used by the container list
  /// selection to "focus" the same way DigitalTwinViewport's
  /// setCameraTarget does, but instantly, since there's no viewer to
  /// round-trip a JS call through.
  void focusOn(Position3D target) {
    setState(() => _camera = _camera.copyWith(target: target));
  }

  void _onScaleStart(ScaleStartDetails details) {
    _cameraAtGestureStart = _camera;
    _gestureStartFocalPoint = details.localFocalPoint;
    _totalMovement = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _totalMovement += details.focalPointDelta.distance;

    setState(() {
      // details.focalPointDelta is the movement *since the previous
      // update event* (Flutter's own gesture docs are explicit about
      // this) — so pan/orbit has to accumulate onto the *current*
      // camera each frame, not recompute from the gesture-start camera,
      // or it would only ever reflect the latest tiny increment instead
      // of the whole drag.
      final azimuth = _camera.azimuthDeg - details.focalPointDelta.dx * 0.4;
      final elevation =
          (_camera.elevationDeg + details.focalPointDelta.dy * 0.4)
              .clamp(-85.0, 85.0);

      // details.scale, by contrast, *is* cumulative relative to pointer
      // distance at gesture start — so zoom recomputes each frame
      // against the distance captured once in _onScaleStart, not
      // accumulated onto the current value. With a single pointer
      // (a plain drag), scale stays at 1.0, so distance is unaffected —
      // exactly the "drag orbits, pinch zooms" split this is meant to be.
      final distance =
          (_cameraAtGestureStart.distance / details.scale).clamp(5.0, 400.0);

      _camera = OrbitCamera(
        target: _camera.target,
        azimuthDeg: azimuth,
        elevationDeg: elevation,
        distance: distance,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details, Size viewportSize) {
    final startPoint = _gestureStartFocalPoint;
    _gestureStartFocalPoint = null;
    if (startPoint == null || _totalMovement >= _tapMovementThresholdPx) {
      return; // moved enough to have been an orbit/zoom, not a tap
    }
    if (widget.onContainerTap == null) return;

    final centerOffset =
        Offset(viewportSize.width / 2, viewportSize.height / 2);
    final relative = startPoint - centerOffset;
    final scene =
        projectYardScene(containers: widget.containers, camera: _camera);
    final hitId = hitTestProjectedScene(scene, relative.dx, relative.dy);
    if (hitId != null) {
      widget.onContainerTap!(hitId);
    }
  }

  void _onDoubleTap() {
    setState(() {
      _camera = OrbitCamera(
        target: widget.initialTarget,
        azimuthDeg: -35,
        elevationDeg: 32,
        distance: 45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: (details) => _onScaleEnd(details, size),
          // Known interaction, not a bug: a double-tap's first tap can
          // also complete a (near-zero-movement) scale gesture, so
          // onScaleEnd's tap detection may select/deselect a container
          // right before onDoubleTap resets the camera. Both firing from
          // one double-tap is a minor UX quirk, not broken behavior.
          onDoubleTap: _onDoubleTap,
          child: ColoredBox(
            color: const Color(0xFF15181D),
            child: CustomPaint(
              painter: YardCanvasPainter(
                containers: widget.containers,
                camera: _camera,
                colorFor: widget.colorFor,
                highlightedIds: widget.highlightedIds,
              ),
              size: size,
            ),
          ),
        );
      },
    );
  }
}
