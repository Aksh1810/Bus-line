import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const BusLineApp());
}

class BusLineApp extends StatelessWidget {
  const BusLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}