import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/yard_block_layout.dart';
import '../../domain/repositories/yard_layout_repository.dart';
import '../network/dto/yard_block_layout_dto.dart';
import '../network/twin_backend_config.dart';
import '../network/twin_backend_exception.dart';

/// Real, HTTP-backed [YardLayoutRepository]. Not the app's default (see
/// repository_providers.dart) — override `yardLayoutRepositoryProvider`
/// with this once a real backend exists at [config].
class RestYardLayoutRepository implements YardLayoutRepository {
  final TwinBackendConfig config;
  final http.Client _client;

  RestYardLayoutRepository(this.config, {http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<YardBlockLayout?> layoutFor(String blockId) async {
    final uri = config.httpBaseUrl.resolve('blocks/$blockId/layout');
    final response = await _client.get(uri);

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw TwinBackendException(
        'Failed to load layout for block "$blockId": HTTP ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return YardBlockLayoutDto.fromJson(json).toDomain();
  }

  @override
  Future<List<String>> availableBlockIds() async {
    final uri = config.httpBaseUrl.resolve('blocks');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw TwinBackendException('Failed to list blocks: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    return json.cast<String>();
  }

  /// Releases the underlying HTTP client's resources. Call this when the
  /// repository itself is being disposed (e.g. from a Riverpod
  /// `ref.onDispose` if this is ever provided via a scoped provider).
  void dispose() => _client.close();
}
