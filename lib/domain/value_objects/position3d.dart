/// A real-world Cartesian position in meters (X = along block bays,
/// Y = height/up, Z = across block rows), local to the terminal's own
/// coordinate origin. Deliberately independent of any rendering package —
/// the domain layer must not know lite_3d_core's Vec3 exists.
class Position3D {
  final double x;
  final double y;
  final double z;

  const Position3D(this.x, this.y, this.z);

  Position3D translate({double dx = 0, double dy = 0, double dz = 0}) =>
      Position3D(x + dx, y + dy, z + dz);

  @override
  bool operator ==(Object other) =>
      other is Position3D && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Position3D($x, $y, $z)';
}
