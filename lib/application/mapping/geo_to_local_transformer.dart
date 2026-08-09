import 'dart:math' as math;

import '../../domain/value_objects/geo_point.dart';
import '../../domain/value_objects/position3d.dart';

/// Strategy interface for placing geo-tracked assets (trucks, cranes,
/// vessels) into the same local Cartesian space the yard twin uses. Not
/// wired into the container demo (containers use exact slot placement,
/// not GPS) — provided as the Open/Closed extension point for the other
/// twin types the wider platform design calls out.
abstract class GeoToLocalTransformer {
  Position3D toLocal(GeoPoint point);
}

/// A local tangent-plane (equirectangular) approximation: accurate enough
/// for a terminal's footprint (up to a few km across) but NOT a proper
/// geodetic projection — do not reuse this for large-area mapping.
class EquirectangularGeoTransformer implements GeoToLocalTransformer {
  final GeoPoint origin;

  const EquirectangularGeoTransformer(this.origin);

  static const double _metersPerDegLat = 111320.0;

  @override
  Position3D toLocal(GeoPoint point) {
    final metersPerDegLon = _metersPerDegLat * math.cos(origin.latitude * math.pi / 180.0);
    final x = (point.longitude - origin.longitude) * metersPerDegLon;
    final z = (point.latitude - origin.latitude) * _metersPerDegLat;
    return Position3D(x, point.altitudeM, z);
  }
}
