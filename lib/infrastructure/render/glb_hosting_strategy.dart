import 'dart:typed_data';

/// Gives a generated GLB scene a URL that [Flutter3DViewer] can load.
///
/// flutter_3d_controller's documented `src` supports Flutter assets and
/// URLs, not confirmed arbitrary local file paths — so rather than guess,
/// each platform implementation hosts the bytes behind a real URL: a
/// loopback-only HTTP server on native platforms, a Blob object URL on
/// web. See glb_hosting_strategy_io.dart / glb_hosting_strategy_web.dart.
abstract class GlbHostingStrategy {
  Future<String> host(Uint8List bytes, String cacheKey);

  Future<void> release(String? src);
}
