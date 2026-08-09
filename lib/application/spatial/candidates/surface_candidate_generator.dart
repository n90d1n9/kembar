import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../domain/spatial/placement_request.dart';
import '../../../domain/spatial/placement_surface.dart';
import '../../../domain/spatial/bounds.dart';
import '../placement_candidate.dart';
import '../spatial_world.dart';
import 'candidate_generator.dart';

/// Configuration for grid-based candidate sampling.
class GridSamplingConfig {
  /// Distance between grid points in meters.
  final double spacing;

  /// Maximum number of columns to generate.
  final int maxColumns;

  /// Maximum number of rows to generate.
  final int maxRows;

  const GridSamplingConfig({
    this.spacing = 0.25,
    this.maxColumns = 20,
    this.maxRows = 20,
  });
}

/// Candidate generator that samples positions on horizontal surfaces.
///
/// This generator creates candidates at:
/// - The user's preferred position (if provided)
/// - Surface center
/// - A local grid around the preferred position
/// - Edge midpoints
/// - Corners
///
/// All positions are clamped to the "usable bounds" of the surface,
/// which accounts for the dimensions of the object being placed to
/// prevent overhang.
class SurfaceCandidateGenerator implements CandidateGenerator {
  final GridSamplingConfig grid;

  const SurfaceCandidateGenerator({
    this.grid = const GridSamplingConfig(),
  });

  @override
  List<PlacementCandidate> generate(
    PlacementRequest request,
    SpatialWorld world,
  ) {
    final subject = world.component(request.subjectId);

    if (subject == null) {
      return const [];
    }

    final candidates = <PlacementCandidate>[];

    final surfaces = world.component(request.targetId)?.surfaces ?? const [];

    for (final surface in surfaces) {
      if (surface.type != PlacementSurfaceType.horizontal) {
        continue;
      }

      candidates.addAll(
        _generateForSurface(subject, surface, request),
      );
    }

    return _deduplicate(candidates);
  }

  List<PlacementCandidate> _generateForSurface(
    vm.SpatialComponent subject,
    PlacementSurface surface,
    PlacementRequest request,
  ) {
    final usable = _usableBounds(surface, subject);
    final y = surface.height + subject.localBounds.height / 2;

    final points = <vm.Vector3>[];

    final preferred = request.preferredPosition;

    if (preferred != null) {
      // Add preferred position (clamped to usable bounds)
      points.add(_clamp(preferred, usable, y));

      // Add local grid around preferred position
      points.addAll(
        _localGridPoints(
          center: preferred,
          bounds: usable,
          y: y,
          spacing: grid.spacing,
          radius: 1.0,
        ),
      );
    }

    // Always add center
    points.add(vm.Vector3(usable.center.x, y, usable.center.z));

    // Add edge midpoints
    points.addAll(_edgePoints(usable, y));

    // Add corners
    points.addAll(_cornerPoints(usable, y));

    return points
        .map((point) => PlacementCandidate(
              position: point,
              surfaceId: surface.id,
              source: _pointSource(point, preferred, usable),
            ))
        .toList();
  }

  /// Calculate the usable bounds for placing an object on a surface.
  ///
  /// This shrinks the surface bounds by half the object's width and depth
  /// to ensure the object's center is placed such that the entire object
  /// fits on the surface without overhang.
  Bounds _usableBounds(
    PlacementSurface surface,
    vm.SpatialComponent subject,
  ) {
    final halfWidth = subject.localBounds.width / 2;
    final halfDepth = subject.localBounds.depth / 2;

    return Bounds(
      min: vm.Vector3(
        surface.bounds.min.x + halfWidth,
        surface.bounds.min.y,
        surface.bounds.min.z + halfDepth,
      ),
      max: vm.Vector3(
        surface.bounds.max.x - halfWidth,
        surface.bounds.max.y,
        surface.bounds.max.z - halfDepth,
      ),
    );
  }

  vm.Vector3 _clamp(vm.Vector3 point, Bounds bounds, double y) {
    return vm.Vector3(
      point.x.clamp(bounds.min.x, bounds.max.x),
      y,
      point.z.clamp(bounds.min.z, bounds.max.z),
    );
  }

  List<vm.Vector3> _localGridPoints({
    required vm.Vector3 center,
    required Bounds bounds,
    required double y,
    required double spacing,
    required double radius,
  }) {
    final points = <vm.Vector3>[];

    for (double x = center.x - radius; x <= center.x + radius; x += spacing) {
      for (double z = center.z - radius; z <= center.z + radius; z += spacing) {
        if (x < bounds.min.x ||
            x > bounds.max.x ||
            z < bounds.min.z ||
            z > bounds.max.z) {
          continue;
        }

        points.add(vm.Vector3(x, y, z));
      }
    }

    return points;
  }

  List<vm.Vector3> _edgePoints(Bounds bounds, double y) {
    final xMid = (bounds.min.x + bounds.max.x) / 2;
    final zMid = (bounds.min.z + bounds.max.z) / 2;

    return [
      vm.Vector3(bounds.min.x, y, zMid),
      vm.Vector3(bounds.max.x, y, zMid),
      vm.Vector3(xMid, y, bounds.min.z),
      vm.Vector3(xMid, y, bounds.max.z),
    ];
  }

  List<vm.Vector3> _cornerPoints(Bounds bounds, double y) {
    return [
      vm.Vector3(bounds.min.x, y, bounds.min.z),
      vm.Vector3(bounds.min.x, y, bounds.max.z),
      vm.Vector3(bounds.max.x, y, bounds.min.z),
      vm.Vector3(bounds.max.x, y, bounds.max.z),
    ];
  }

  CandidateSource _pointSource(
    vm.Vector3 point,
    vm.Vector3? preferred,
    Bounds bounds,
  ) {
    if (preferred != null && point.distanceTo(preferred) < 0.001) {
      return CandidateSource.preferred;
    }

    final center = bounds.center;
    if ((point.x - center.x).abs() < 0.001 &&
        (point.z - center.z).abs() < 0.001) {
      return CandidateSource.center;
    }

    // Check if it's a corner
    final isCornerX =
        (point.x - bounds.min.x).abs() < 0.001 ||
        (point.x - bounds.max.x).abs() < 0.001;
    final isCornerZ =
        (point.z - bounds.min.z).abs() < 0.001 ||
        (point.z - bounds.max.z).abs() < 0.001;

    if (isCornerX && isCornerZ) {
      return CandidateSource.corner;
    }

    // Check if it's an edge midpoint
    final xMid = (bounds.min.x + bounds.max.x) / 2;
    final zMid = (bounds.min.z + bounds.max.z) / 2;

    final isEdgeX = (point.x - bounds.min.x).abs() < 0.001 ||
        (point.x - bounds.max.x).abs() < 0.001;
    final isEdgeZ = (point.z - bounds.min.z).abs() < 0.001 ||
        (point.z - bounds.max.z).abs() < 0.001;
    final isMidX = (point.x - xMid).abs() < 0.001;
    final isMidZ = (point.z - zMid).abs() < 0.001;

    if ((isEdgeX && isMidZ) || (isEdgeZ && isMidX)) {
      return CandidateSource.edge;
    }

    return CandidateSource.grid;
  }

  List<PlacementCandidate> _deduplicate(
    List<PlacementCandidate> candidates,
  ) {
    final result = <PlacementCandidate>[];

    for (final candidate in candidates) {
      final exists = result.any(
        (existing) =>
            existing.position.distanceTo(candidate.position) < 0.001,
      );

      if (!exists) {
        result.add(candidate);
      }
    }

    return result;
  }
}
