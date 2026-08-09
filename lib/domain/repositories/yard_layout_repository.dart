import '../entities/yard_block_layout.dart';

abstract class YardLayoutRepository {
  Future<YardBlockLayout?> layoutFor(String blockId);

  Future<List<String>> availableBlockIds();
}
