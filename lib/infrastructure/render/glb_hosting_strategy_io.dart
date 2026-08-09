import 'dart:io';
import 'dart:typed_data';

import 'glb_hosting_strategy.dart';

GlbHostingStrategy createGlbHostingStrategy() => _LocalHttpGlbHostingStrategy();

/// Serves generated GLB scenes from an in-memory map over a
/// loopback-only HTTP server (dart:io — no extra dependency). This
/// sidesteps the open question of whether the 3D viewer's `src` accepts
/// arbitrary local file paths by giving every scene a real, documented-
/// to-work URL instead.
class _LocalHttpGlbHostingStrategy implements GlbHostingStrategy {
  Future<HttpServer>? _serverFuture;
  final Map<String, Uint8List> _scenes = {};

  // Caching the in-flight Future itself (not just the eventual HttpServer)
  // matters: if two host() calls land before the first bind completes,
  // `??=` assigns synchronously on the first call — before any awaiting —
  // so the second call reuses the same pending bind instead of starting a
  // second server and leaking the first one's open port.
  Future<HttpServer> _ensureServer() {
    return _serverFuture ??= _bindServer();
  }

  Future<HttpServer> _bindServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final segments = request.uri.pathSegments;
      final key = segments.isEmpty ? '' : segments.last.replaceAll('.glb', '');
      final bytes = _scenes[key];
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response
        ..headers.contentType = ContentType('model', 'gltf-binary')
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..add(bytes);
      await request.response.close();
    });
    return server;
  }

  @override
  Future<String> host(Uint8List bytes, String cacheKey) async {
    final server = await _ensureServer();
    _scenes[cacheKey] = bytes;
    return 'http://${server.address.address}:${server.port}/$cacheKey.glb';
  }

  @override
  Future<void> release(String? src) async {
    if (src == null) return;
    final segments = Uri.parse(src).pathSegments;
    if (segments.isEmpty) return;
    _scenes.remove(segments.last.replaceAll('.glb', ''));
  }
}
