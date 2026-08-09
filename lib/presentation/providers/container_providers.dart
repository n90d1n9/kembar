import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/container_twin.dart';
import 'repository_providers.dart';

final containersStreamProvider = StreamProvider.family<List<ContainerTwin>, String>((ref, blockId) {
  final repository = ref.watch(containerRepositoryProvider);
  return repository.watchContainers(blockId: blockId);
});
