// Document Detector Logic
//
// Wrapper around ML Kit Object Detection for document boundary detection.
// Processes camera frames to find rectangular document regions.

import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class DocumentDetector {
  ObjectDetector? _objectDetector;
  bool _isInitialized = false;

  DocumentDetector() {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;

    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: false,
      multipleObjects: false,
    );

    _objectDetector = ObjectDetector(options: options);
    _isInitialized = true;
  }

  /// Detect document in camera image frame
  /// Returns 4 corner points if document found, null otherwise
  Future<List<Offset>?> detectDocument(CameraImage image) async {
    if (!_isInitialized || _objectDetector == null) return null;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return null;

      final objects = await _objectDetector!.processImage(inputImage);

      if (objects.isEmpty) return null;

      // Find the largest object (most likely the document)
      DetectedObject? largest;
      double largestArea = 0;

      for (final obj in objects) {
        final area = obj.boundingBox.width * obj.boundingBox.height;
        if (area > largestArea) {
          largestArea = area;
          largest = obj;
        }
      }

      if (largest == null) return null;

      // Convert bounding box to 4 corner points
      final rect = largest.boundingBox;
      return [
        Offset(rect.left, rect.top), // Top-left
        Offset(rect.right, rect.top), // Top-right
        Offset(rect.right, rect.bottom), // Bottom-right
        Offset(rect.left, rect.bottom), // Bottom-left
      ];
    } catch (e) {
      debugPrint('Document detection error: $e');
      return null;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageRotation = InputImageRotation.rotation0deg;

      final inputImageFormat = InputImageFormat.values.firstWhere(
        (format) => format.rawValue == image.format.raw,
        orElse: () => InputImageFormat.nv21,
      );

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  void dispose() {
    _objectDetector?.close();
    _isInitialized = false;
  }
}
