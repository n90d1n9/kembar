import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/port_terminal/scene/container_scene_builder.dart';
import '../../application/port_terminal/scene/placed_container.dart';
import 'container_providers.dart';
import 'debounced_containers_providers.dart';
import 'repository_providers.dart';
import 'yard_layout_providers.dart';
import 'yard_window_providers.dart';

/// Placed-container view models straight from the *live* (not debounced)
/// container stream — cheap to recompute, since it's a pure in-memory
/// transform with no bytes/network/rendering involved. This is what the
/// native Canvas renderer watches directly, so it stays fully live: every
/// container mutation reaches it immediately.
final placedContainersProvider =
    Provider.family<List<PlacedContainer>, String>((ref, blockId) {
  final layout = ref.watch(yardBlockLayoutProvider(blockId)).valueOrNull;
  final containers = ref.watch(containersStreamProvider(blockId)).valueOrNull;
  final window = ref.watch(yardWindowProvider(blockId));
  if (layout == null || containers == null) return const [];

  final mapper = ref.watch(containerPositionMapperProvider);
  return ContainerSceneBuilder(mapper)
      .build(containers: containers, layout: layout, visibleRegion: window);
});

/// Combines the *debounced* container stream, the yard layout, and the
/// current bay-range window into GLB scene bytes. Deliberately watches
/// `debouncedContainersProvider` rather than the raw stream: regenerating
/// and reloading a whole GLB model on every single container mutation
/// would make the GLB path visibly reload constantly under any real rate
/// of live updates — debouncing coalesces a burst into one rebuild.
///
/// Written as a plain derived `Provider` (no codegen) — it watches
/// several other providers and manually folds their AsyncValues into
/// one. Because it `ref.watch`es `yardWindowProvider(blockId)` too,
/// sliding the window rebuilds the scene with only the containers inside
/// it — the actual mechanism behind "windowing", not just a filter
/// that's computed but never applied.
final twinGlbProvider =
    Provider.family<AsyncValue<Uint8List>, String>((ref, blockId) {
  final layoutAsync = ref.watch(yardBlockLayoutProvider(blockId));
  final debouncedContainers = ref.watch(debouncedContainersProvider(blockId));
  final window = ref.watch(yardWindowProvider(blockId));

  if (layoutAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (layoutAsync.hasError) {
    return AsyncValue.error(
        layoutAsync.error!, layoutAsync.stackTrace ?? StackTrace.current);
  }

  final layout = layoutAsync.valueOrNull;
  if (layout == null || debouncedContainers == null) {
    return const AsyncValue.loading();
  }

  try {
    final mapper = ref.watch(containerPositionMapperProvider);
    final builder = ContainerSceneBuilder(mapper);
    final placed = builder.build(
        containers: debouncedContainers, layout: layout, visibleRegion: window);

    final adapter = ref.watch(sceneRenderAdapterProvider);
    final bytes = adapter.buildGlb(placed, layout: layout);
    return AsyncValue.data(bytes);
  } catch (error, stackTrace) {
    return AsyncValue.error(error, stackTrace);
  }
});
