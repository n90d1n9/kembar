import 'dart:html' as html;
import 'dart:typed_data';

import 'glb_hosting_strategy.dart';

GlbHostingStrategy createGlbHostingStrategy() => _BlobUrlGlbHostingStrategy();

/// Web implementation: hosts each generated GLB as a Blob object URL,
/// which model-viewer's `src` accepts natively as a web platform.
class _BlobUrlGlbHostingStrategy implements GlbHostingStrategy {
  @override
  Future<String> host(Uint8List bytes, String cacheKey) async {
    final blob = html.Blob([bytes], 'model/gltf-binary');
    return html.Url.createObjectUrlFromBlob(blob);
  }

  @override
  Future<void> release(String? src) async {
    if (src != null) html.Url.revokeObjectUrl(src);
  }
}
