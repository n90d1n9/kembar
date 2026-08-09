import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/yard_block_layout.dart';
import '../providers/yard_window_providers.dart';

/// Reusable bay-range control. This is the actual scale mechanism for
/// this rendering approach: since flutter_3d_controller can't report
/// camera/frustum state back to Flutter, there's no way to derive "what's
/// currently visible" automatically — the user narrows the window
/// directly instead, and that's what keeps the node count within
/// lite_3d_core's comfortable range on a large block.
class YardWindowControl extends ConsumerWidget {
  final String blockId;
  final YardBlockLayout layout;

  const YardWindowControl({super.key, required this.blockId, required this.layout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(yardWindowProvider(blockId));
    final controller = ref.read(yardWindowProvider(blockId).notifier);

    final bayCount = layout.bayCount;
    final minBay = window.minBay.clamp(1, bayCount).toInt();
    final maxBay = window.maxBay.clamp(1, bayCount).toInt();
    final isShowingAll = minBay == 1 && maxBay == bayCount;

    return Row(
      children: [
        const Icon(Icons.view_column_outlined, size: 18),
        const SizedBox(width: 8),
        Text(
          'Bays $minBay–$maxBay of $bayCount',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Expanded(
          child: bayCount > 1
              ? RangeSlider(
                  min: 1,
                  max: bayCount.toDouble(),
                  divisions: bayCount - 1,
                  values: RangeValues(minBay.toDouble(), maxBay.toDouble()),
                  labels: RangeLabels('$minBay', '$maxBay'),
                  onChanged: (values) => controller.setBayRange(
                    values.start.round(),
                    values.end.round(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: isShowingAll ? null : () => controller.showAllBays(bayCount),
          child: const Text('Show all'),
        ),
      ],
    );
  }
}
