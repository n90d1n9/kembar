import 'package:flutter/material.dart';

import '../../domain/entities/container_status.dart';

/// UI-only color mapping for container status, mirroring (not sharing —
/// the render layer intentionally doesn't depend on Flutter) the
/// Material3D base colors used in Lite3dSceneRenderAdapter, so the 3D
/// scene and the 2D legend/list agree visually.
const Map<ContainerStatus, Color> twinStatusColors = {
  ContainerStatus.laden: Color(0xFF2980D4),
  ContainerStatus.empty: Color(0xFF8C8C8C),
  ContainerStatus.onHold: Color(0xFFE5A61A),
  ContainerStatus.reservedForLoad: Color(0xFF4DB359),
  ContainerStatus.damaged: Color(0xFFCC2626),
};

String twinStatusLabel(ContainerStatus status) {
  switch (status) {
    case ContainerStatus.laden:
      return 'Laden';
    case ContainerStatus.empty:
      return 'Empty';
    case ContainerStatus.onHold:
      return 'On hold';
    case ContainerStatus.reservedForLoad:
      return 'Reserved for load';
    case ContainerStatus.damaged:
      return 'Damaged';
  }
}
