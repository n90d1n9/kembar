import '../value_objects/container_id.dart';
import '../value_objects/container_size.dart';
import '../value_objects/yard_slot.dart';
import 'container_status.dart';

/// The digital twin of one physical container: identity, real dimensions,
/// its assigned real yard address, and the operational state that a real
/// synchronization engine (OCR/RFID/gate events/manual input, per the wider
/// platform's twin-sync design) would keep up to date.
class ContainerTwin {
  final ContainerId id;
  final IsoContainerSize size;
  final YardSlot slot;
  final ContainerStatus status;
  final double weightKg;
  final String? ownerLine;
  final DateTime lastUpdated;

  const ContainerTwin({
    required this.id,
    required this.size,
    required this.slot,
    required this.status,
    required this.weightKg,
    this.ownerLine,
    required this.lastUpdated,
  });

  ContainerTwin copyWith({
    YardSlot? slot,
    ContainerStatus? status,
    double? weightKg,
    String? ownerLine,
    DateTime? lastUpdated,
  }) {
    return ContainerTwin(
      id: id,
      size: size,
      slot: slot ?? this.slot,
      status: status ?? this.status,
      weightKg: weightKg ?? this.weightKg,
      ownerLine: ownerLine ?? this.ownerLine,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
