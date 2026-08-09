import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/port_terminal/scene/yard_bounding_box.dart';
import '../../domain/entities/yard_block_layout.dart';

/// Windowing state per yard block — the practical answer to "viewport-
/// driven LOD" given what's actually available: flutter_3d_controller
/// doesn't expose camera position/frustum back to Flutter, so there's no
/// way to derive "what's visible" from the render engine itself. Instead
/// the *user* controls the window directly (a bay-range slider — see
/// YardWindowControl), which caps how many containers ever get built into
/// a scene at once.
///
/// Manual family notifier, Riverpod 2.x pattern (confirmed against
/// Riverpod's own migration notes): the base class for a family notifier
/// without codegen is `FamilyNotifier<State, Arg>`, not plain `Notifier`.
/// This changes in Riverpod 3.0 — update this class if this project ever
/// upgrades past flutter_riverpod ^2.x.
class YardWindowController extends FamilyNotifier<YardBoundingBox, String> {
  /// A conservative default that renders before the real layout has even
  /// loaded — 8 bays across all rows keeps the first paint small no
  /// matter how big the block turns out to be.
  static const _defaultWindow =
      YardBoundingBox(minBay: 1, maxBay: 8, minRow: 1, maxRow: 999);

  @override
  YardBoundingBox build(String blockId) => _defaultWindow;

  void setBayRange(int minBay, int maxBay) {
    state = YardBoundingBox(
      minBay: minBay,
      maxBay: maxBay,
      minRow: state.minRow,
      maxRow: state.maxRow,
    );
  }

  void showAllBays(int bayCount) {
    state = YardBoundingBox(
      minBay: 1,
      maxBay: bayCount,
      minRow: state.minRow,
      maxRow: state.maxRow,
    );
  }
}

final yardWindowProvider =
    NotifierProvider.family<YardWindowController, YardBoundingBox, String>(
  YardWindowController.new,
);
