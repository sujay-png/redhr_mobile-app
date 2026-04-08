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
  State<AttendanceCameraScreen> createState() =>
      _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState extends State<AttendanceCameraScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  Position? _currentPosition;
  String _address = "Fetching location...";

  // ── State flags ──────────────────────────────────────────────────────────────
  bool _isCapturing = false;
  bool _captured    = false; 
  String _liveTime  = "";
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _startClock();
    _initEverything();
  }

  void _startClock() {
    _liveTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _liveTime = DateFormat('hh:mm:ss a').format(DateTime.now());
        });
      }
    });
  }

  Future<void> _initEverything() async {
    // Run location + camera init in parallel
    await Future.wait([
      _determinePosition(),
      _initCamera(),
    ]);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.medium, // ✅ medium is faster than high to capture & encode
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _initFuture = _controller!.initialize();
      await _initFuture;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // ✅ Use last known position first (instant) then accurate position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = lastKnown;
          _address =
              "${lastKnown.latitude.toStringAsFixed(4)}, ${lastKnown.longitude.toStringAsFixed(4)}";
        });
      }

      // Get accurate position in background
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // ✅ medium > high for speed
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _address =
              "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) setState(() => _address = "Location unavailable");
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ── Capture ───────────────────────────────────────────────────────────────────
  Future<void> _handleCapture() async {
    if (_isCapturing || _controller == null) return;
    setState(() => _isCapturing = true);

    try {
      // 1. Take picture immediately
      final XFile image = await _controller!.takePicture();

      // 2. Get employee ID from cache
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt("employee_id");
      if (employeeId == null) throw Exception("Employee ID not found. Please log in again.");

      // 3. Use whatever position we have (last known is fine)
      final lat = _currentPosition?.latitude  ?? 0.0;
      final lng = _currentPosition?.longitude ?? 0.0;

      // ✅ SPEED FIX: Show success overlay immediately, upload in background
      setState(() {
        _captured    = true;
        _isCapturing = false;
      });

      // 4. Upload in background — don't await before popping
      _uploadAndPop(
        employeeId: employeeId,
        imagePath: image.path,
        lat: lat,
        lng: lng,
      );

    } catch (e) {
      debugPrint("Capture error: $e");
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Upload happens after we've already shown success + popped
  Future<void> _uploadAndPop({
  required int employeeId,
  required String imagePath,
  required double lat,
  required double lng,
}) async {
  try {
    final res = await ApiService.markAttendance(
      lat: lat,
      lng: lng,
      imagePath: imagePath,
    );
    debugPrint("✅ Attendance API: $res");
  } catch (e) {
    debugPrint("❌ Attendance upload failed: $e");
  }

  // ✅ Pop AFTER upload completes
  await Future.delayed(const Duration(milliseconds: 600));
  
  if (!mounted) return;
  if (context.canPop()) {
    context.pop(true);
  } else {
    context.go('/home');
  }
}

  // ── UI ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_controller != null)
            Positioned.fill(
              child: FutureBuilder(
                future: _initFuture,
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

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) context.pop(false);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom UI
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomUI(),
          ),

          // ✅ Success overlay — shown immediately after capture
          if (_captured) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text(
              "Attendance Marked!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Syncing in background...",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metaDetail("TIMESTAMP", _liveTime),
                  _metaDetail(
                    "ACCURACY",
                    _currentPosition != null
                        ? "${_currentPosition!.accuracy.toStringAsFixed(0)}m"
                        : "—",
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: _isCapturing || _captured ? null : _handleCapture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white38,
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
                            fontSize: 16,
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
        Text(label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            )),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            )),
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
}