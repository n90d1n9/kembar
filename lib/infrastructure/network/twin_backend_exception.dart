/// Thrown by the network-backed repositories. Deliberately not `dart:io`'s
/// `HttpException` — that type doesn't exist on web builds, and these
/// repositories (via package:http and package:web_socket_channel) are
/// meant to work on every platform this app targets.
class TwinBackendException implements Exception {
  final String message;

  const TwinBackendException(this.message);

  @override
  String toString() => 'TwinBackendException: $message';
}
