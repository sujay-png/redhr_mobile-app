import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'package:redhr_mobile_app/auth/login.dart';
import 'package:redhr_mobile_app/homepage.dart';
import 'package:redhr_mobile_app/nav/shell.dart';
import 'package:redhr_mobile_app/attendance_camera_screen.dart';
import 'package:redhr_mobile_app/reports.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/login',
    navigatorKey: _rootNavigatorKey,
    routes: [
      // 1. LOGIN SCREEN (No Bottom Nav)
      GoRoute(
        path: '/login',
        builder: (context, state) => const EmployeeLoginScreen(),
      ),

      // 2. ATTENDANCE CAMERA (No Bottom Nav - Root level)
      GoRoute(
        path: '/attendance-camera',
        parentNavigatorKey: _rootNavigatorKey, // Ensures it covers the whole screen
        builder: (context, state) => const AttendanceCameraScreen(),
      ),
      
      // 3. MAIN APP SHELL (With Bottom Nav)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/attendance',
                // This redirect triggers when the user taps the Attendance Tab
                redirect: (context, state) => '/attendance-camera',
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const DailyReportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const Scaffold(body: Center(child: Text("Profile"))),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}