import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/container_twin.dart';
import 'container_providers.dart';

/// A debounced view of the live container stream, used only by the GLB
/// rendering path (see twinGlbProvider). Regenerating + re-hosting +
/// reloading a whole 3D model is expensive enough that reacting to every
/// single container mutation individually would make a "live" twin
/// visibly reload on every event; this coalesces a rapid burst into one
/// rebuild after 400ms of quiet, while still applying the very first
/// snapshot immediately so the initial paint isn't delayed.
///
/// Manual family notifier (Riverpod 2.x's `FamilyNotifier<State, Arg>` —
/// see yard_window_providers.dart for why that base class specifically).
class DebouncedContainersController extends FamilyNotifier<List<ContainerTwin>?, String> {
  Timer? _debounceTimer;
  bool _receivedFirst = false;

  @override
  List<ContainerTwin>? build(String blockId) {
    ref.listen<AsyncValue<List<ContainerTwin>>>(
      containersStreamProvider(blockId),
      (previous, next) {
        // NOTE: an error state on the underlying stream is silently
        // dropped here (valueOrNull is null for both loading AND error).
        // Neither FakeContainerRepository nor WebSocketContainerRepository
        // ever puts an *error* on the stream itself today (the WebSocket
        // one handles failures internally via reconnect, never
        // controller.addError) — but a future repository that does would
        // need this listener to also check next.hasError and propagate
        // it, which this doesn't do.
        final data = next.valueOrNull;
        if (data == null) return;

        if (!_receivedFirst) {
          _receivedFirst = true;
          state = data; // first snapshot applies immediately
          return;
        }

        // Re-scheduling on every event (rather than letting an earlier
        // timer fire on schedule) is what makes this trailing-edge: only
        // the last update in a burst ever actually lands, and it always
        // captures the freshest `data` from whichever call scheduled it.
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 400), () {
          state = data;
        });
      },
      fireImmediately: true,
    );

    ref.onDispose(() => _debounceTimer?.cancel());
    return null;
  }
}

final debouncedContainersProvider =
    NotifierProvider.family<DebouncedContainersController, List<ContainerTwin>?, String>(
  DebouncedContainersController.new,
);
