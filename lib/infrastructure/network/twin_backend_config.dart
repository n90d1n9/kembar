/// Connection details for a real twin backend. Not used as the app's
/// default anywhere (there's no live backend to point it at in this
/// project) — it exists so switching FakeContainerRepository /
/// FakeYardLayoutRepository for WebSocketContainerRepository /
/// RestYardLayoutRepository is a matter of overriding two providers in
/// repository_providers.dart, not a rewrite.
///
/// Expected REST surface (adjust the repositories' path segments to match
/// your actual backend):
///   GET  {httpBaseUrl}blocks                      -> ["A", "B", ...]
///   GET  {httpBaseUrl}blocks/{blockId}/layout      -> YardBlockLayoutDto
///   GET  {httpBaseUrl}blocks/{blockId}/containers  -> [ContainerTwinDto, ...]
///
/// Expected WebSocket surface:
///   {wsBaseUrl}blocks/{blockId}/containers/stream
///   Server sends JSON text frames of the form:
///     {"type": "snapshot", "containers": [ContainerTwinDto, ...]}
///     {"type": "update", "container": ContainerTwinDto}
///     {"type": "remove", "id": "<containerId>"}
class TwinBackendConfig {
  final Uri httpBaseUrl;
  final Uri wsBaseUrl;

  TwinBackendConfig({required Uri httpBaseUrl, required Uri wsBaseUrl})
      : httpBaseUrl = _ensureTrailingSlash(_requireScheme(httpBaseUrl, const ['http', 'https'])),
        wsBaseUrl = _ensureTrailingSlash(_requireScheme(wsBaseUrl, const ['ws', 'wss']));

  // Uri.resolve() drops the base URL's last path segment unless the base
  // itself ends in '/' (standard RFC 3986 relative resolution) — every
  // repository below relies on resolve(), so normalizing once here avoids
  // a subtle, silent wrong-URL bug that would otherwise depend on whether
  // whoever constructs this remembered the trailing slash.
  static Uri _ensureTrailingSlash(Uri uri) {
    if (uri.path.endsWith('/')) return uri;
    return uri.replace(path: '${uri.path}/');
  }

  // Fail fast at construction time with a clear message, rather than a
  // confusing failure deep inside http.get or WebSocketChannel.connect
  // because someone passed an http:// URL where a ws:// one belonged.
  static Uri _requireScheme(Uri uri, List<String> allowed) {
    if (!allowed.contains(uri.scheme)) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Expected scheme to be one of $allowed, got "${uri.scheme}"',
      );
    }
    return uri;
  }
}
