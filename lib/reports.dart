import 'package:flutter/material.dart';
import 'package:redhr_mobile_app/service/api_service.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => DailyReportScreenState();
}

class DailyReportScreenState extends State<DailyReportScreen> {
  final Color primaryTeal = const Color(0xFF0C5D6B);
  final TextEditingController focusController = TextEditingController();
  final TextEditingController challengeController = TextEditingController();
  bool isSubmitting = false;

  Future<void> submitReport() async {
    print("--------------------------------");
    print("🚀 [SUBMIT] Report Submission Started");

    final String tasks = focusController.text.trim();
    final String challenges = challengeController.text.trim();

    // Validation Check
    if (tasks.isEmpty) {
      print("⚠️ [VALIDATION] Failed: 'Today's Focus' is empty.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter today's focus")),
      );
      return;
    }

    print("📦 [DATA] Tasks: $tasks");
    print(
      "📦 [DATA] Challenges: ${challenges.isEmpty ? 'None provided' : challenges}",
    );

    setState(() => isSubmitting = true);

    try {
      print("📡 [API] Calling ApiService.submitDailyReport...");

      final success = await ApiService.submitDailyReport(
        tasks: tasks,
        challenges: challenges,
      );

      if (success) {
        print("✅ [SUCCESS] Report stored successfully in MariaDB.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully!")),
        );
        focusController.clear();
        challengeController.clear();
      } else {
        print("❌ [FAILURE] Backend returned a non-201 status code.");
        throw Exception("Failed to submit report");
      }
    } catch (e) {
      print("🚨 [ERROR] Exception during submission: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      print("🏁 [FINISH] Submission process completed.");
      print("--------------------------------");
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Daily Submission",
          style: TextStyle(
            color: Color(0xFF0C5D6B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SUBMISSION PORTAL",
              style: TextStyle(
                color: Colors.grey,
                letterSpacing: 1.2,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Daily Report",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0C5D6B),
              ),
            ),
            const SizedBox(height: 30),

            reportFieldTitle("Today's Focus"),
            reportTextArea(
              "What were your primary objectives today?",
              focusController,
            ),

            const SizedBox(height: 20),

            reportFieldTitle("Challenges Encountered"),
            reportTextArea(
              "Describe any blockers or difficulties...",
              challengeController,
            ),

            const SizedBox(height: 30),

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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isSubmitting ? null : submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Submit Report",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget reportTextArea(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
