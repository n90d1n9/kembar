import 'package:flutter/material.dart';

import '../../domain/entities/container_twin.dart';
import '../theme/twin_status_colors.dart';

/// Reusable detail panel for a single container twin. Pure presentation —
/// takes the entity and a close callback, nothing else.
class ContainerInspectorPanel extends StatelessWidget {
  final ContainerTwin? container;
  final VoidCallback? onClose;

  const ContainerInspectorPanel({super.key, this.container, this.onClose});

  @override
  Widget build(BuildContext context) {
    final container = this.container;
    if (container == null) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(container.id.value, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    tooltip: 'Close',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _row(context, 'Slot', container.slot.toString()),
            _row(context, 'Size', container.size.name),
            _row(context, 'Status', twinStatusLabel(container.status)),
            _row(context, 'Weight', '${container.weightKg.toStringAsFixed(0)} kg'),
            if (container.ownerLine != null) _row(context, 'Line', container.ownerLine!),
            _row(context, 'Updated', _formatTime(container.lastUpdated)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
