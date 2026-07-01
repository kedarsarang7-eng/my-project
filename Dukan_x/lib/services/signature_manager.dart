// Signature Management Service
// Handles signature upload, drawing, and storage for invoice generation
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

/// Signature Manager for handling signature capture, storage, and retrieval
class SignatureManager {
  static final SignatureManager _instance = SignatureManager._internal();
  factory SignatureManager() => _instance;
  SignatureManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Uint8List? _cachedSignature;
  bool _isLoaded = false;

  // ========== SIGNATURE RETRIEVAL ==========

  /// Get signature for current owner
  Future<Uint8List?> getSignature() async {
    if (_isLoaded && _cachedSignature != null) {
      return _cachedSignature;
    }

    final ownerId = sessionService.getOwnerDocId();
    if (ownerId == null) return null;

    // Try Firestore first
    try {
      final doc = await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('settings')
          .doc('signature')
          .get();

      if (doc.exists && doc.data()?['signatureBase64'] != null) {
        final base64String = doc.data()!['signatureBase64'] as String;
        _cachedSignature = base64Decode(base64String);
        _isLoaded = true;
        return _cachedSignature;
      }
    } catch (e) {
      debugPrint('Error loading signature from Firestore: $e');
    }

    // Try local storage as fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString('signature_$ownerId');
      if (base64String != null) {
        _cachedSignature = base64Decode(base64String);
        _isLoaded = true;
        return _cachedSignature;
      }
    } catch (e) {
      debugPrint('Error loading signature from local: $e');
    }

    return null;
  }

  /// Check if signature exists
  Future<bool> hasSignature() async {
    final signature = await getSignature();
    return signature != null && signature.isNotEmpty;
  }

  // ========== SIGNATURE STORAGE ==========

  /// Save signature to Firestore and local storage
  Future<bool> saveSignature(Uint8List signatureBytes) async {
    final ownerId = sessionService.getOwnerDocId();
    if (ownerId == null) return false;

    try {
      final base64String = base64Encode(signatureBytes);

      // Save to Firestore
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('settings')
          .doc('signature')
          .set({
            'signatureBase64': base64String,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('signature_$ownerId', base64String);

      // Update cache
      _cachedSignature = signatureBytes;
      _isLoaded = true;

      return true;
    } catch (e) {
      debugPrint('Error saving signature: $e');
      return false;
    }
  }

  /// Delete signature
  Future<bool> deleteSignature() async {
    final ownerId = sessionService.getOwnerDocId();
    if (ownerId == null) return false;

    try {
      // Delete from Firestore
      await _firestore
          .collection('owners')
          .doc(ownerId)
          .collection('settings')
          .doc('signature')
          .delete();

      // Delete from local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signature_$ownerId');

      // Clear cache
      _cachedSignature = null;
      _isLoaded = false;

      return true;
    } catch (e) {
      debugPrint('Error deleting signature: $e');
      return false;
    }
  }

  // ========== SIGNATURE UPLOAD ==========

  /// Pick signature image from gallery
  Future<Uint8List?> pickSignatureFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 200,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        return _processSignatureImage(bytes);
      }
    } catch (e) {
      debugPrint('Error picking signature image: $e');
    }
    return null;
  }

  /// Pick signature image from camera
  Future<Uint8List?> pickSignatureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 200,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        return _processSignatureImage(bytes);
      }
    } catch (e) {
      debugPrint('Error capturing signature image: $e');
    }
    return null;
  }

  /// Process and optimize signature image
  Future<Uint8List> _processSignatureImage(Uint8List bytes) async {
    // For now, just return the bytes
    // In production, you could add image processing/cropping here
    return bytes;
  }

  // ========== SIGNATURE DRAWING ==========

  /// Convert signature drawing points to image bytes
  Future<Uint8List?> convertDrawingToImage(
    List<List<Offset>> strokes,
    Size canvasSize,
  ) async {
    if (strokes.isEmpty) return null;

    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.white,
      );

      // Draw strokes
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final stroke in strokes) {
        if (stroke.length < 2) continue;

        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);

        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }

        canvas.drawPath(path, paint);
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error converting drawing to image: $e');
      return null;
    }
  }

  /// Clear cached signature (for logout/switch account)
  void clearCache() {
    _cachedSignature = null;
    _isLoaded = false;
  }
}

/// Signature Drawing Canvas Widget
class SignatureDrawingCanvas extends StatefulWidget {
  final double width;
  final double height;
  final Color backgroundColor;
  final Color strokeColor;
  final double strokeWidth;
  final Function(List<List<Offset>>)? onDrawingChanged;

  const SignatureDrawingCanvas({
    super.key,
    this.width = 300,
    this.height = 150,
    this.backgroundColor = Colors.white,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.5,
    this.onDrawingChanged,
  });

  @override
  State<SignatureDrawingCanvas> createState() => SignatureDrawingCanvasState();
}

class SignatureDrawingCanvasState extends State<SignatureDrawingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  List<List<Offset>> get strokes => _strokes;
  bool get isEmpty => _strokes.isEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
    widget.onDrawingChanged?.call(_strokes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _currentStroke = [details.localPosition];
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _currentStroke.add(details.localPosition);
            });
          },
          onPanEnd: (details) {
            if (_currentStroke.length > 1) {
              setState(() {
                _strokes.add(List.from(_currentStroke));
                _currentStroke.clear();
              });
              widget.onDrawingChanged?.call(_strokes);
            }
          },
          child: CustomPaint(
            painter: _SignaturePainter(
              strokes: _strokes,
              currentStroke: _currentStroke,
              strokeColor: widget.strokeColor,
              strokeWidth: widget.strokeWidth,
            ),
            size: Size(widget.width, widget.height),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Draw current stroke
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) return;

    final path = Path();
    path.moveTo(stroke[0].dx, stroke[0].dy);

    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
