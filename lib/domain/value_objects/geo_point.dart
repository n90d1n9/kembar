/// A geodetic position (latitude/longitude/altitude). Kept separate from
/// [Position3D] on purpose: geo coordinates are for the terminal-level
/// overview (vessels, gates, the terminal itself on a real map) and for
/// GPS-tracked equipment — not for yard-slot container placement, which
/// uses exact bay/row/tier geometry instead.
class GeoPoint {
  final double latitude;
  final double longitude;
  final double altitudeM;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.altitudeM = 0,
  });
}
