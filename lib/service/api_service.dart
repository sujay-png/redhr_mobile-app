import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "https://api.hr.rd-crm.in";

  /// ============================
  /// 🔐 GET FIREBASE TOKEN (Private Helper)
  /// ============================
  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    
    final token = await user.getIdToken();
    if (token == null) throw Exception("Token not found");
    
    return token;
  }

  /// ============================
  /// 👤 GET CURRENT USER (Internal Profile)
  /// ============================
  static Future<Map<String, dynamic>> getMe() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/api/me"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch user: ${res.body}");
    }

    return jsonDecode(res.body);
  }

  /// ============================
  /// 📸 MARK ATTENDANCE
  /// ============================
static Future<Map<String, dynamic>> markAttendance({
  required int employeeId,
  required double lat,
  required double lng,
  String imagePath = "", // Make this optional
}) async {
  final token = await _getToken();

  final request = http.MultipartRequest(
    'POST',
    Uri.parse("$baseUrl/api/Attendance/mark"),
  );

  request.headers['Authorization'] = 'Bearer $token';
  request.fields['employee_id'] = employeeId.toString();
  request.fields['lat'] = lat.toString();
  request.fields['lng'] = lng.toString();

  if (imagePath.isNotEmpty) {
    request.files.add(
      await http.MultipartFile.fromPath('image', imagePath),
    );
  }

  final response = await request.send();
  final resBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    return jsonDecode(resBody);
  } else {
    throw Exception("API Error: $resBody");
  }
}

  /// ============================
  /// ⏳ FETCH ATTENDANCE STATUS
  /// ============================
  static Future<Map<String, dynamic>> getAttendanceStatus(String token) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/api/Attendance/status"),
      headers: {"Authorization": "Bearer $token"},
    );
    
    if (res.statusCode != 200) {
      throw Exception("Failed to fetch status: ${res.body}");
    }
    return jsonDecode(res.body);
  }


  /// ============================
  /// 📝 SUBMIT DAILY REPORT
  /// ============================
  static Future<bool> submitDailyReport({
  required String tasks,
  required String challenges,
}) async {
  try {
    final token = await _getToken();
    final url = Uri.parse("$baseUrl/api/daily-reports");

    print("🌐 [HTTP] POST to: $url");
    
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "todays_tasks": tasks,
        "challenges": challenges,
      }),
    );

    print("📬 [HTTP] Status Code: ${response.statusCode}");
    print("📄 [HTTP] Response Body: ${response.body}");

    return response.statusCode == 201;
  } catch (e) {
    print("🚨 [HTTP] Request failed: $e");
    return false;
  }
}
}