import 'package:flutter/material.dart';

import '../../domain/entities/container_status.dart';
import '../theme/twin_status_colors.dart';

/// Reusable status legend. Takes the status set as data rather than
/// hardcoding it, so it isn't tied to containers specifically.
class YardLegend extends StatelessWidget {
  final Map<ContainerStatus, Color> palette;

  const YardLegend({super.key, this.palette = twinStatusColors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final entry in palette.entries) _LegendChip(status: entry.key, color: entry.value),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final ContainerStatus status;
  final Color color;

  const _LegendChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(twinStatusLabel(status), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
