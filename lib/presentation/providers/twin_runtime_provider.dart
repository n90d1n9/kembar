import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/runtime/twin_runtime.dart';
import '../../application/runtime/twin_runtime_controller.dart';
import 'twin_repository_provider.dart';

/// Provider for TwinRuntime.
/// 
/// This is the core digital twin kernel that maintains state.
final twinRuntimeProvider = Provider<TwinRuntime>((ref) {
  final runtime = TwinRuntime();

  ref.onDispose(runtime.dispose);

  return runtime;
});

/// Provider for TwinRuntimeController.
/// 
/// Manages the lifecycle of loading data into the runtime.
final twinRuntimeControllerProvider = Provider<TwinRuntimeController>((ref) {
  final repository = ref.watch(twinRepositoryProvider);
  final runtime = ref.watch(twinRuntimeProvider);

  final controller = TwinRuntimeController(
    repository: repository,
    runtime: runtime,
  );

  ref.onDispose(controller.stop);

  return controller;
});

/// AsyncNotifier provider that auto-starts the controller.
/// 
/// Use this when you want the runtime to automatically load data.
final twinRuntimeAutoStartProvider = FutureProvider<TwinRuntime>((ref) async {
  final controller = ref.watch(twinRuntimeControllerProvider);
  final runtime = ref.watch(twinRuntimeProvider);

  await controller.start();

  return runtime;
});
