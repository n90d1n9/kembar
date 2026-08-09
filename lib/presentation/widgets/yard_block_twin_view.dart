import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/position3d.dart';
import '../providers/container_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/scene_providers.dart';
import '../providers/selection_providers.dart';
import '../providers/yard_layout_providers.dart';
import '../providers/yard_window_providers.dart';
import '../theme/twin_status_colors.dart';
import 'container_inspector_panel.dart';
import 'container_list_panel.dart';
import 'digital_twin_viewport.dart';
import 'twin_status_views.dart';
import 'yard_canvas_view.dart';
import 'yard_legend.dart';
import 'yard_window_control.dart';

enum _RenderMode { model3d, liveCanvas }

/// The composed, drop-in Digital Twin widget: `YardBlockTwinView(blockId:
/// 'A')` is all a consuming screen needs to write. Internally it wires two
/// interchangeable render paths — [DigitalTwinViewport] (GLB, via
/// lite_3d_core + flutter_3d_controller) and [YardCanvasView] (native
/// Canvas, straight from live data) — together with the container-
/// specific providers and reusable panels. The "smart" layer sits here so
/// every widget it composes stays dumb and independently reusable.
class YardBlockTwinView extends ConsumerStatefulWidget {
  final String blockId;

  const YardBlockTwinView({super.key, required this.blockId});

  @override
  ConsumerState<YardBlockTwinView> createState() => _YardBlockTwinViewState();
}

class _YardBlockTwinViewState extends ConsumerState<YardBlockTwinView> {
  Flutter3DController? _model3dController;
  final _canvasKey = GlobalKey<YardCanvasViewState>();
  _RenderMode _renderMode = _RenderMode.liveCanvas;

  void _focusCamera(double x, double y, double z) {
    if (_renderMode == _RenderMode.model3d) {
      _model3dController?.setCameraTarget(x, y, z);
    } else {
      _canvasKey.currentState?.focusOn(Position3D(x, y, z));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glbAsync = ref.watch(twinGlbProvider(widget.blockId));
    final placedContainers = ref.watch(placedContainersProvider(widget.blockId));
    final containersAsync = ref.watch(containersStreamProvider(widget.blockId));
    final layoutAsync = ref.watch(yardBlockLayoutProvider(widget.blockId));
    final mapper = ref.watch(containerPositionMapperProvider);
    final window = ref.watch(yardWindowProvider(widget.blockId));
    final selectedId = ref.watch(selectedContainerProvider);
    final hostingStrategy = ref.watch(glbHostingStrategyProvider);

    final containers = containersAsync.valueOrNull ?? const [];
    // What the list shows should match what's actually rendered —
    // otherwise tapping a list entry could select a container that
    // isn't visible because the window has moved past it.
    final visibleContainers = containers.where((c) => window.contains(c.slot)).toList(growable: false);
    final selected = selectedId == null
        ? null
        : containers.where((c) => c.id.value == selectedId).firstOrNull;

    void selectAndFocus(String id) {
      ref.read(selectedContainerProvider.notifier).select(id);
      final container = containers.where((c) => c.id.value == id).firstOrNull;
      final layout = layoutAsync.valueOrNull;
      // Reuses the exact same mapper the rendered scene was built with —
      // no duplicated/hardcoded geometry, so this stays correct for
      // whichever block is actually showing, not just block "A".
      if (container != null && layout != null) {
        final position = mapper.positionOf(container.slot, layout);
        _focusCamera(position.x, position.y, position.z);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final layout = layoutAsync.valueOrNull;
        final viewport = Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: const YardLegend())),
                  ChoiceChip(
                    label: const Text('Live Canvas'),
                    selected: _renderMode == _RenderMode.liveCanvas,
                    onSelected: (_) => setState(() => _renderMode = _RenderMode.liveCanvas),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('3D Model'),
                    selected: _renderMode == _RenderMode.model3d,
                    onSelected: (_) => setState(() => _renderMode = _RenderMode.model3d),
                  ),
                ],
              ),
            ),
            if (layout != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: YardWindowControl(blockId: widget.blockId, layout: layout),
              ),
            Expanded(
              child: Stack(
                children: [
                  // YardCanvasView stays mounted (hidden via Offstage,
                  // not destroyed) across mode toggles so its camera
                  // orbit/zoom state survives switching away and back —
                  // it's cheap enough (plain Canvas, no WebView) that
                  // this costs nothing noticeable. DigitalTwinViewport
                  // does NOT get the same treatment: keeping a WebView-
                  // backed 3D viewer alive off-screen indefinitely is a
                  // real resource cost for something the user isn't
                  // looking at, so it's still created/destroyed on
                  // toggle and does lose its state — an accepted,
                  // asymmetric tradeoff, not an oversight.
                  Offstage(
                    offstage: _renderMode != _RenderMode.liveCanvas,
                    child: YardCanvasView(
                      key: _canvasKey,
                      containers: placedContainers,
                      colorFor: (c) => twinStatusColors[c.status] ?? Colors.grey,
                      highlightedIds: selectedId == null ? const {} : {selectedId},
                      onContainerTap: selectAndFocus,
                    ),
                  ),
                  if (_renderMode == _RenderMode.model3d)
                    glbAsync.when(
                      data: (bytes) => DigitalTwinViewport(
                        glbBytes: bytes,
                        hostingStrategy: hostingStrategy,
                        onControllerReady: (c) => _model3dController = c,
                      ),
                      loading: () => const TwinLoadingView(),
                      error: (error, stackTrace) => TwinErrorView(message: '$error'),
                    ),
                ],
              ),
            ),
          ],
        );

        final sidePanel = SizedBox(
          width: isWide ? 280 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected != null) ...[
                ContainerInspectorPanel(
                  container: selected,
                  onClose: () => ref.read(selectedContainerProvider.notifier).select(null),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: ContainerListPanel(
                  containers: visibleContainers,
                  selectedId: selectedId,
                  onSelect: selectAndFocus,
                ),
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: viewport),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.all(8), child: sidePanel),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: 320, child: viewport),
            Expanded(child: Padding(padding: const EdgeInsets.all(8), child: sidePanel)),
          ],
        );
      },
    );
  }
}
