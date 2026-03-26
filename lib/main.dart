import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:redhr_mobile_app/auth/login.dart';
import 'attendance_camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 VERY IMPORTANT → Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 🔥 Routes (clean navigation)
      routes: {
        '/login': (context) => const EmployeeLoginScreen(),
        '/home': (context) => const AttendanceCameraScreen(),
      },

      // 🔥 Start with login
      home: const EmployeeLoginScreen(),
    );
  }
}