import 'dart:math' as math;

import '../../../domain/entities/yard_block_layout.dart';
import '../../../domain/value_objects/position3d.dart';
import '../../../domain/value_objects/yard_slot.dart';
import 'container_position_mapper.dart';

/// Converts a bay/row/tier slot into a real-world Cartesian position using
/// the block's true physical pitches, honoring the block's own orientation
/// if it isn't aligned to the terminal's global axes.
///
/// bay  -> local X (along the block's length)
/// row  -> local Z (across the block's width)
/// tier -> local Y (stack height; tier 1 sits on the ground)
class SlotPositionMapper implements ContainerPositionMapper {
  const SlotPositionMapper();

  @override
  Position3D positionOf(YardSlot slot, YardBlockLayout layout) {
    final localX = (slot.bay - 1) * layout.bayPitchM;
    final localZ = (slot.row - 1) * layout.rowPitchM;
    final localY = (slot.tier - 1) * layout.tierHeightM;

    final theta = layout.orientationDeg * math.pi / 180.0;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    final rotatedX = localX * cosT - localZ * sinT;
    final rotatedZ = localX * sinT + localZ * cosT;

    return Position3D(
      layout.origin.x + rotatedX,
      layout.origin.y + localY,
      layout.origin.z + rotatedZ,
    );
  }
}
