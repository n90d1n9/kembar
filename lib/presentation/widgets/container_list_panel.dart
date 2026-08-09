import 'package:flutter/material.dart';

import '../../domain/entities/container_twin.dart';
import '../theme/twin_status_colors.dart';

/// Reusable scrollable container list. flutter_3d_controller doesn't
/// document per-mesh tap picking, so selecting a container to inspect (or
/// to focus the camera on, via DigitalTwinViewport's controller) goes
/// through this list rather than a click on the 3D model itself.
class ContainerListPanel extends StatelessWidget {
  final List<ContainerTwin> containers;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const ContainerListPanel({
    super.key,
    required this.containers,
    required this.onSelect,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const Center(child: Text('No containers in this block yet'));
    }
    return ListView.builder(
      itemCount: containers.length,
      itemBuilder: (context, index) {
        final container = containers[index];
        final selected = container.id.value == selectedId;
        return ListTile(
          dense: true,
          selected: selected,
          leading: CircleAvatar(
            radius: 6,
            backgroundColor: twinStatusColors[container.status],
          ),
          title: Text(container.id.value, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          subtitle: Text(container.slot.toString()),
          onTap: () => onSelect(container.id.value),
        );
      },
    );
  }
}
