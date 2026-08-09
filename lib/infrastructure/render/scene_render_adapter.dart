import 'dart:typed_data';

import '../../application/scene/placed_container.dart';
import '../../domain/entities/yard_block_layout.dart';

/// Abstraction over "turn placed containers into a renderable binary
/// scene". Today the only implementation targets lite_3d_core/GLB, but
/// nothing above this layer knows that — swapping render engines later
/// (matching lite_3d_core's own backend-abstraction philosophy) means
/// writing a new adapter, not touching scene-building or UI code.
abstract class SceneRenderAdapter {
  Uint8List buildGlb(List<PlacedContainer> containers, {YardBlockLayout? layout});
}
