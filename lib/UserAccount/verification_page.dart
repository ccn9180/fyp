import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../User/main_screen.dart';
import 'user_details_page.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final bool isGoogle;

  const VerificationPage({
    super.key,
    required this.email,
    required this.password,
    this.isGoogle = false,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  FaceDetector? _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  // Liveness Detection States
  String _currentInstruction = 'Ready to begin?';
  bool _scanningActive = false;
  bool _blinkDetected = false;
  bool _turnLeftDetected = false;
  bool _turnRightDetected = false;
  bool _isVerified = false;
  double _currentEulerY = 0; // Track head rotation in real-time
  double _currentEulerX = 0;
  String _hintText = "Look at the camera";
  Face? _detectedFace; // Store the face for overlay drawing
  bool _showSkipButton = false; // Emergency bypass
  
  // Adaptive Rotation for Hardware Compatibility
  final List<InputImageRotation> _rotations = [
    InputImageRotation.rotation0deg,
    InputImageRotation.rotation90deg,
    InputImageRotation.rotation180deg,
    InputImageRotation.rotation270deg,
  ];
  int _rotationIndex = 1; // Start with 90deg (most common for Android front)
  bool _rotationLocked = false;
  DateTime? _lastRotationTry;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    
    _initializeCamera();
    _initializeFaceDetector();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // For blinking
        enableLandmarks: true,
        enableTracking: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraDescription = frontCamera;
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium, // Better clarity for detection
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _cameraController!.startImageStream(_processCameraImage);
        
        // Show skip button after 5 seconds of failing to detect
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isVerified) {
            setState(() => _showSkipButton = true);
          }
        });
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraDescription == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    
    // For Android, ML Kit expects YUV420. For iOS, BGRA8888.
    if (Platform.isAndroid && format != InputImageFormat.yuv420) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // Use adaptive rotation
    final rotation = _rotations[_rotationIndex];

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  DateTime? _lastProcessed;

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isVerified || !_scanningActive || !mounted) return;
    
    // Throttling: Only process one frame every 500ms to avoid clogging the native bridge
    final now = DateTime.now();
    if (_lastProcessed != null && now.difference(_lastProcessed!).inMilliseconds < 500) {
      return;
    }
    _lastProcessed = now;
    
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _detectedFace = faces.isNotEmpty ? faces.first : null;
        });
      }

      if (faces.isNotEmpty) {
        _rotationLocked = true; // Found a face! Lock this rotation.
        if (mounted) _analyzeFace(faces.first);
      } else if (!_rotationLocked && _scanningActive) {
        // Try next rotation if we haven't found a face after a few attempts
        final now = DateTime.now();
        if (_lastRotationTry == null || now.difference(_lastRotationTry!).inSeconds >= 2) {
          _lastRotationTry = now;
          setState(() {
            _rotationIndex = (_rotationIndex + 1) % _rotations.length;
            _hintText = "Calibrating sensor... (${_rotationIndex + 1}/4)";
          });
        }
      }
    } catch (e) {
      debugPrint("ML Processing Error: $e");
      // Stop scanning if there's a serious native error to prevent battery drain
      if (e.toString().contains('IllegalArgumentException')) {
         _scanningActive = false;
         _currentInstruction = "Scanning error. Let's try again.";
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _analyzeFace(Face face) {
    if (_isVerified) return;

    setState(() {
      _currentEulerY = face.headEulerAngleY ?? 0;
      _currentEulerX = face.headEulerAngleX ?? 0;
    });

    if (!_blinkDetected) {
      if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
        if (face.leftEyeOpenProbability! < 0.2 && face.rightEyeOpenProbability! < 0.2) {
          setState(() {
            _blinkDetected = true;
            _currentInstruction = 'Turn your head left';
            _hintText = "Rotate until the bar is full";
          });
          HapticFeedback.mediumImpact();
        } else {
          setState(() => _hintText = "Blink your eyes now");
        }
      }
    } else if (!_turnLeftDetected) {
      final double progress = (_currentEulerY / 20).clamp(0.0, 1.0);
      if (_currentEulerY > 20) {
        setState(() {
          _turnLeftDetected = true;
          _currentInstruction = 'Turn your head right';
          _hintText = "Now rotate to the other side";
        });
        HapticFeedback.mediumImpact();
      } else if (_currentEulerY > 5) {
        setState(() => _hintText = "Keep turning left...");
      }
    } else if (!_turnRightDetected) {
      if (_currentEulerY < -20) {
        setState(() {
          _turnRightDetected = true;
          _currentInstruction = 'Verification Successful!';
          _isVerified = true;
          _hintText = "You're all set!";
        });
        HapticFeedback.vibrate();
        Future.delayed(const Duration(milliseconds: 1500), () => _startScan());
      } else if (_currentEulerY < -5) {
        setState(() => _hintText = "Great! Keep turning right...");
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _controller.dispose();
    super.dispose();
  }

  void _startLivenessTest() {
    setState(() {
      _scanningActive = true;
      _isVerified = false; // Reset
      _blinkDetected = false;
      _turnLeftDetected = false;
      _turnRightDetected = false;
      _rotationLocked = false;
      _currentInstruction = 'Blink your eyes';
      _hintText = "Hold phone at eye level";
    });
  }

  Future<void> _startScan() async {
    if (!_isVerified) {
      _startLivenessTest();
      return;
    }

    // 1. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // For both Google and Manual users (who already verified email), 
      // we now just simulate the premium "face scan" experience.
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        
        // Go straight to UserDetailsPage after the "scan"
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserDetailsPage(
              email: widget.email,
              password: widget.password,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7), // Unified sage background
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          // Consistent Progress Bar (Step 2 Active) with Back Button
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E2742)),
                                  onPressed: () async {
                                    try {
                                      // If they cancel mid-registration flow, delete the Auth entry 
                                      // so it's not "saved" without a profile.
                                      await FirebaseAuth.instance.currentUser?.delete();
                                    } catch (e) {
                                      // Fallback to sign out if delete fails (e.g. session timeout)
                                      await FirebaseAuth.instance.signOut();
                                    }
                                    if (mounted) Navigator.pop(context);
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildProgressStep(true), // Step 1
                                  const SizedBox(width: 8),
                                  _buildProgressStep(true), // Step 2 (Current)
                                  const SizedBox(width: 8),
                                  _buildProgressStep(false), // Step 3
                                  const SizedBox(width: 8),
                                  _buildProgressStep(false), // Step 4
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 17),

                          // Headlines
                          Text(
                            'Look into the light',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF324F43),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Position your face within the circle to\nhelp us keep the community safe.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              height: 1.5,
                              color: const Color(0xFF7A8C85),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Scanner Circle
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Glow/Ring
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isVerified ? const Color(0xFF7B9E89) : Colors.white, 
                                    width: 8
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      (_turnLeftDetected ? const Color(0xFF7B9E89) : (_blinkDetected ? Colors.orangeAccent : const Color(0xFF7B9E89))).withOpacity(0.5),
                                      Colors.white.withOpacity(0.2),
                                    ],
                                  ),
                                  boxShadow: [
                                     BoxShadow(
                                      color: (_isVerified ? const Color(0xFF7B9E89) : Colors.black).withOpacity(0.1),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              // Camera Preview
                              Container(
                                width: 240,
                                height: 240,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF233033),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: _isCameraInitialized
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            AspectRatio(
                                              aspectRatio: 1,
                                              child: CameraPreview(_cameraController!),
                                            ),
                                            // Live Detection Overlay
                                            if (_scanningActive && _detectedFace != null)
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: FaceOverlayPainter(
                                                    face: _detectedFace!,
                                                    imageSize: _cameraController!.value.previewSize!,
                                                    blinkDetected: _blinkDetected,
                                                  ),
                                                ),
                                              ),
                                            // Moving Laser Line Animation
                                            if (_scanningActive && !_isVerified)
                                              AnimatedBuilder(
                                                animation: _controller,
                                                builder: (context, child) {
                                                  return Positioned(
                                                    top: 40 + (160 * _controller.value),
                                                    left: 40,
                                                    right: 40,
                                                    child: Container(
                                                      height: 2,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF7B9E89),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFF7B9E89).withOpacity(0.8),
                                                            blurRadius: 10,
                                                            spreadRadius: 2,
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            // Real-time silhouette guide
                                            Center(
                                              child: Opacity(
                                                opacity: 0.15,
                                                child: Icon(
                                                  Icons.person_pin,
                                                  size: 200,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            // Rotation Gauge Overlay
                                            if (_scanningActive && !_isVerified)
                                              Positioned(
                                                bottom: 15,
                                                left: 40,
                                                right: 40,
                                                child: _buildRotationGauge(),
                                              ),
                                            // Real-time Debug Status
                                            if (_scanningActive && !_isVerified)
                                              Positioned(
                                                top: 20,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        _detectedFace != null ? "FACE LOCKED" : "SEARCHING...",
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          color: _detectedFace != null ? Colors.greenAccent : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (_detectedFace != null)
                                                        Text(
                                                          "Angle: ${_currentEulerY.toStringAsFixed(1)}°",
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 9,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        )
                                      : const Center(child: CircularProgressIndicator(color: Color(0xFF7B9E89))),
                                ),
                              ),
                              // Scanning Corners Overlay
                              SizedBox(
                                width: 140,
                                height: 170,
                                child: CustomPaint(
                                  painter: ScannerCornersPainter(),
                                ),
                              ),
                              
                              // Scanning Line Animation (Optional)
                               AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return Positioned(
                                    top: 40 + (160 * _controller.value),
                                    child: Container(
                                      width: 200,
                                      height: 2,
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFF7B9E89).withOpacity(0.5), blurRadius: 5)
                                        ],
                                        color: Colors.white.withOpacity(0.5), 
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Instruction Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFFF0F0F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isVerified ? Icons.check_circle : Icons.face_retouching_natural,
                                  color: const Color(0xFF7B9E89),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _currentInstruction,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _isVerified ? const Color(0xFF7B9E89) : const Color(0xFF1E2742),
                                          ),
                                        ),
                                        if (_detectedFace != null && !_isVerified)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.greenAccent,
                                                shape: BoxShape.circle,
                                                boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 4)],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _hintText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: const Color(0xFF7A8C85),
                                      ),
                                    ),
                                    if (_scanningActive && !_isVerified)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            _buildStepDot(_blinkDetected),
                                            _buildStepDot(_turnLeftDetected),
                                            _buildStepDot(_turnRightDetected),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                      
                      // Bottom Section
                      Column(
                        children: [
                          // Privacy Note
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1EB), // Light sage tint
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF7B9E89)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Your biometric data is encrypted and never shared. It's used only for this one-time verification.",
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      height: 1.4,
                                      color: const Color(0xFF4A6356),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Emergency Skip Button
                          if (_showSkipButton && !_isVerified)
                            TextButton(
                              onPressed: () {
                                setState(() => _isVerified = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Bypassing verification for this session...")),
                                );
                                _startScan();
                              },
                              child: Text(
                                "Cant get it work? Skip for now",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Start Scan Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _startScan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B9E89), // Primary Sage Green
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isVerified 
                                  ? 'Continue' 
                                  : (_scanningActive ? 'Scanning...' : 'Start Verification'),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          
                          // Bottom Links
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: (){}, 
                                child: Text(
                                  'Retake photo',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFAAAAAA),
                                    fontSize: 13,
                                  ),
                                )
                              ),
                              TextButton(
                                 onPressed: (){}, 
                                 child: Row(
                                   children: [
                                     Text(
                                       'Help center',
                                       style: GoogleFonts.outfit(
                                         color: const Color(0xFFAAAAAA),
                                         fontSize: 13,
                                       ),
                                     ),
                                     const SizedBox(width: 4),
                                     const Icon(Icons.open_in_new, size: 12, color: Color(0xFFAAAAAA)),
                                   ],
                                 ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
  Widget _buildRotationGauge() {
    // Determine progress based on current step
    double progress = 0;
    if (_blinkDetected && !_turnLeftDetected) {
      progress = (_currentEulerY / 20).clamp(0.0, 1.0);
    } else if (_turnLeftDetected && !_turnRightDetected) {
      progress = (_currentEulerY / -20).clamp(0.0, 1.0);
    }

    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF7B9E89),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7B9E89).withOpacity(0.5), blurRadius: 4)
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot(bool completed) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? const Color(0xFF7B9E89) : Colors.grey[200],
      ),
    );
  }

  Widget _buildProgressStep(bool isActive) {
    return Container(
      width: 60,
      height: 2,
      color: isActive ? const Color(0xFF7B9E89) : Colors.grey[300],
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final Face face;
  final Size imageSize;
  final bool blinkDetected;

  FaceOverlayPainter({
    required this.face,
    required this.imageSize,
    required this.blinkDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.height;
    final scaleY = size.height / imageSize.width;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF7B9E89).withOpacity(0.4);

    // Draw Face Bounding Box (Scaled)
    final rect = Rect.fromLTRB(
      face.boundingBox.left * scaleX,
      face.boundingBox.top * scaleY,
      face.boundingBox.right * scaleX,
      face.boundingBox.bottom * scaleY,
    );
    
    // Draw rounded corner bracket instead of full box for premium feel
    final path = Path();
    double len = 20;
    // Top Left
    path.moveTo(rect.left, rect.top + len);
    path.lineTo(rect.left, rect.top);
    path.lineTo(rect.left + len, rect.top);
    // Top Right
    path.moveTo(rect.right - len, rect.top);
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.top + len);
    // Bottom Right
    path.moveTo(rect.right, rect.bottom - len);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.right - len, rect.bottom);
    // Bottom Left
    path.moveTo(rect.left + len, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.lineTo(rect.left, rect.bottom - len);

    canvas.drawPath(path, paint);

    // Draw Eye Indicators
    final eyePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = blinkDetected ? const Color(0xFF7B9E89).withOpacity(0.8) : Colors.white.withOpacity(0.4);

    // Left Eye
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    if (leftEye != null) {
      canvas.drawCircle(
        Offset(leftEye.position.x * scaleX, leftEye.position.y * scaleY),
        4 * (face.leftEyeOpenProbability ?? 1.0).clamp(0.5, 1.0),
        eyePaint
      );
    }

    // Right Eye
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    if (rightEye != null) {
      canvas.drawCircle(
        Offset(rightEye.position.x * scaleX, rightEye.position.y * scaleY),
        4 * (face.rightEyeOpenProbability ?? 1.0).clamp(0.5, 1.0),
        eyePaint
      );
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) => true;
}

class ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double cornerLength = 20;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, 0)
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - cornerLength)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - cornerLength, size.height),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cornerLength, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
