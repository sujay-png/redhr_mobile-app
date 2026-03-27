import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:redhr_mobile_app/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceCameraScreen extends StatefulWidget {
  const AttendanceCameraScreen({super.key});

  @override
  State<AttendanceCameraScreen> createState() => _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends State<AttendanceCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  Position? _currentPosition;
  String _address = "Fetching location...";
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  Future<void> _initEverything() async {
    await _determinePosition();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
      _address =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FULL SCREEN VIEWPORT
          if (_controller != null)
            Positioned.fill(
              child: FutureBuilder(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller!);
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),

          // OVERLAY GRADIENT
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // TOP INFO
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _blurCircle(Icons.location_on, Colors.redAccent),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "CURRENT LOCATION",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _address,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM SECTION
          Align(alignment: Alignment.bottomCenter, child: _buildBottomUI()),
        ],
      ),
    );
  }

  Widget _buildBottomUI() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metaDetail(
                    "TIMESTAMP",
                    DateFormat('hh:mm a').format(DateTime.now()),
                  ),
                  _metaDetail(
                    "ACCURACY",
                    "${_currentPosition?.accuracy.toStringAsFixed(1) ?? '0'}m",
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: _isCapturing ? null : _handleCapture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _isCapturing
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "MARK ATTENDANCE",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _handleCapture() async {
    setState(() => _isCapturing = true);

    try {
      // ✅ Ensure camera ready
      await _initializeControllerFuture;

      // 📍 Get precise location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 📸 Capture image
      final XFile image = await _controller!.takePicture();

      // 🔥 Get employee_id from local storage
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt("employee_id");

      if (employeeId == null) {
        throw Exception("Employee ID not found. Please login again.");
      }

      // 🔍 Debug logs
      print("--- ATTENDANCE LOG ---");
      print("Employee ID: $employeeId");
      print("Image Path: ${image.path}");
      print("Lat: ${position.latitude}");
      print("Lng: ${position.longitude}");

      // 🚀 Call API
      final res = await ApiService.markAttendance(
        employeeId: employeeId,
        lat: position.latitude,
        lng: position.longitude,
        imagePath: image.path,
      );

      print("✅ API RESPONSE: $res");

      if (!mounted) return;

      // ✅ SUCCESS UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "Attendance Marked"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );


      context.go('/home');
    } catch (e) {
      print("❌ ERROR: $e");

      if (!mounted) return;

      // ❌ ERROR UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to mark attendance"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}
