import 'package:flutter/material.dart';

import '../../domain/value_objects/geo_point.dart';
import '../widgets/terminal_geo_overview.dart';
import '../widgets/yard_block_twin_view.dart';

class TerminalDigitalTwinScreen extends StatefulWidget {
  const TerminalDigitalTwinScreen({super.key});

  @override
  State<TerminalDigitalTwinScreen> createState() => _TerminalDigitalTwinScreenState();
}

class _TerminalDigitalTwinScreenState extends State<TerminalDigitalTwinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal Digital Twin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Yard 3D Twin', icon: Icon(Icons.view_in_ar_outlined)),
            Tab(text: 'Geo Overview', icon: Icon(Icons.public)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: YardBlockTwinView(blockId: 'A'),
          ),
          // Demo coordinates — replace with the real terminal's location.
          const TerminalGeoOverview(
            terminalLocation: GeoPoint(latitude: 51.9496, longitude: 4.1453),
            terminalName: 'Demo Terminal (replace with real coordinates)',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
