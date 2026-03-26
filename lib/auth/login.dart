import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:redhr_mobile_app/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
  setState(() => loading = true);

  try {
    // 🔥 1. Firebase Login
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    // 🔥 2. Get token
    final token = await cred.user!.getIdToken();

    print("🔥 Firebase Token: $token");

    // 🔥 3. Call backend WITH TOKEN
    final user = await ApiService.getCurrentUser(token!);

    print("👤 Employee Data: $user");

    // 🔥 4. Store employee_id
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("employee_id", user['id']);

    // 🔥 5. Navigate (FIXED)
    Navigator.pushReplacementNamed(context, '/home');

  } catch (e) {
    print("❌ Login Error: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invalid email or password"),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 350,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(0.05),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// LOGO / TITLE
              const Text(
                "Employee Login",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              /// EMAIL
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// PASSWORD
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// LOGIN BUTTON
SizedBox(
  width: double.infinity,
  height: 50,
  child: ElevatedButton(
    onPressed: loading
        ? null
        : () {
            print("🔥 LOGIN BUTTON CLICKED");
            login();
          },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1F4E5F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: loading
        ? const CircularProgressIndicator(color: Colors.white)
        : const Text(
            "LOGIN",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
  ),
),

              const SizedBox(height: 10),

              /// INFO TEXT
              const Text(
                "Use credentials provided by HR",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}