import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../User/main_screen.dart';

enum _VerificationPhase { uploadID, liveScan, result }
enum _LivenessStep { scanning, done }

class VerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final bool isGoogle;
  final String fullName;
  final String dob;
  final String icNumber;
  final String gender;
  /// Optional: path to the IC image captured by IDScannerPage.
  /// When provided the user skips the manual upload step and goes
  /// straight to the live face scan.
  final String? icImagePath;

  const VerificationPage({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.dob,
    required this.icNumber,
    required this.gender,
    this.isGoogle = false,
    this.icImagePath,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage>
    with TickerProviderStateMixin {
  // ── State Phases ───────────────────────────────────────────────────────────
  _VerificationPhase _currentPhase = _VerificationPhase.uploadID;
  _LivenessStep _currentLivenessStep = _LivenessStep.scanning;

  // ── ID Face Extraction (Phase 1) ───────────────────────────────────────────
  File? _idImageFile;
  Face? _idFace;
  Size? _idImageSize;
  bool _isProcessingId = false;
  bool _idFaceExtracted = false;
  String? _idErrorMessage;

  // ── Camera / ML Live Scan (Phase 2) ────────────────────────────────────────
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  FaceDetector? _faceDetector;

  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _streamStarted = false;

  Face? _detectedFace;
  CameraImage? _latestFrame;
  Timer? _frameTimer;

  // Scan frame counting
  int _alignFrames = 0;
  static const int _framesRequired = 6; // collect 6 good frames then finish

  // Similarity tracking
  final List<double> _similarities = [];
  double _similarityScore = 0.0;
  bool _verificationSuccess = false;

  // ── UI / Animation ─────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _faceStatus = 'Align face in the center';

  InputImageRotation get _imageRotation {
    if (Platform.isIOS) return InputImageRotation.rotation0deg;
    return InputImageRotation.rotation270deg;
  }

  // Scan instruction
  String get _stepInstruction {
    switch (_currentLivenessStep) {
      case _LivenessStep.scanning:
        return 'Keep still, scanning your face...';
      case _LivenessStep.done:
        return 'Processing results...';
    }
  }

  String get _stepHint {
    switch (_currentLivenessStep) {
      case _LivenessStep.scanning:
        return 'Look straight at the camera and hold steady';
      case _LivenessStep.done:
        return 'Comparing with your IC photo...';
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeFaceDetector();

    // If an IC image was captured during scanning, auto-process it
    if (widget.icImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoProcessIcImage(widget.icImagePath!);
      });
    }
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  // ── Auto-process IC image from scanner (skips manual upload) ──────────────

  Future<void> _autoProcessIcImage(String imagePath) async {
    setState(() {
      _idImageFile = File(imagePath);
      _isProcessingId = true;
      _idFaceExtracted = false;
      _idErrorMessage = null;
      // Stay on uploadID phase briefly to show the extracted image
      _currentPhase = _VerificationPhase.uploadID;
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      // Give the detector time to initialize
      await Future.delayed(const Duration(milliseconds: 300));
      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        // No face on IC — fall back to manual upload
        setState(() {
          _idErrorMessage = 'Could not detect a face on the scanned IC. Please upload manually.';
          _isProcessingId = false;
        });
        return;
      }

      final imageSize = await _getImageSize(_idImageFile!);
      if (!mounted) return;

      setState(() {
        _idFace = faces.first;
        _idImageSize = imageSize;
        _idFaceExtracted = true;
        _isProcessingId = false;
      });

      // Small pause so the user sees the detected ID, then go to scan
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _startLiveScan();
    } catch (e) {
      if (mounted) {
        setState(() {
          _idErrorMessage = 'Error processing IC image: $e';
          _isProcessingId = false;
        });
      }
    }
  }

  // ── Phase 1: ID Image Upload & Face Extraction ─────────────────────────────

  Future<void> _pickIdImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _idImageFile = File(image.path);
      _isProcessingId = true;
      _idFaceExtracted = false;
      _idErrorMessage = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _idErrorMessage = "No face detected on the ID. Please choose a clearer photo.";
          _isProcessingId = false;
        });
        return;
      }

      final imageSize = await _getImageSize(_idImageFile!);
      if (!mounted) return;

      setState(() {
        _idFace = faces.first;
        _idImageSize = imageSize;
        _idFaceExtracted = true;
        _isProcessingId = false;
      });

      // Auto-transition to live scan page after a small pause so they see the success/face box
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      _startLiveScan();
    } catch (e) {
      if (mounted) {
        setState(() {
          _idErrorMessage = "Error extracting face: $e";
          _isProcessingId = false;
        });
      }
    }
  }

  Future<Size> _getImageSize(File file) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.file(file);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }),
    );
    return completer.future;
  }

  // ── Phase 2: Live Scanning setup ───────────────────────────────────────────

  Future<void> _startLiveScan() async {
    if (!_idFaceExtracted || _idFace == null) return;

    setState(() {
      _currentPhase = _VerificationPhase.liveScan;
      _currentLivenessStep = _LivenessStep.scanning;
      _alignFrames = 0;
      _similarities.clear();
      _faceStatus = 'Align face in the center';
    });

    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraDescription = frontCamera;

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      _startFrameStream();
    } catch (e) {
      debugPrint('Camera init error: $e');
      setState(() => _faceStatus = 'Camera error — check permissions');
    }
  }

  void _startFrameStream() {
    if (_streamStarted) return;
    _streamStarted = true;

    _cameraController?.startImageStream((CameraImage img) {
      _latestFrame = img;
    });

    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _processLatestFrame();
    });
  }

  void _stopFrameStream() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _latestFrame = null;
    _streamStarted = false;
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint('Stop streaming error: $e');
    }
  }

  // ── Frame Processing & Geometric Comparison ────────────────────────────────

  Uint8List _convertYUV420toNV21(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final ySize = yPlane.bytes.length;
    final uvLen = uPlane.bytes.length;
    final nv21 = Uint8List(ySize + uvLen * 2);
    nv21.setRange(0, ySize, yPlane.bytes);
    int idx = ySize;
    for (int i = 0; i < uvLen; i++) {
      nv21[idx++] = vPlane.bytes[i];
      nv21[idx++] = uPlane.bytes[i];
    }
    return nv21;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraDescription == null) return null;

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || format != InputImageFormat.bgra8888) return null;
      final buf = WriteBuffer();
      for (final p in image.planes) buf.putUint8List(p.bytes);
      return InputImage.fromBytes(
        bytes: buf.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } else {
      if (image.planes.length < 3) return null;
      return InputImage.fromBytes(
        bytes: _convertYUV420toNV21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
  }

  Future<void> _processLatestFrame() async {
    if (_isProcessingFrame || !mounted) return;
    if (_faceDetector == null || _latestFrame == null || _currentLivenessStep == _LivenessStep.done) return;

    _isProcessingFrame = true;
    final image = _latestFrame!;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _detectedFace = null;
          _faceStatus = 'No face detected';
        });
        _isProcessingFrame = false;
        return;
      }

      final face = faces.first;
      setState(() {
        _detectedFace = face;
      });

      _updateFaceStatus(face, image.width.toDouble(), image.height.toDouble());
      _advanceLiveness(face);
    } catch (e) {
      debugPrint('Live frame process error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _updateFaceStatus(Face face, double imgW, double imgH) {
    // On Android the camera stream is rotated 90°/270°, so width/height are swapped
    final bool isRotated = _imageRotation == InputImageRotation.rotation90deg ||
        _imageRotation == InputImageRotation.rotation270deg;
    final double frameW = isRotated ? imgH : imgW;
    final double frameH = isRotated ? imgW : imgH;

    final box = face.boundingBox;
    final double w = box.width, h = box.height;
    final double cx = box.center.dx, cy = box.center.dy;

    // Proportional thresholds — works on any camera resolution
    final double minFaceRatio = 0.18; // face must be at least 18% of frame
    final double maxFaceRatio = 0.65; // face must not exceed 65% of frame
    final double centerMarginX = 0.20; // allow 20% margin from each side
    final double centerMarginY = 0.20;

    String s;
    if (w / frameW < minFaceRatio || h / frameH < minFaceRatio) {
      s = 'Too far — move closer';
    } else if (w / frameW > maxFaceRatio || h / frameH > maxFaceRatio) {
      s = 'Too close — move back';
    } else if (cx / frameW < centerMarginX) {
      s = 'Move right';
    } else if (cx / frameW > 1.0 - centerMarginX) {
      s = 'Move left';
    } else if (cy / frameH < centerMarginY) {
      s = 'Move down';
    } else if (cy / frameH > 1.0 - centerMarginY) {
      s = 'Move up';
    } else {
      s = 'Good position';
    }
    if (_faceStatus != s) setState(() => _faceStatus = s);
  }

  double _calculateSimilarity(Face idFace, Face liveFace) {
    Point<int>? getPos(Face face, FaceLandmarkType type) {
      return face.landmarks[type]?.position;
    }

    final idLeftEye = getPos(idFace, FaceLandmarkType.leftEye);
    final idRightEye = getPos(idFace, FaceLandmarkType.rightEye);
    final idNose = getPos(idFace, FaceLandmarkType.noseBase);
    final idMouthLeft = getPos(idFace, FaceLandmarkType.leftMouth);
    final idMouthRight = getPos(idFace, FaceLandmarkType.rightMouth);
    final idLeftCheek = getPos(idFace, FaceLandmarkType.leftCheek);
    final idRightCheek = getPos(idFace, FaceLandmarkType.rightCheek);

    final liveLeftEye = getPos(liveFace, FaceLandmarkType.leftEye);
    final liveRightEye = getPos(liveFace, FaceLandmarkType.rightEye);
    final liveNose = getPos(liveFace, FaceLandmarkType.noseBase);
    final liveMouthLeft = getPos(liveFace, FaceLandmarkType.leftMouth);
    final liveMouthRight = getPos(liveFace, FaceLandmarkType.rightMouth);
    final liveLeftCheek = getPos(liveFace, FaceLandmarkType.leftCheek);
    final liveRightCheek = getPos(liveFace, FaceLandmarkType.rightCheek);

    double dist(Point<int> p1, Point<int> p2) {
      return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
    }

    Map<String, double>? getRatios(
      Point<int>? leftEye,
      Point<int>? rightEye,
      Point<int>? nose,
      Point<int>? mouthLeft,
      Point<int>? mouthRight,
      Point<int>? leftCheek,
      Point<int>? rightCheek,
      Rect boundingBox,
    ) {
      if (leftEye == null || rightEye == null || nose == null || mouthLeft == null || mouthRight == null) {
        return null;
      }

      final eyeDist = dist(leftEye, rightEye);
      if (eyeDist <= 0) return null;

      final noseToLeftEye = dist(nose, leftEye);
      final noseToRightEye = dist(nose, rightEye);
      final mouthWidth = dist(mouthLeft, mouthRight);
      final mouthCenter = Point<int>(
        ((mouthLeft.x + mouthRight.x) / 2).round(),
        ((mouthLeft.y + mouthRight.y) / 2).round(),
      );
      final noseToMouth = dist(nose, mouthCenter);

      final leftEyeToMouth = dist(leftEye, mouthLeft);
      final rightEyeToMouth = dist(rightEye, mouthRight);

      final double cheekDist = (leftCheek != null && rightCheek != null) ? dist(leftCheek, rightCheek) : 0.0;

      final double boxWidth = boundingBox.width.toDouble();
      final double boxHeight = boundingBox.height.toDouble();
      final double aspect = boxWidth > 0 ? boxHeight / boxWidth : 1.3;

      return {
        'eyeToNose': (noseToLeftEye + noseToRightEye) / (2 * eyeDist),
        'mouthWidth': mouthWidth / eyeDist,
        'eyeToMouth': (leftEyeToMouth + rightEyeToMouth) / (2 * eyeDist),
        'noseToMouth': noseToMouth / eyeDist,
        if (cheekDist > 0) 'cheekToCheek': cheekDist / eyeDist,
        'aspect': aspect,
      };
    }

    final idRatios = getRatios(idLeftEye, idRightEye, idNose, idMouthLeft, idMouthRight, idLeftCheek, idRightCheek, idFace.boundingBox);
    final liveRatios = getRatios(liveLeftEye, liveRightEye, liveNose, liveMouthLeft, liveMouthRight, liveLeftCheek, liveRightCheek, liveFace.boundingBox);

    if (idRatios == null || liveRatios == null) return 0.0;

    double totalError = 0.0;
    int count = 0;

    idRatios.forEach((key, idValue) {
      final liveValue = liveRatios[key];
      if (liveValue != null) {
        totalError += (idValue - liveValue).abs();
        count++;
      }
    });

    if (count == 0) return 0.0;

    final double averageError = totalError / count;

    // Map averageError: 0.00 -> 1.0 (100%), averageError >= 0.15 -> 0.0 (0%)
    return max(0.0, 1.0 - (averageError / 0.15));
  }

  void _advanceLiveness(Face face) {
    final eulerY = face.headEulerAngleY ?? 0;
    final eulerX = face.headEulerAngleX ?? 0;
    final inPosition = _faceStatus == 'Good position';

    if (_currentLivenessStep != _LivenessStep.scanning) return;

    if (inPosition && eulerY.abs() < 12 && eulerX.abs() < 12) {
      _alignFrames++;
      // Collect similarity every frame when in position
      if (_idFace != null) {
        final score = _calculateSimilarity(_idFace!, face);
        _similarities.add(score);
      }
      if (_alignFrames >= _framesRequired) {
        _similarityScore = _similarities.isNotEmpty
            ? _similarities.reduce((a, b) => a + b) / _similarities.length
            : 0.0;
        _advanceStep(_LivenessStep.done);
      }
    } else {
      // Reset if face moves out of position but keep accumulated similarities
      _alignFrames = 0;
    }
  }

  void _advanceStep(_LivenessStep next) {
    HapticFeedback.mediumImpact();
    setState(() => _currentLivenessStep = next);

    if (next == _LivenessStep.done) {
      _stopFrameStream();
      HapticFeedback.heavyImpact();
      _finishFaceVerification();
    }
  }

  // ── Verification Completion & Firestore Upload ──────────────────────────────

  Future<void> _finishFaceVerification() async {
    // 1. Enforce similarity threshold >= 70%
    final bool matchSuccess = _similarityScore >= 0.70;  // 70% threshold - accounts for IC photo quality/angle
    
    setState(() {
      _verificationSuccess = matchSuccess;
      _currentPhase = _VerificationPhase.result;
    });

    if (!matchSuccess) return; // Stop if verification fails, user gets retry card

    // Show loading modal on successful match
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      XFile? faceImage;
      try {
        faceImage = await _cameraController?.takePicture();
      } catch (e) {
        debugPrint('Failed to snap matching face: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('liveness_verified', true);

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Session lost. Please log in again.");

      String? faceImageUrl;
      if (faceImage != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child('user_faces').child('${user.uid}.jpg');
          await ref.putFile(File(faceImage.path));
          faceImageUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Upload matching face error: $e');
        }
      }

      // Save complete registration payload
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': widget.email,
        'fullName': widget.fullName,
        'dateOfBirth': widget.dob,
        'icNumber': widget.icNumber,
        'gender': widget.gender,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': user.emailVerified,
        'faceImageUrl': faceImageUrl,
        'matchConfidence': _similarityScore,
      });

      await user.updateDisplayName(widget.fullName);

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account verified and registered successfully!"),
          backgroundColor: Color(0xFF7B9E89),
        ),
      );

      // Auto-navigate directly to the Home Page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification registration failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  // Retry live scanner only (keeps existing ID document)
  Future<void> _retryLiveScan() async {
    setState(() {
      _currentPhase = _VerificationPhase.liveScan;
      _currentLivenessStep = _LivenessStep.scanning;
      _alignFrames = 0;
      _similarities.clear();
      _faceStatus = 'Align face in the center';
    });
    await _initializeCamera();
  }

  Future<void> _cancelAndGoBack() async {
    _stopFrameStream();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  // ── Build Layouts ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelAndGoBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF7),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3-Step Onboarding Progress Bar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _cancelAndGoBack,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E2742)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildProgressStep(true),
                        const SizedBox(width: 8),
                        _buildProgressStep(true),
                        const SizedBox(width: 8),
                        _buildProgressStep(true), // Verification step active
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  'Face Verification',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF324F43),
                  ),
                ),
                const SizedBox(height: 8),

                // Phase switching build
                if (_currentPhase == _VerificationPhase.uploadID)
                  _buildUploadIdPhase()
                else if (_currentPhase == _VerificationPhase.liveScan)
                  _buildLiveScanPhase()
                else
                  _buildResultPhase(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Phase 1: Upload ID Layout
  Widget _buildUploadIdPhase() {
    final bool isAutoMode = widget.icImagePath != null;

    return Column(
      children: [
        Text(
          isAutoMode
              ? 'Preparing your IC for face verification...'
              : 'We need to extract your face from your ID card or passport.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: const Color(0xFF7A8C85)),
        ),
        const SizedBox(height: 32),

        // Card Container Slot
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _idFaceExtracted
                  ? const Color(0xFF7B9E89)
                  : (_idErrorMessage != null ? Colors.red.shade200 : Colors.grey.shade200),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _idImageFile == null
                ? (isAutoMode
                    // Auto mode: show loading while image is being set up
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B9E89)))
                    : InkWell(
                        onTap: () => _showPickerOptions(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F1EB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF7B9E89), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Upload ID card / Passport',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E2742)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to select from Camera or Gallery',
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_idImageFile!, fit: BoxFit.cover),
                      // If face is found, overlay highlight box
                      if (_idFaceExtracted && _idFace != null && _idImageSize != null)
                        CustomPaint(
                          painter: _IdFacePainter(
                            boundingBox: _idFace!.boundingBox,
                            imageSize: _idImageSize!,
                          ),
                        ),
                      if (_isProcessingId)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Helper messages
        if (_idFaceExtracted)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text(
                isAutoMode ? 'IC face detected — starting scan...' : 'Face detected on ID successfully!',
                style: GoogleFonts.outfit(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          )
        else if (_idErrorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _idErrorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),

        const SizedBox(height: 40),

        // Buttons — only shown in manual mode or on error
        if (!isAutoMode && _idImageFile != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _idFaceExtracted && !_isProcessingId ? _startLiveScan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B9E89),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'Start Face Verification',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _showPickerOptions(),
            child: Text(
              'Upload Different Image',
              style: GoogleFonts.outfit(color: const Color(0xFF7B9E89), fontWeight: FontWeight.w600),
            ),
          ),
        ],

        // In auto mode, only show retry option if there was an error
        if (isAutoMode && _idErrorMessage != null && !_isProcessingId) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _showPickerOptions(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B9E89),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'Upload ID Manually',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],

        // In auto mode and no error, no manual upload button is shown
        if (!isAutoMode && _idImageFile == null)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _showPickerOptions(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B9E89),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'Upload ID card / Passport',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF7B9E89)),
              title: Text('Take Photo', style: GoogleFonts.outfit()),
              onTap: () {
                Navigator.pop(context);
                _pickIdImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF7B9E89)),
              title: Text('Choose from Gallery', style: GoogleFonts.outfit()),
              onTap: () {
                Navigator.pop(context);
                _pickIdImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Phase 2: Live Scanning Layout
  Widget _buildLiveScanPhase() {
    // How many frames collected so far (capped to framesRequired)
    final progress = (_alignFrames / _framesRequired).clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          'Look straight at the camera to compare with your IC photo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: const Color(0xFF7A8C85)),
        ),
        const SizedBox(height: 24),

        // Live camera preview with guided overlay
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) {
            final scale = _currentLivenessStep == _LivenessStep.scanning
                ? _pulseAnimation.value
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Scanning progress ring
                    CustomPaint(
                      size: const Size(270, 270),
                      painter: _ScanningProgressPainter(
                        progress: progress,
                        isDone: _currentLivenessStep == _LivenessStep.done,
                      ),
                    ),

                    // Camera clip preview
                    ClipOval(
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: _buildCameraPreview(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Position/Action Status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _faceStatus == 'Good position'
                ? const Color(0xFFE8F1EB)
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: _faceStatus == 'Good position' ? const Color(0xFF2E7D32) : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _faceStatus,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _faceStatus == 'Good position'
                      ? const Color(0xFF2E7D32)
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Instruction card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stepInstruction,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E2742),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stepHint,
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF7A8C85)),
              ),
              const SizedBox(height: 16),
              // Simple progress bar showing scanning progress
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? const Color(0xFF2E7D32) : const Color(0xFF7B9E89),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _alignFrames >= _framesRequired
                    ? 'Scan complete ✓'
                    : 'Scanning... hold still',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: _alignFrames >= _framesRequired
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B9E89)),
        ),
      );
    }

    final previewSize = _cameraController!.value.previewSize;
    if (previewSize == null) return Container(color: Colors.black);

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  // Phase 3: Results Layout
  Widget _buildResultPhase() {
    final matchPct = (_similarityScore * 100).round();
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Icon Status Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _verificationSuccess ? const Color(0xFFE8F1EB) : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _verificationSuccess ? Icons.verified_user_rounded : Icons.gpp_bad_outlined,
                  size: 56,
                  color: _verificationSuccess ? const Color(0xFF7B9E89) : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _verificationSuccess ? 'Verification Successful' : 'Verification Failed',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E2742),
                ),
              ),
              const SizedBox(height: 12),

              // Similarity Score Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _verificationSuccess ? const Color(0xFF7B9E89).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$matchPct% Similarity Match',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _verificationSuccess ? const Color(0xFF4A6356) : Colors.redAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _verificationSuccess
                    ? 'Congratulations! Your facial features match the uploaded ID document. You are set to go.'
                    : 'The facial match ratio is below the secure threshold. Please retry in a well-lit area or capture a clearer ID photo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF7A8C85), height: 1.6),
              ),
              const SizedBox(height: 32),

              // Primary Actions
              if (_verificationSuccess)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Processing...',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7B9E89),
                      ),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _retryLiveScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B9E89),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Retry Live Face Scan',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Utils ──────────────────────────────────────────────────────────────────

  Widget _buildProgressStep(bool active) {
    return Container(
      width: 60,
      height: 2,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7B9E89) : Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// Custom Painter to draw bounding box on selected ID document face
class _IdFacePainter extends CustomPainter {
  final Rect boundingBox;
  final Size imageSize;

  _IdFacePainter({required this.boundingBox, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final rect = Rect.fromLTRB(
      boundingBox.left * scaleX,
      boundingBox.top * scaleY,
      boundingBox.right * scaleX,
      boundingBox.bottom * scaleY,
    );

    final paint = Paint()
      ..color = const Color(0xFF7B9E89)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
  }

  @override
  bool shouldRepaint(covariant _IdFacePainter oldDelegate) {
    return oldDelegate.boundingBox != boundingBox || oldDelegate.imageSize != imageSize;
  }
}

// Custom Painter for the circular scanning progress ring
class _ScanningProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isDone;

  _ScanningProgressPainter({required this.progress, this.isDone = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeWidth = 5.0;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.shade200;

    // Background ring
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = isDone ? const Color(0xFF2E7D32) : const Color(0xFF7B9E89);

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanningProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDone != isDone;
  }
}