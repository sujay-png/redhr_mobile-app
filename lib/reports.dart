import 'package:flutter/material.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => DailyReportScreenState();
}

class DailyReportScreenState extends State<DailyReportScreen> {
  final Color primaryTeal = const Color(0xFF0C5D6B);
  final TextEditingController focusController = TextEditingController();
  final TextEditingController challengeController = TextEditingController();
  String? selectedDuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.person_outline, color: Colors.black),
        title: const Text("Welcome back", style: TextStyle(color: Color(0xFF0C5D6B), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.black))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SUBMISSION PORTAL", style: TextStyle(color: Colors.grey, letterSpacing: 1.2, fontSize: 12, fontWeight: FontWeight.bold)),
            const Text("Daily Report", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0C5D6B))),
            Text("Wednesday, October 25, 2023", style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 30),

            reportFieldTitle("Today's Focus"),
            reportTextArea("What were your primary objectives today?", focusController),
            
            const SizedBox(height: 20),

            reportFieldTitle("Challenges Encountered"),
            reportTextArea("Describe any blockers or difficulties...", challengeController),

          
            const SizedBox(height: 30),
            
            // Pro-tip Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFF0C5D6B)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Pro-tip: Detailed reports help the leadership team identify recurring bottlenecks.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF0C5D6B)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                // Logic to submit to Supabase/MariaDB
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Submit Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 10),
                  Icon(Icons.send, size: 18, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget reportFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget reportTextArea(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}