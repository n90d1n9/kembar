import '../../domain/entities/yard_block_layout.dart';
import '../../domain/repositories/yard_layout_repository.dart';
import '../../domain/value_objects/position3d.dart';

/// Stand-in for a real terminal-engineering data source. Bay/row pitches
/// are realistic for a 20/40ft mixed block (bay pitch covers a 20ft slot
/// plus working gap; row pitch covers container width plus gutter; tier
/// height matches a standard 8'6" container) — swap for a real repository
/// backed by the terminal's actual yard survey without touching callers.
class FakeYardLayoutRepository implements YardLayoutRepository {
  static final Map<String, YardBlockLayout> _layouts = {
    'A': const YardBlockLayout(
      blockId: 'A',
      origin: Position3D(0, 0, 0),
      orientationDeg: 0,
      bayPitchM: 6.5,
      rowPitchM: 2.75,
      tierHeightM: 2.591,
      bayCount: 20,
      rowCount: 6,
      tierCount: 5,
    ),
  };

  @override
  Future<YardBlockLayout?> layoutFor(String blockId) async => _layouts[blockId];

  @override
  Future<List<String>> availableBlockIds() async => _layouts.keys.toList();
}
