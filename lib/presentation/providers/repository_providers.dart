import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/mapping/container_position_mapper.dart';
import '../../application/mapping/slot_position_mapper.dart';
import '../../domain/repositories/container_repository.dart';
import '../../domain/repositories/yard_layout_repository.dart';
import '../../infrastructure/network/twin_backend_config.dart';
import '../../infrastructure/render/glb_hosting_strategy_factory.dart';
import '../../infrastructure/render/lite3d_scene_render_adapter.dart';
import '../../infrastructure/render/scene_render_adapter.dart';
import '../../infrastructure/repositories/fake_container_repository.dart';
import '../../infrastructure/repositories/fake_yard_layout_repository.dart';
import '../../infrastructure/repositories/rest_yard_layout_repository.dart';
import '../../infrastructure/repositories/websocket_container_repository.dart';

/// All dependency wiring lives here, as plain (non-generated) Riverpod
/// `Provider`s.
///
/// [twinBackendConfigProvider] is the single switch between demo and real
/// data: it's `null` by default, which is what keeps `flutter run` working
/// out of the box with no backend at all. Point it at a real backend from
/// app startup — nothing else in this file, or any widget, needs to
/// change:
///
/// ```dart
/// runApp(ProviderScope(
///   overrides: [
///     twinBackendConfigProvider.overrideWithValue(
///       TwinBackendConfig(
///         httpBaseUrl: Uri.parse('https://your-backend.example.com/twin/'),
///         wsBaseUrl: Uri.parse('wss://your-backend.example.com/twin/'),
///       ),
///     ),
///   ],
///   child: const TerminalDigitalTwinApp(),
/// ));
/// ```
final twinBackendConfigProvider = Provider<TwinBackendConfig?>((ref) => null);

final yardLayoutRepositoryProvider = Provider<YardLayoutRepository>((ref) {
  final backend = ref.watch(twinBackendConfigProvider);
  if (backend != null) {
    final repository = RestYardLayoutRepository(backend);
    ref.onDispose(repository.dispose);
    return repository;
  }
  return FakeYardLayoutRepository();
});

final containerRepositoryProvider = Provider<ContainerRepository>((ref) {
  final backend = ref.watch(twinBackendConfigProvider);
  if (backend != null) {
    final repository = WebSocketContainerRepository(backend);
    ref.onDispose(repository.dispose);
    return repository;
  }
  return FakeContainerRepository();
});

final containerPositionMapperProvider = Provider<ContainerPositionMapper>((ref) {
  return const SlotPositionMapper();
});

final sceneRenderAdapterProvider = Provider<SceneRenderAdapter>((ref) {
  return const Lite3dSceneRenderAdapter();
});

final glbHostingStrategyProvider = Provider<GlbHostingStrategy>((ref) {
  return createGlbHostingStrategy();
});
