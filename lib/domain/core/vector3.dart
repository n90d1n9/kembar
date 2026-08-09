class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(
    this.x,
    this.y,
    this.z,
  );

  const Vector3.zero() : this(0, 0, 0);

  Vector3 operator +(Vector3 other) {
    return Vector3(
      x + other.x,
      y + other.y,
      z + other.z,
    );
  }

  Vector3 operator -(Vector3 other) {
    return Vector3(
      x - other.x,
      y - other.y,
      z - other.z,
    );
  }

  Vector3 operator *(double scalar) {
    return Vector3(
      x * scalar,
      y * scalar,
      z * scalar,
    );
  }

  Vector3 operator -() {
    return Vector3(-x, -y, -z);
  }

  double get length => (x * x + y * y + z * z).sqrt();

  @override
  bool operator ==(Object other) {
    return other is Vector3 &&
        other.x == x &&
        other.y == y &&
        other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vector3($x, $y, $z)';

  static Vector3 all(double value) => Vector3(value, value, value);
}
