import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "https://api.hr.rd-crm.in";

  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    final token = await user.getIdToken();
    if (token == null) throw Exception("Token not found");
    return token;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/api/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) {
      throw Exception("Failed to fetch user: ${res.body}");
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> markAttendance({
    required double lat,
    required double lng,
    String imagePath = "",
  }) async {
    final token = await _getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/api/Attendance/mark"),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // ✅ FIXED: match backend field names exactly
    request.fields['latitude'] = lat.toString();
    request.fields['longitude'] = lng.toString();

    if (imagePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );
    }

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    print("📡 ATTENDANCE STATUS: ${response.statusCode}");
    print("📦 ATTENDANCE RESPONSE: $resBody");

    if (response.statusCode == 200) {
      return jsonDecode(resBody);
    } else {
      throw Exception("API Error: $resBody");
    }
  }

  // ✅ FIXED: removed unused String token parameter
  static Future<Map<String, dynamic>> getAttendanceStatus() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/api/attendance/status"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to fetch status: ${res.body}");
    }

    final body = jsonDecode(res.body);
    final status = body['status'] as String? ?? 'not_marked';

    return {
      'isCheckedIn':  status == 'checked_in' || status == 'completed',
      'isCheckedOut': status == 'completed',
      'checkInTime':  body['checkInTime'],
      'checkOutTime': body['checkOutTime'],
    };
  }

  static Future<void> checkOut() async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse("$baseUrl/api/attendance/checkout"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    if (res.statusCode != 200) {
      throw Exception("Check-out failed: ${res.body}");
    }
  }

  static Future<bool> submitDailyReport({
    required String tasks,
    required String challenges,
  }) async {
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse("$baseUrl/api/daily-reports"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "todays_tasks": tasks,
          "challenges": challenges,
        }),
      );
      print("📬 Report Status: ${res.statusCode}");
      print("📄 Report Body: ${res.body}");
      return res.statusCode == 201;
    } catch (e) {
      print("🚨 Report failed: $e");
      return false;
    }
  }
}