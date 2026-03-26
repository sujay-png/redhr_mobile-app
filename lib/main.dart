import 'package:flutter/material.dart';
import 'attendance_camera_screen.dart'; // 👈 import your screen

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AttendanceCameraScreen(), 
    );
  }
}