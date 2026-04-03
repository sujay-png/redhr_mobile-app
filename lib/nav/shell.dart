import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:redhr_mobile_app/auth/login.dart';
import 'package:redhr_mobile_app/homepage.dart';
import 'package:redhr_mobile_app/attendance_camera_screen.dart';
import 'package:redhr_mobile_app/reports.dart';
import 'nav.dart';

// ── Router ────────────────────────────────────────────────────────────────────
// All GoRouter configuration lives here. main.dart just consumes `appRouter`.

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  navigatorKey: _rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const EmployeeLoginScreen(),
    ),

    // Camera is pushed above the shell so it covers the bottom nav bar.
    GoRoute(
      path: '/camera',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AttendanceCameraScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),

        // Attendance tab has no real screen — tapping it opens /camera via AppShell.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/attendance',
              builder: (context, state) => const SizedBox.shrink(),
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
              builder: (context, state) => const Scaffold(
                body: Center(child: Text("Profile")),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

// ── Shell ─────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  /// All tab-tap navigation logic lives here.
  Future<void> _onTap(BuildContext context, int index) async {
    // Tapping ATTENDANCE (index 1) pushes the camera directly.
    // On return we always land on Home (index 0).
    if (index == 1) {
      final result = await context.push<bool>('/camera');
      if (context.mounted) {
        navigationShell.goBranch(0, initialLocation: false);
        // HomePage observes AppLifecycleState and will reload on resume,
        // but we also trigger it here via the result flag if needed.
      }
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}