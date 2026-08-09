import 'dart:async';

import '../domain/core/twin_entity.dart';
import '../domain/core/twin_event.dart';
import '../repositories/twin_repository.dart';
import 'twin_runtime.dart';

/// Controller that manages the lifecycle of TwinRuntime.
/// 
/// It:
/// 1. Loads initial snapshot from repository
/// 2. Subscribes to live events from repository
/// 3. Applies all events to the runtime
/// 
/// This is the bridge between the data layer (repository) and the kernel (runtime).
class TwinRuntimeController {
  final TwinRepository repository;
  final TwinRuntime runtime;

  StreamSubscription? _subscription;
  bool _started = false;

  TwinRuntimeController({
    required this.repository,
    required this.runtime,
  });

  /// Start listening to repository events.
  /// 
  /// First loads the initial snapshot, then subscribes to live updates.
  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    // Load initial snapshot
    final entities = await repository.fetchEntities();

    for (final entity in entities) {
      runtime.apply(
        EntityCreated(entity),
      );
    }

    // Subscribe to live events
    _subscription = repository.watch().listen(
      runtime.apply,
    );
  }

  /// Stop listening to repository events.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Restart the controller.
  Future<void> restart() async {
    await stop();
    await start();
  }
}
