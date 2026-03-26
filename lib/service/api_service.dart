import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "https://api.hr.rd-crm.in";

  /// ============================
  /// 🔐 GET FIREBASE TOKEN
  /// ============================
  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final token = await user.getIdToken();

    if (token == null) {
      throw Exception("Token not found");
    }

    return token;
  }

  /// ============================
  /// 👤 GET CURRENT USER
  /// ============================
static Future<Map<String, dynamic>> getCurrentUser(String token) async {
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
  required String imagePath,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception("User not logged in");
  }

  final token = await user.getIdToken();

  final request = http.MultipartRequest(
    'POST',
    Uri.parse("$baseUrl/api/Attendance/mark"),
  );

  // 🔥 ADD TOKEN (THIS WAS MISSING)
  request.headers['Authorization'] = 'Bearer $token';

  request.fields['employee_id'] = employeeId.toString();
  request.fields['lat'] = lat.toString();
  request.fields['lng'] = lng.toString();

  request.files.add(
    await http.MultipartFile.fromPath('image', imagePath),
  );

  final response = await request.send();
  final resBody = await response.stream.bytesToString();

  print("🔥 STATUS: ${response.statusCode}");
  print("🔥 BODY: $resBody");

  if (response.statusCode == 200) {
    return jsonDecode(resBody);
  } else {
    throw Exception("API Error: $resBody");
  }
}
}