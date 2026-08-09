/// A container's assigned yard address: block, bay, row, tier. This is the
/// "real position" the digital twin is built from — everything downstream
/// (Position3D, the rendered scene) is derived from it, never guessed.
class YardSlot {
  final String blockId;
  final int bay;
  final int row;
  final int tier;

  const YardSlot({
    required this.blockId,
    required this.bay,
    required this.row,
    required this.tier,
  });

  @override
  String toString() =>
      '$blockId-${bay.toString().padLeft(2, '0')}-${row.toString().padLeft(2, '0')}-$tier';

  @override
  bool operator ==(Object other) =>
      other is YardSlot &&
      other.blockId == blockId &&
      other.bay == bay &&
      other.row == row &&
      other.tier == tier;

  @override
  int get hashCode => Object.hash(blockId, bay, row, tier);
}
