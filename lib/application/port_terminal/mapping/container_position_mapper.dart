import '../../../domain/entities/yard_block_layout.dart';
import '../../../domain/value_objects/position3d.dart';
import '../../../domain/value_objects/yard_slot.dart';

/// Strategy interface for turning a yard slot into a real Cartesian
/// position. Kept abstract so alternative placement strategies (e.g. a
/// block with irregular bay spacing, or RTLS-corrected positions) can be
/// swapped in without touching [ContainerSceneBuilder] — Open/Closed.
abstract class ContainerPositionMapper {
  Position3D positionOf(YardSlot slot, YardBlockLayout layout);
}
