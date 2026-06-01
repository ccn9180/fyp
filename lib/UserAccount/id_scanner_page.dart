import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScannedIdResult {
  final String? fullName;
  final String? dob;
  final String? gender;
  final String? icNumber;
  final String? capturedImagePath;

  ScannedIdResult({
    this.fullName,
    this.dob,
    this.gender,
    this.icNumber,
    this.capturedImagePath,
  });
}

class IDScannerPage extends StatefulWidget {
  const IDScannerPage({super.key});

  @override
  State<IDScannerPage> createState() => _IDScannerPageState();
}

class _IDScannerPageState extends State<IDScannerPage> {
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isFinished = false;

  CameraImage? _latestFrame;
  Timer? _frameTimer;

  bool _isExtractionSuccess = false;
  String _statusMessage = 'Align your ID card inside the rectangle box';
  String _subStatusMessage = 'Make sure the details are clear and legible';

  // Accumulator: IC must be found consistently across frames before accepting
  String? _pendingIcNo;
  int _icConfirmCount = 0;
  static const int _icConfirmRequired = 2;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Prioritize rear camera for scanning cards
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraDescription = backCamera;

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high, // Higher resolution = sharper text for OCR
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      // Slight delay to ensure preview is ready before starting the frame stream
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      _startFrameStream();
    } catch (e) {
      debugPrint('Camera scanner init error: $e');
    }
  }

  void _startFrameStream() {
    _cameraController?.startImageStream((CameraImage img) {
      _latestFrame = img;
    });

    _frameTimer?.cancel();
    // 800ms interval — gives camera time to auto-focus between captures
    _frameTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _processLatestFrame();
    });
  }

  void _stopFrameStream() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _latestFrame = null;
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint('Stop scanning stream error: $e');
    }
  }

  InputImageRotation _rotationFromSensor(CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation90deg;
    }
  }

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

    final rotation = _rotationFromSensor(_cameraDescription!);

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || format != InputImageFormat.bgra8888) return null;
      final buf = WriteBuffer();
      for (final p in image.planes) buf.putUint8List(p.bytes);
      return InputImage.fromBytes(
        bytes: buf.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
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
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size screenSize,
    required InputImageRotation rotation,
  }) {
    final isRotated = rotation == InputImageRotation.rotation90deg ||
                      rotation == InputImageRotation.rotation270deg;
    final imageWidth = isRotated ? imageSize.height : imageSize.width;
    final imageHeight = isRotated ? imageSize.width : imageSize.height;

    final scaleX = screenSize.width / imageWidth;
    final scaleY = screenSize.height / imageHeight;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  Future<void> _processLatestFrame() async {
    if (_isFinished || _isProcessingFrame || !mounted) return;
    if (_latestFrame == null || _cameraDescription == null) return;

    _isProcessingFrame = true;
    final image = _latestFrame!;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final rotation = _rotationFromSensor(_cameraDescription!);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      if (!mounted || _isFinished) return;

      // Define screen metrics for coordinate filtering
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final screenSize = Size(screenWidth, screenHeight);

      // Card overlay alignment rectangle definition
      final scanWidth = screenWidth * 0.85;
      final scanHeight = scanWidth / 1.58;
      final scanRect = Rect.fromCenter(
        center: Offset(screenWidth / 2, screenHeight / 2 - 40),
        width: scanWidth,
        height: scanHeight,
      );

      final List<String> insideLines = [];
      final List<String> outsideLines = [];

      for (final block in recognizedText.blocks) {
        final blockScreenRect = _scaleRect(
          rect: block.boundingBox,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          screenSize: screenSize,
          rotation: rotation,
        );

        // Keep text lines if the block's center falls inside our guide box
        if (scanRect.contains(blockScreenRect.center)) {
          insideLines.addAll(block.text.split('\n'));
        } else {
          outsideLines.addAll(block.text.split('\n'));
        }
      }

      // Check text extracted inside the box first, fall back to full image if nothing found inside
      String combinedInsideText = insideLines.join('\n');
      String combinedFullText = rawText;

      String? icNo;
      String? dob;
      String? gender;

      // Parse IC (try inside first, then full raw text)
      String? normalizedIc = _findIcNumber(combinedInsideText) ?? _findIcNumber(combinedFullText);

      if (normalizedIc != null) {
        final yy = int.parse(normalizedIc.substring(0, 2));
        final mm = int.parse(normalizedIc.substring(2, 4));
        final dd = int.parse(normalizedIc.substring(4, 6));

        final now = DateTime.now();
        final currentYear2Digit = now.year % 100;
        final century = (yy <= currentYear2Digit) ? 2000 : 1900;
        final fullYear = century + yy;

        dob = "$mm/$dd/$fullYear";

        final lastDigit = int.parse(normalizedIc.substring(11, 12));
        gender = (lastDigit % 2 == 1) ? 'Male' : 'Female';
        icNo = "${normalizedIc.substring(0, 6)}-${normalizedIc.substring(6, 8)}-${normalizedIc.substring(8, 12)}";
      }

      // Fallback: Check Passport MRZ lines inside or full text
      if (dob == null || gender == null) {
        final allLinesToCheck = insideLines.isNotEmpty ? insideLines : combinedFullText.split('\n');
        for (final line in allLinesToCheck) {
          final cleanLine = line.replaceAll(' ', '').toUpperCase();
          if (cleanLine.length >= 30 && cleanLine.contains('<')) {
            final mrz2Regex = RegExp(r'[A-Z0-9]{9}[0-9]{1}[A-Z]{3}[0-9]{6}[0-9]{1}[M|F|X|<]{1}[0-9]{6}');
            final match = mrz2Regex.firstMatch(cleanLine);
            if (match != null) {
              final mrzSegment = match.group(0)!;
              final yyStr = mrzSegment.substring(13, 15);
              final mmStr = mrzSegment.substring(15, 17);
              final ddStr = mrzSegment.substring(17, 19);

              final yy = int.parse(yyStr);
              final mm = int.parse(mmStr);
              final dd = int.parse(ddStr);

              final now = DateTime.now();
              final currentYear2Digit = now.year % 100;
              final century = (yy <= currentYear2Digit) ? 2000 : 1900;
              dob = "$mm/$dd/${century + yy}";

              final gChar = mrzSegment.substring(20, 21);
              if (gChar == 'M') gender = 'Male';
              if (gChar == 'F') gender = 'Female';
              
              icNo = mrzSegment.substring(0, 9).replaceAll('<', '');
              break;
            }
          }
        }
      }

      // Try to extract Name (prefer inside lines)
      String? matchedName;
      final List<String> commonWordsToIgnore = [
        'KAD PENGENALAN', 'MALAYSIA', 'WARGANEGARA', 'ISLAM', 'MYKAD', 'PASPORT',
        'PASSPORT', 'IDENTITY CARD', 'NEGARA', 'PENGENALAN', 'KERAJAAN',
        'DETECTOR', 'SPECIMEN', 'SAMPLE', 'WAKIL', 'DOKUMEN', 'KEMENTERIAN',
        'TARIKH', 'JANTINA', 'LELAKI', 'PEREMPUAN', 'WANITA', 'ALAMAT',
        'SIGNATURE', 'TANDATANGAN', 'DATE', 'BORN', 'BIRTH', 'SEX', 'GENDER',
      ];

      final nameSearchLines = insideLines.isNotEmpty ? insideLines : combinedFullText.split('\n');
      for (final line in nameSearchLines) {
        final trimmed = line.trim();
        final upperLine = trimmed.toUpperCase();

        // Skip if too short or too long
        if (upperLine.length < 5 || upperLine.length > 60) continue;

        // Skip lines that contain digits (IC number, DOB etc.)
        if (RegExp(r'\d').hasMatch(trimmed)) continue;

        // Skip lines with special chars except space, @, /, - (for names like BIN/BINTI)
        if (!RegExp(r"^[A-Za-z\s@/\-'.]+$").hasMatch(trimmed)) continue;

        // Skip known label words
        if (commonWordsToIgnore.any((word) => upperLine.contains(word))) continue;

        // Must have at least 2 words (first + last name minimum)
        final words = upperLine.split(RegExp(r'\s+'));
        if (words.length < 2) continue;

        // Skip single-character words dominating the line
        if (words.any((w) => w.length == 1 && w != 'A')) continue;

        matchedName = trimmed;
        break;
      }

      // Validate that we are scanning the FRONT side of the MyKad/Passport (Malaysia rules)
      final upperRawText = combinedFullText.toUpperCase();
      final hasFrontKeywords = upperRawText.contains('KAD PENGENALAN') ||
          upperRawText.contains('PENGENALAN') ||
          upperRawText.contains('WARGANEGARA') ||
          upperRawText.contains('MYKAD') ||
          upperRawText.contains('PASPORT') ||
          upperRawText.contains('PASSPORT') ||
          upperRawText.contains('IDENTITY');

      // If an IC number was found but we don't detect any front keywords, reject it and guide user to flip
      if (icNo != null && !hasFrontKeywords) {
        setState(() {
          _statusMessage = 'Please scan the FRONT of your ID';
          _subStatusMessage = 'Flip your ID card over to the front side';
        });
        _pendingIcNo = null;
        _icConfirmCount = 0;
        _isProcessingFrame = false;
        return;
      }

      // If at least we got an IC/Passport number, cross-check over 2 frames before accepting
      if (icNo != null) {
        if (icNo == _pendingIcNo) {
          _icConfirmCount++;
        } else {
          // New IC candidate — reset counter
          _pendingIcNo = icNo;
          _icConfirmCount = 1;
        }

        if (_icConfirmCount >= _icConfirmRequired) {
          setState(() {
            _isFinished = true;
            _isExtractionSuccess = true;
            _statusMessage = '✓ ID Detected!';
            _subStatusMessage = 'Capturing... please hold still';
          });
          _stopFrameStream();
          HapticFeedback.lightImpact();

          Future.delayed(const Duration(milliseconds: 800), () async {
            if (!mounted) return;
            // Capture a still photo of the IC for face verification
            String? capturedPath;
            try {
              final photo = await _cameraController?.takePicture();
              capturedPath = photo?.path;
            } catch (e) {
              debugPrint('Failed to capture IC photo: $e');
            }
            HapticFeedback.heavyImpact();
            if (mounted) {
              Navigator.pop(
                context,
                ScannedIdResult(
                  fullName: matchedName,
                  dob: dob,
                  gender: gender,
                  icNumber: icNo,
                  capturedImagePath: capturedPath,
                ),
              );
            }
          });
        } else {
          // Show scanning in progress
          setState(() {
            _statusMessage = 'ID found, confirming...';
            _subStatusMessage = 'Hold still for a moment';
          });
        }
      } else {
        // Reset confirmation if IC disappears
        _pendingIcNo = null;
        _icConfirmCount = 0;
      }
    } catch (e) {
      debugPrint('Scan image processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  String _normalizeToDigits(String input) {
    // Only correct characters that are visually near-identical to digits
    // Be conservative — aggressive mapping causes false positives
    final map = {
      'O': '0', 'o': '0', 'D': '0',
      'I': '1', 'i': '1', 'l': '1', 'L': '1', '|': '1',
      'Z': '2', 'z': '2',
      'S': '5', 's': '5',
      'G': '6', 'b': '6',
      'B': '8',
    };

    String result = '';
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (map.containsKey(char)) {
        result += map[char]!;
      } else {
        result += char;
      }
    }
    return result;
  }

  bool _isValidIcDate(String rawIc) {
    if (rawIc.length != 12) return false;
    if (!RegExp(r'^\d{12}$').hasMatch(rawIc)) return false;
    int mm = int.tryParse(rawIc.substring(2, 4)) ?? 0;
    int dd = int.tryParse(rawIc.substring(4, 6)) ?? 0;
    if (mm < 1 || mm > 12) return false;
    if (dd < 1 || dd > 31) return false;
    if (mm == 2 && dd > 29) return false;
    if ((mm == 4 || mm == 6 || mm == 9 || mm == 11) && dd > 30) return false;
    return true;
  }

  String? _findIcNumber(String text) {
    final regex = RegExp(
      r'([0-9oOiIl|sSzZeEaAbBgGqQtT]{6})[\s\-]*([0-9oOiIl|sSzZeEaAbBgGqQtT]{2})[\s\-]*([0-9oOiIl|sSzZeEaAbBgGqQtT]{4})',
      caseSensitive: false,
    );
    
    final matches = regex.allMatches(text);
    for (final match in matches) {
      final group1 = match.group(1) ?? '';
      final group2 = match.group(2) ?? '';
      final group3 = match.group(3) ?? '';
      final candidate = '$group1$group2$group3';
      final normalized = _normalizeToDigits(candidate);
      if (_isValidIcDate(normalized)) {
        return normalized;
      }
    }

    final lines = text.split('\n');
    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      for (int i = 0; i <= cleanLine.length - 12; i++) {
        final candidate = cleanLine.substring(i, i + 12);
        final normalized = _normalizeToDigits(candidate);
        if (_isValidIcDate(normalized)) {
          return normalized;
        }
      }
    }
    
    return null;
  }

  @override
  void dispose() {
    _stopFrameStream();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final scanWidth = screenWidth * 0.85;
    final scanHeight = scanWidth / 1.58;
    final scanRect = Rect.fromCenter(
      center: Offset(screenWidth / 2, screenHeight / 2 - 40),
      width: scanWidth,
      height: scanHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B9E89)),
            ),

          // 2. Translucent mask overlay with clear cutout box
          CustomPaint(
            size: Size(screenWidth, screenHeight),
            painter: ScannerOverlayPainter(scanRect: scanRect, isSuccess: _isExtractionSuccess),
          ),

          // 3. Header title and cancel button
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Scan ID / Passport',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48), // Equal spacing buffer
              ],
            ),
          ),

          // 4. Instructions under the rectangle box
          Positioned(
            top: scanRect.bottom + 24,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: _isExtractionSuccess ? const Color(0xFF81C784) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subStatusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: _isExtractionSuccess ? const Color(0xFFC8E6C9) : Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final bool isSuccess;

  ScannerOverlayPainter({required this.scanRect, required this.isSuccess});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    
    // Draw background
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw clear cut-out
    final cutoutPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;
    final RRect roundedScanRect = RRect.fromRectAndRadius(scanRect, const Radius.circular(16));
    canvas.drawRRect(roundedScanRect, cutoutPaint);

    canvas.restore();

    // Draw border (turn green on success)
    final borderPaint = Paint()
      ..color = isSuccess ? const Color(0xFF2E7D32) : const Color(0xFF7B9E89)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(roundedScanRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect || oldDelegate.isSuccess != isSuccess;
  }
}
