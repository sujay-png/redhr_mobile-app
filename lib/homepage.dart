import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:redhr_mobile_app/service/api_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  bool isLoading = true;
  bool isActionLoading = false;
  bool _isResuming = false; // guard against double-load on resume + check-in

  String? userName;
  String? checkInTime;
  String? checkOutTime; // ← store actual check-out time from server

  // Live "hours worked" timer
  Timer? _workedTimer;
  Duration _workedDuration = Duration.zero;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workedTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only reload on resume, and skip if we're already mid-action
    if (state == AppLifecycleState.resumed && !_isResuming) {
      _initialLoad();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String? timestamp) {
    if (timestamp == null) return "--:--";
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(timestamp));
    } catch (_) {
      return "--:--";
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  void _startWorkedTimer() {
    _workedTimer?.cancel();
    if (checkInTime == null) return;

    final checkIn = DateTime.tryParse(checkInTime!);
    if (checkIn == null) return;

    // Sync to actual elapsed time before starting the ticker
    _workedDuration = DateTime.now().difference(checkIn);

    _workedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _workedDuration += const Duration(seconds: 1));
      }
    });
  }

  void _stopWorkedTimer() {
    _workedTimer?.cancel();
    _workedTimer = null;
  }

  /// Compute final duration from real server timestamps (check-in → check-out).
  void _setFinalDuration() {
    if (checkInTime == null) return;
    final checkIn = DateTime.tryParse(checkInTime!);
    if (checkIn == null) return;

    if (checkOutTime != null) {
      // Use actual check-out time from server
      final checkOut = DateTime.tryParse(checkOutTime!);
      if (checkOut != null) {
        _workedDuration = checkOut.difference(checkIn);
        return;
      }
    }

    // Fallback: use current time (shouldn't normally reach here)
    _workedDuration = DateTime.now().difference(checkIn);
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _initialLoad() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getAttendanceStatus(token),
      ]);

      final profile = results[0];
      final status = results[1];

      if (mounted) {
        setState(() {
          userName     = profile['full_name'];
          isCheckedIn  = status['isCheckedIn']  ?? false;
          isCheckedOut = status['isCheckedOut'] ?? false;
          checkInTime  = status['checkInTime'];
          checkOutTime = status['checkOutTime']; // ← read from API response
          isLoading    = false;
        });

        if (isCheckedIn && !isCheckedOut) {
          _startWorkedTimer();
        } else {
          _stopWorkedTimer();
          if (isCheckedIn && isCheckedOut) {
            _setFinalDuration(); // uses real server timestamps
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Load Error: $e");
    }
  }

  // ── Attendance handlers ───────────────────────────────────────────────────

  /// CHECK-IN: push camera page, update state on return.
  Future<void> _handleCheckIn() async {
    _isResuming = true; // prevent didChangeAppLifecycleState from firing a duplicate load

    final result = await context.push<bool>('/camera');

    _isResuming = false;

    if (result == true && mounted) {
      // Optimistic UI update while we wait for server confirmation
      setState(() {
        isCheckedIn  = true;
        isCheckedOut = false;
        checkInTime  = DateTime.now().toIso8601String();
        isActionLoading = true;
      });

      _startWorkedTimer();

      // Give the server a moment to process, then sync real data
      await Future.delayed(const Duration(milliseconds: 1500));
      await _initialLoad();

      if (mounted) setState(() => isActionLoading = false);
    }
  }

  /// CHECK-OUT: call dedicated check-out API, update state.
  Future<void> _handleCheckOut() async {
    setState(() => isActionLoading = true);

    try {
      // Use a dedicated check-out endpoint — not markAttendance with dummy data
      await ApiService.checkOut(); 

      _stopWorkedTimer();

      // Sync from server to get real checkOutTime
      await _initialLoad();

      if (mounted) {
        setState(() => isActionLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Checked Out Successfully"),
            backgroundColor: Color(0xFFE67E22),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isActionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check-out failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primaryTeal   = Color(0xFF005B69);
    const orangeStatus  = Color(0xFFE67E22);
    const greyStatus    = Color(0xFF7F8C8D);
    const backgroundColor = Color(0xFFF8F9FA);

    String statusTitle = "Not Checked In";
    String buttonText  = "Check In Now";
    IconData buttonIcon = Icons.login_rounded;
    Color cardColor    = primaryTeal;

    if (isCheckedIn && !isCheckedOut) {
      statusTitle = "Currently Working";
      buttonText  = "Check Out Now";
      buttonIcon  = Icons.logout_rounded;
      cardColor   = orangeStatus;
    } else if (isCheckedOut) {
      statusTitle = "Work Completed";
      buttonText  = "Attendance Finished";
      buttonIcon  = Icons.check_circle_outline;
      cardColor   = greyStatus;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _initialLoad,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: primaryTeal.withOpacity(0.1),
                                child: Text(
                                  userName != null
                                      ? userName![0].toUpperCase()
                                      : "U",
                                  style: const TextStyle(
                                    color: primaryTeal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KINETIC LEDGER',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    userName != null
                                        ? 'Hi, $userName'
                                        : 'Welcome back',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A434E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1A434E),
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // ── Attendance card ────────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Today's Status",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              statusTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Check-in time row
                            if (isCheckedIn && checkInTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Started at ${_formatTime(checkInTime)}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                            // Check-out time row (only shown after checkout)
                            if (isCheckedOut && checkOutTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Ended at ${_formatTime(checkOutTime)}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                            // Live / final hours-worked counter
                            if (isCheckedIn)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        isCheckedOut
                                            ? "Total time worked"
                                            : "Time worked",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(_workedDuration),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Action button
                            ElevatedButton(
                              onPressed: (isCheckedOut || isActionLoading)
                                  ? null
                                  : isCheckedIn
                                      ? _handleCheckOut
                                      : _handleCheckIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: cardColor,
                                disabledBackgroundColor: Colors.white38,
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isActionLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cardColor,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(buttonIcon),
                                        const SizedBox(width: 10),
                                        Text(
                                          buttonText,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ── Quick Access ───────────────────────────────────────
                      const Text(
                        'Quick Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildMenuCard(
                        icon: Icons.payments_outlined,
                        iconBg: const Color(0xFFE3F2FD),
                        title: 'Salary Slips',
                        subtitle: 'View and download your monthly pay stubs.',
                        onTap: () {},
                      ),
                      _buildMenuCard(
                        icon: Icons.description_rounded,
                        iconBg: const Color(0xFFFFF3E0),
                        title: 'Reports Management',
                        subtitle: 'Track and edit your daily task submissions.',
                        onTap: () => context.go('/reports'),
                      ),
                      _buildMenuCard(
                        icon: Icons.history_rounded,
                        iconBg: const Color(0xFFE0F2F1),
                        title: 'Attendance History',
                        subtitle: 'View check-in history and selfie logs.',
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _buildTipSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildTipSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blueGrey),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tip',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Checking in before 9:05 AM helps maintain your perfect punctuality record!',
                  style: TextStyle(color: Colors.blueGrey, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF263238)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}