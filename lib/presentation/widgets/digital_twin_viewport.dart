import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

import '../../infrastructure/render/glb_hosting_strategy_factory.dart';
import 'twin_status_views.dart';

/// Generic, reusable 3D viewport for a raw GLB scene. Deliberately knows
/// nothing about containers, yards, or terminals — this widget is equally
/// usable for any other lite_3d_core scene (e.g. tenun_3d charts), which
/// is the point: rendering is a separate concern from what's being
/// rendered.
///
/// [hostingStrategy] defaults to the platform factory if not supplied, so
/// this widget works standalone outside a Riverpod tree too; pass one in
/// (e.g. from `glbHostingStrategyProvider`) to share a single instance
/// and make it overridable in tests.
class DigitalTwinViewport extends StatefulWidget {
  final Uint8List glbBytes;
  final GlbHostingStrategy? hostingStrategy;
  final bool autoRotate;
  final double rotationSpeedDegPerSec;
  final Color backgroundColor;
  final ValueChanged<Flutter3DController>? onControllerReady;
  final ValueChanged<String>? onModelLoaded;
  final ValueChanged<String>? onModelError;

  const DigitalTwinViewport({
    super.key,
    required this.glbBytes,
    this.hostingStrategy,
    this.autoRotate = false,
    this.rotationSpeedDegPerSec = 10,
    this.backgroundColor = Colors.transparent,
    this.onControllerReady,
    this.onModelLoaded,
    this.onModelError,
  });

  @override
  State<DigitalTwinViewport> createState() => _DigitalTwinViewportState();
}

class _DigitalTwinViewportState extends State<DigitalTwinViewport> {
  late final GlbHostingStrategy _hostingStrategy =
      widget.hostingStrategy ?? createGlbHostingStrategy();
  late final Flutter3DController _controller = Flutter3DController();

  String? _src;
  Object? _hostError;

  @override
  void initState() {
    super.initState();
    widget.onControllerReady?.call(_controller);
    _prepareSource();
  }

  @override
  void didUpdateWidget(covariant DigitalTwinViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.glbBytes, widget.glbBytes)) {
      _prepareSource();
    }
  }

  Future<void> _prepareSource() async {
    final requestedBytes = widget.glbBytes;
    final previousSrc = _src;
    try {
      final cacheKey = identityHashCode(requestedBytes).toString();
      final src = await _hostingStrategy.host(requestedBytes, cacheKey);
      // Guard against out-of-order completions: if the widget has since
      // moved on to newer bytes (another _prepareSource call started after
      // this one), applying this result now would show stale data.
      if (!mounted || !identical(widget.glbBytes, requestedBytes)) return;
      setState(() {
        _src = src;
        _hostError = null;
      });
      if (previousSrc != null && previousSrc != src) {
        unawaited(_hostingStrategy.release(previousSrc));
      }
    } catch (error) {
      if (!mounted || !identical(widget.glbBytes, requestedBytes)) return;
      setState(() => _hostError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hostError != null) {
      return TwinErrorView(
        message: 'Could not prepare 3D scene: $_hostError',
        onRetry: _prepareSource,
      );
    }
    if (_src == null) {
      return const TwinLoadingView(message: 'Preparing 3D scene…');
    }
    return ColoredBox(
      color: widget.backgroundColor,
      child: Flutter3DViewer(
        controller: _controller,
        src: _src!,
        onLoad: (modelAddress) {
          if (widget.autoRotate) {
            _controller.startRotation(rotationSpeed: widget.rotationSpeedDegPerSec.toInt());
          }
          widget.onModelLoaded?.call(modelAddress);
        },
        onError: (error) => widget.onModelError?.call(error),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_hostingStrategy.release(_src));
    super.dispose();
  }
}
