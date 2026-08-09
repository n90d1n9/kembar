import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/yard_block_layout.dart';
import 'repository_providers.dart';

final yardBlockLayoutProvider = FutureProvider.family<YardBlockLayout, String>((ref, blockId) async {
  final repository = ref.watch(yardLayoutRepositoryProvider);
  final layout = await repository.layoutFor(blockId);
  if (layout == null) {
    throw StateError('No yard layout found for block "$blockId"');
  }
  return layout;
});

final availableBlockIdsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(yardLayoutRepositoryProvider).availableBlockIds();
});
