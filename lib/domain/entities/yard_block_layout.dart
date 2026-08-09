import '../value_objects/position3d.dart';

/// The real physical geometry of one yard block, as it would come from the
/// terminal's engineering drawings: where the block sits, which way it
/// faces, and the true spacing between bays/rows/tiers. This is what makes
/// slot -> Cartesian conversion an exact placement rather than an estimate.
class YardBlockLayout {
  final String blockId;
  final Position3D origin;

  /// Rotation of the block's bay axis around the vertical (Y) axis, in
  /// degrees, for blocks that aren't aligned to the terminal's global grid.
  final double orientationDeg;

  final double bayPitchM;
  final double rowPitchM;
  final double tierHeightM;

  final int bayCount;
  final int rowCount;
  final int tierCount;

  const YardBlockLayout({
    required this.blockId,
    required this.origin,
    this.orientationDeg = 0,
    required this.bayPitchM,
    required this.rowPitchM,
    required this.tierHeightM,
    required this.bayCount,
    required this.rowCount,
    required this.tierCount,
  });
}
