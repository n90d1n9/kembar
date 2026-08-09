import 'package:flutter/material.dart';
import 'package:goodmap/goodmap.dart';

import '../../domain/value_objects/geo_point.dart';

/// Terminal-level geo overview — a distinct resolution of the digital
/// twin from the yard-level 3D scene (matching the wider platform design's
/// multi-resolution twin concept). Uses goodmap because this is genuinely
/// a lat/lng concern (where the terminal/vessels/gates are on a real map),
/// not a yard-slot one.
class TerminalGeoOverview extends StatelessWidget {
  final GeoPoint terminalLocation;
  final String terminalName;

  const TerminalGeoOverview({
    super.key,
    required this.terminalLocation,
    required this.terminalName,
  });

  @override
  Widget build(BuildContext context) {
    final center = LatLng(terminalLocation.latitude, terminalLocation.longitude);
    return GoodMap(
      initialCenter: center,
      initialZoom: 14,
      controls: const GoodControls(zoom: true, compass: true),
      onMapReady: (controller) {
        controller.addMarker(
          MarkerOptions(
            position: center,
            child: const Icon(Icons.anchor, color: Colors.white),
            onTap: () => controller.showPopup(
              center,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(terminalName),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
