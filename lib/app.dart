import 'package:flutter/material.dart';

import 'presentation/screens/terminal_digital_twin_screen.dart';

class TerminalDigitalTwinApp extends StatelessWidget {
  const TerminalDigitalTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Digital Twin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2980D4),
        brightness: Brightness.dark,
      ),
      home: const TerminalDigitalTwinScreen(),
    );
  }
}
