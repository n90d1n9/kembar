import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/container_twin.dart';
import '../../domain/repositories/container_repository.dart';
import '../network/dto/container_twin_dto.dart';
import '../network/twin_backend_config.dart';
import '../network/twin_backend_exception.dart';

/// Real, WebSocket-backed [ContainerRepository] with REST snapshot fallback
/// for [fetchContainers]. Not the app's default (see
/// repository_providers.dart) — override `containerRepositoryProvider`
/// with this once a real backend exists at [config].
///
/// Unlike FakeContainerRepository (whose polling timer runs forever once
/// started), this repository ties the real socket's lifetime to actual
/// listener count via the broadcast StreamController's onListen/onCancel:
/// connect on first subscriber, disconnect on last one leaving. That only
/// matters in practice if the providers wrapping this are `.autoDispose` —
/// a plain (non-autoDispose) `StreamProvider.family` keeps at least one
/// internal subscription alive for the app's lifetime once first read, so
/// onCancel won't fire during normal navigation. Worth knowing if you
/// wire this in and expect the socket to close when a screen is popped.
class WebSocketContainerRepository implements ContainerRepository {
  final TwinBackendConfig config;
  final http.Client _httpClient;

  WebSocketContainerRepository(this.config, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final Map<String, StreamController<List<ContainerTwin>>> _controllers = {};
  final Map<String, Map<String, ContainerTwin>> _cache = {};
  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, StreamSubscription<dynamic>> _channelSubscriptions = {};
  final Map<String, Timer> _reconnectTimers = {};
  final Map<String, int> _reconnectAttempts = {};

  @override
  Stream<List<ContainerTwin>> watchContainers({required String blockId}) {
    final existing = _controllers[blockId];
    if (existing != null) return existing.stream;

    late final StreamController<List<ContainerTwin>> controller;
    controller = StreamController<List<ContainerTwin>>.broadcast(
      onListen: () => _connect(blockId, controller),
      onCancel: () => _teardown(blockId),
    );
    _controllers[blockId] = controller;
    return controller.stream;
  }

  void _connect(String blockId, StreamController<List<ContainerTwin>> controller) {
    final uri = config.wsBaseUrl.resolve('blocks/$blockId/containers/stream');
    final channel = WebSocketChannel.connect(uri);
    _channels[blockId] = channel;
    _reconnectAttempts[blockId] = 0;

    // channel.stream's onDone/onError covers a connection that drops
    // after being established; channel.ready covers one that never
    // establishes in the first place — both paths should trigger the
    // same reconnect logic rather than leaving the stream silently dead.
    unawaited(channel.ready.catchError((Object _) {
      _scheduleReconnect(blockId, controller);
    }));

    _channelSubscriptions[blockId] = channel.stream.listen(
      (dynamic raw) => _handleMessage(blockId, raw, controller),
      onError: (Object _) => _scheduleReconnect(blockId, controller),
      onDone: () => _scheduleReconnect(blockId, controller),
      cancelOnError: true,
    );
  }

  void _handleMessage(
    String blockId,
    dynamic raw,
    StreamController<List<ContainerTwin>> controller,
  ) {
    if (controller.isClosed) return;
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final cache = _cache.putIfAbsent(blockId, () => {});

      if (type == 'snapshot') {
        cache.clear();
        for (final item in json['containers'] as List<dynamic>) {
          final twin = ContainerTwinDto.fromJson(item as Map<String, dynamic>).toDomain();
          cache[twin.id.value] = twin;
        }
      } else if (type == 'update') {
        final twin = ContainerTwinDto.fromJson(json['container'] as Map<String, dynamic>).toDomain();
        cache[twin.id.value] = twin;
      } else if (type == 'remove') {
        final id = json['id'] as String?;
        if (id != null) cache.remove(id);
      } else {
        return; // Unknown message type — ignore rather than crash the stream.
      }

      controller.add(cache.values.toList(growable: false));
    } catch (_) {
      // A single malformed message shouldn't take down an otherwise-live
      // stream — drop it and keep listening for the next one.
    }
  }

  void _scheduleReconnect(String blockId, StreamController<List<ContainerTwin>> controller) {
    if (controller.isClosed) return;
    // Both channel.ready.catchError and channel.stream's onError/onDone
    // can fire for the same underlying failure — this guard keeps a
    // single failure from scheduling two reconnects (and double-counting
    // the backoff attempt) instead of relying on cancel-and-replace.
    if (_reconnectTimers.containsKey(blockId)) return;

    unawaited(_channelSubscriptions.remove(blockId)?.cancel());
    _channels.remove(blockId);

    final attempt = (_reconnectAttempts[blockId] ?? 0) + 1;
    _reconnectAttempts[blockId] = attempt;
    // Exponential backoff capped at 30s: 2s, 4s, 8s, 16s, 30s, 30s, ...
    final backoffSeconds = math.min(30, 1 << math.min(attempt, 5));

    _reconnectTimers[blockId] = Timer(Duration(seconds: backoffSeconds), () {
      _reconnectTimers.remove(blockId);
      if (!controller.isClosed) _connect(blockId, controller);
    });
  }

  void _teardown(String blockId) {
    _reconnectTimers.remove(blockId)?.cancel();
    unawaited(_channelSubscriptions.remove(blockId)?.cancel());
    unawaited(_channels.remove(blockId)?.sink.close());
    _reconnectAttempts.remove(blockId);
    _cache.remove(blockId);
    // Closing the controller matters beyond cleanup: every reconnect path
    // guards on `controller.isClosed` before doing anything, including a
    // late-firing `channel.ready.catchError` that can still land after
    // teardown has otherwise finished. Without this close(), such a
    // straggler would see `isClosed == false` and happily reconnect a
    // socket for a session nothing is tracking anymore. Remove from
    // _controllers last so a concurrent watchContainers() call can't
    // observe a half-torn-down entry still in the map.
    final controller = _controllers.remove(blockId);
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  Future<List<ContainerTwin>> fetchContainers({required String blockId}) async {
    final uri = config.httpBaseUrl.resolve('blocks/$blockId/containers');
    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw TwinBackendException(
        'Failed to fetch containers for block "$blockId": HTTP ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((dynamic item) => ContainerTwinDto.fromJson(item as Map<String, dynamic>).toDomain())
        .toList();
  }

  /// Closes every open socket/subscription and the HTTP client. Call this
  /// when the repository itself is being disposed.
  void dispose() {
    for (final blockId in _controllers.keys.toList()) {
      _teardown(blockId);
    }
    _httpClient.close();
  }
}
