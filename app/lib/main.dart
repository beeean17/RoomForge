import 'package:flutter/material.dart';

void main() {
  runApp(const RoomForgeApp());
}

class RoomForgeApp extends StatelessWidget {
  const RoomForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomForge',
      home: Scaffold(
        appBar: AppBar(title: const Text('RoomForge')),
        body: const Center(child: Text('Project foundation ready')),
      ),
    );
  }
}
