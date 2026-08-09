import '../../../domain/entities/yard_block_layout.dart';
import '../../../domain/value_objects/position3d.dart';
import '../twin_backend_exception.dart';

/// Wire-format DTO for a block's engineering layout — see
/// TwinBackendConfig's doc comment for the expected JSON shape.
class YardBlockLayoutDto {
  final String blockId;
  final double originX;
  final double originY;
  final double originZ;
  final double orientationDeg;
  final double bayPitchM;
  final double rowPitchM;
  final double tierHeightM;
  final int bayCount;
  final int rowCount;
  final int tierCount;

  const YardBlockLayoutDto({
    required this.blockId,
    required this.originX,
    required this.originY,
    required this.originZ,
    required this.orientationDeg,
    required this.bayPitchM,
    required this.rowPitchM,
    required this.tierHeightM,
    required this.bayCount,
    required this.rowCount,
    required this.tierCount,
  });

  factory YardBlockLayoutDto.fromJson(Map<String, dynamic> json) {
    try {
      return YardBlockLayoutDto(
        blockId: json['blockId'] as String,
        originX: ((json['originX'] as num?) ?? 0).toDouble(),
        originY: ((json['originY'] as num?) ?? 0).toDouble(),
        originZ: ((json['originZ'] as num?) ?? 0).toDouble(),
        orientationDeg: ((json['orientationDeg'] as num?) ?? 0).toDouble(),
        bayPitchM: (json['bayPitchM'] as num).toDouble(),
        rowPitchM: (json['rowPitchM'] as num).toDouble(),
        tierHeightM: (json['tierHeightM'] as num).toDouble(),
        bayCount: (json['bayCount'] as num).toInt(),
        rowCount: (json['rowCount'] as num).toInt(),
        tierCount: (json['tierCount'] as num).toInt(),
      );
    } on TypeError catch (error) {
      throw TwinBackendException('Malformed yard layout payload: $error');
    }
  }

  YardBlockLayout toDomain() {
    return YardBlockLayout(
      blockId: blockId,
      origin: Position3D(originX, originY, originZ),
      orientationDeg: orientationDeg,
      bayPitchM: bayPitchM,
      rowPitchM: rowPitchM,
      tierHeightM: tierHeightM,
      bayCount: bayCount,
      rowCount: rowCount,
      tierCount: tierCount,
    );
  }
}
