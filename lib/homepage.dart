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

class _HomePageState extends State<HomePage> {
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  bool isLoading = true;
  String? userName;
  String? checkInTime;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  // Helper to format the IST timestamp for the UI
  String _formatTime(String? timestamp) {
    if (timestamp == null) return "--:--";
    try {
      DateTime dt = DateTime.parse(timestamp);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return "--:--";
    }
  }

  // Load user data and attendance status on startup
Future<void> _initialLoad() async {
    try {
      // 1. Get the Firebase ID Token
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // 2. Fetch Profile for Name and ID
      final profile = await ApiService.getMe();
      
      // 3. Fetch Attendance Status (Passing the required token)
      final status = await ApiService.getAttendanceStatus(token);

      if (mounted) {
        setState(() {
          userName = profile['full_name'];
          isCheckedIn = status['isCheckedIn'] ?? false;
          isCheckedOut = status['isCheckedOut'] ?? false;
          checkInTime = status['checkInTime'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Load Error: $e");
    }
  }

  // Handle Button Click (Check-In or Check-Out)
  Future<void> _handleAttendance() async {
    try {
      // --- FLOW A: CHECK-IN ---
      if (!isCheckedIn) {
        // Navigate to your dedicated camera screen
        // We use .push so we can wait for the result to refresh the UI
        final result = await context.push<bool>('/camera');

        if (result == true) {
          _initialLoad(); // Refresh home state if check-in was successful
        }
        return;
      }

      // --- FLOW B: CHECK-OUT ---
      setState(() => isLoading = true);

      // Get profile for ID
      final profile = await ApiService.getMe();

      // Call API directly without opening camera
      await ApiService.markAttendance(
        employeeId: profile['id'],
        lat: 0.0,
        lng: 0.0,
        imagePath: "", // Passes empty string to skip Multipart file check
      );

      // Refresh Status immediately
      await _initialLoad();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Checked Out Successfully"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF005B69);
    const orangeStatus = Color(0xFFE67E22);
    const greyStatus = Color(0xFF7F8C8D);
    const backgroundColor = Color(0xFFF8F9FA);

    // Dynamic UI State logic
    String statusTitle = "Not Checked In";
    String buttonText = "Check In Now";
    IconData buttonIcon = Icons.login_rounded;
    Color cardColor = primaryTeal;

    if (isCheckedIn && !isCheckedOut) {
      statusTitle = "Currently Working";
      buttonText = "Check Out Now";
      buttonIcon = Icons.logout_rounded;
      cardColor = orangeStatus;
    } else if (isCheckedOut) {
      statusTitle = "Work Completed";
      buttonText = "Attendance Finished";
      buttonIcon = Icons.check_circle_outline;
      cardColor = greyStatus;
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
                      // --- Header ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: primaryTeal.withOpacity(0.1),
                                child: Text(userName != null ? userName![0].toUpperCase() : "U"),
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
                                    userName != null ? 'Hi, $userName' : 'Welcome back',
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
                          const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A434E), size: 28),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // --- Dynamic Attendance Card ---
                      Container(
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
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Today's Status",
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
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
                            
                            // Show start time if working
                            if (isCheckedIn && !isCheckedOut && checkInTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Started at ${_formatTime(checkInTime)}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isCheckedOut ? null : _handleAttendance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: cardColor,
                                disabledBackgroundColor: Colors.white54,
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(buttonIcon),
                                  const SizedBox(width: 10),
                                  Text(
                                    buttonText,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Quick Access Section ---
                      const Text('Quick Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      _buildMenuCard(
                        icon: Icons.payments_outlined,
                        iconBg: const Color(0xFFE3F2FD),
                        title: 'Salary Slips',
                        subtitle: 'View and download your monthly pay stubs.',
                      ),
                      _buildMenuCard(
                        icon: Icons.description_rounded,
                        iconBg: const Color(0xFFFFF3E0),
                        title: 'Reports Management',
                        subtitle: 'Track and edit your daily task submissions.',
                      ),
                      _buildMenuCard(
                        icon: Icons.history_rounded,
                        iconBg: const Color(0xFFE0F2F1),
                        title: 'Attendance Tracking',
                        subtitle: 'View check-in history and selfie logs.',
                      ),

                      const SizedBox(height: 10),

                      // --- Quick Tip Section ---
                      _buildTipSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTipSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: const Icon(Icons.lightbulb_outline, color: Colors.blueGrey),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Tip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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

  Widget _buildMenuCard({required IconData icon, required Color iconBg, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF263238)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    );
  }
}