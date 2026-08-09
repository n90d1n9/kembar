import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/mappers/container_spatial_mapper.dart';
import '../../application/mappers/container_twin_mapper.dart';
import '../../application/repositories/container_twin_repository_adapter.dart';
import '../../application/repositories/twin_repository.dart';
import 'repository_providers.dart';

/// Provider for ContainerTwinMapper.
/// 
/// Maps domain-specific ContainerTwin to generic TwinEntity.
final containerTwinMapperProvider = Provider<ContainerTwinMapper>((ref) {
  final spatialMapper = ref.watch(containerSpatialMapperProvider);
  return ContainerTwinMapper(spatialMapper: spatialMapper);
});

/// Provider for ContainerSpatialMapper.
/// 
/// Maps container slots to 3D positions.
final containerSpatialMapperProvider = Provider<ContainerSpatialMapper>((ref) {
  // Default implementation - can be overridden for different terminal layouts
  return const ContainerSpatialMapper();
});

/// Provider for TwinRepository adapted from ContainerRepository.
/// 
/// This bridges the container-terminal domain to the platform-agnostic Twin Kernel.
final twinRepositoryProvider = Provider<TwinRepository>((ref) {
  final containerRepository = ref.watch(containerRepositoryProvider);
  final mapper = ref.watch(containerTwinMapperProvider);
  
  return ContainerTwinRepositoryAdapter(
    source: containerRepository,
    mapper: mapper,
  );
});
