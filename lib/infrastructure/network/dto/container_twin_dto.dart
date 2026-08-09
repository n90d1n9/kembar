import '../../../domain/entities/container_status.dart';
import '../../../domain/entities/container_twin.dart';
import '../../../domain/value_objects/container_id.dart';
import '../../../domain/value_objects/container_size.dart';
import '../../../domain/value_objects/yard_slot.dart';
import '../twin_backend_exception.dart';

/// Wire-format DTO for one container, and the only place that knows the
/// JSON shape — see TwinBackendConfig's doc comment for the expected
/// fields. Keeping this separate from [ContainerTwin] means the domain
/// entity never has to change if the backend's JSON shape does, and the
/// domain layer stays free of any serialization concern at all.
class ContainerTwinDto {
  final String id;
  final String isoSize;
  final String block;
  final int bay;
  final int row;
  final int tier;
  final String status;
  final double weightKg;
  final String? ownerLine;
  final String lastUpdated;

  const ContainerTwinDto({
    required this.id,
    required this.isoSize,
    required this.block,
    required this.bay,
    required this.row,
    required this.tier,
    required this.status,
    required this.weightKg,
    this.ownerLine,
    required this.lastUpdated,
  });

  factory ContainerTwinDto.fromJson(Map<String, dynamic> json) {
    try {
      return ContainerTwinDto(
        id: json['id'] as String,
        isoSize: json['isoSize'] as String,
        block: json['block'] as String,
        bay: (json['bay'] as num).toInt(),
        row: (json['row'] as num).toInt(),
        tier: (json['tier'] as num).toInt(),
        status: json['status'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        ownerLine: json['ownerLine'] as String?,
        lastUpdated: json['lastUpdated'] as String,
      );
    } on TypeError catch (error) {
      throw TwinBackendException('Malformed container payload: $error');
    }
  }

  ContainerTwin toDomain() {
    return ContainerTwin(
      id: ContainerId(id),
      size: _parseIsoSize(isoSize),
      slot: YardSlot(blockId: block, bay: bay, row: row, tier: tier),
      status: _parseStatus(status),
      weightKg: weightKg,
      ownerLine: ownerLine,
      lastUpdated: DateTime.parse(lastUpdated),
    );
  }

  static IsoContainerSize _parseIsoSize(String value) {
    for (final size in IsoContainerSize.values) {
      if (size.name == value) return size;
    }
    throw TwinBackendException('Unknown ISO container size "$value"');
  }

  static ContainerStatus _parseStatus(String value) {
    for (final status in ContainerStatus.values) {
      if (status.name == value) return status;
    }
    throw TwinBackendException('Unknown container status "$value"');
  }
}
