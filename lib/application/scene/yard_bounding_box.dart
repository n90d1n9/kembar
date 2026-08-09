import '../../domain/value_objects/yard_slot.dart';

/// A bay/row window used to cap how many containers get placed into a
/// scene at once. lite_3d_core's own docs note its GLB export is tuned
/// for tens-to-low-hundreds of nodes, not the thousands a real yard block
/// can hold — this is the hook for viewport-driven windowing / LOD.
class YardBoundingBox {
  final int minBay;
  final int maxBay;
  final int minRow;
  final int maxRow;

  const YardBoundingBox({
    required this.minBay,
    required this.maxBay,
    required this.minRow,
    required this.maxRow,
  });

  bool contains(YardSlot slot) =>
      slot.bay >= minBay && slot.bay <= maxBay && slot.row >= minRow && slot.row <= maxRow;
}
