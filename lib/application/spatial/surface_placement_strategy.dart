import 'package:vector_math/vector_math_64.dart' as vm;

import '../../domain/spatial/placement_request.dart';
import '../../domain/spatial/placement_surface.dart';
import '../../domain/spatial/spatial_relation.dart';
import 'placement_candidate.dart';
import 'spatial_world.dart';

/// Placement strategy for placing objects on horizontal surfaces.
class SurfacePlacementStrategy {
  const SurfacePlacementStrategy();

  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.model(request.subjectId);

    if (subject == null) {
      return const [];
    }

    final surfaces = world.surfacesFor(request.targetId);
    final candidates = <PlacementCandidate>[];

    for (final surface in surfaces) {
      if (surface.type != PlacementSurfaceType.horizontal) {
        continue;
      }

      // Generate candidates at center and preferred position
      final center = surface.bounds.center;
      
      // Get subject dimensions from the model
      final subjectBounds = subject.localBounds as dynamic;
      final halfHeight = subjectBounds.height / 2;
      final y = surface.height + halfHeight;

      // Center candidate
      candidates.add(
        PlacementCandidate(
          position: vm.Vector3(center.x, y, center.z),
          surfaceId: surface.id,
        ),
      );

      // Preferred position candidate if provided
      if (request.preferredPosition != null) {
        final clamped = _clampToSurface(
          request.preferredPosition!,
          surface,
          subjectBounds.width / 2,
          subjectBounds.depth / 2,
        );
        
        candidates.add(
          PlacementCandidate(
            position: vm.Vector3(clamped.x, y, clamped.z),
            surfaceId: surface.id,
          ),
        );
      }
    }

    return candidates;
  }

  vm.Vector3 _clampToSurface(
    vm.Vector3 preferred,
    PlacementSurface surface,
    double halfWidth,
    double halfDepth,
  ) {
    final minX = surface.bounds.min.x + halfWidth;
    final maxX = surface.bounds.max.x - halfWidth;
    final minZ = surface.bounds.min.z + halfDepth;
    final maxZ = surface.bounds.max.z - halfDepth;

    return vm.Vector3(
      preferred.x.clamp(minX, maxX),
      surface.height,
      preferred.z.clamp(minZ, maxZ),
    );
  }
}
