import 'package:flutter/material.dart';
import 'package:redhr_mobile_app/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


Future<void> handleLogin(BuildContext context) async {
  try {
    final user = await ApiService.getCurrentUser();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("employee_id", user['id']);

    print("✅ Employee ID stored: ${user['id']}");

    Navigator.pushReplacementNamed(context, '/home');

  } catch (e) {
    print("❌ Login Error: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Login failed"),
        backgroundColor: Colors.red,
      ),
    );
  }
}