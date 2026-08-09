import 'twin_component.dart';
import 'vector3.dart';

class SpatialComponent implements TwinComponent {
  final Vector3 position;
  final Vector3 rotation;
  final Vector3 scale;

  const SpatialComponent({
    required this.position,
    this.rotation = const Vector3(0, 0, 0),
    this.scale = const Vector3(1, 1, 1),
  });

  @override
  String get type => 'spatial';
}
