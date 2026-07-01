import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class CameraView extends StatefulWidget {
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraInitialized;

  const CameraView({
    super.key,
    required this.onImage,
    this.onCameraInitialized,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  int _cameraIndex = -1;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Find back camera
    _cameraIndex = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;

    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup
                .nv21 // Better for ML Kit on Android
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      // Start stream
      await _controller!.startImageStream(_processImage);

      widget.onCameraInitialized?.call();
      setState(() {});
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isBusy || _controller == null) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage != null) {
      await widget.onImage(inputImage);
    }

    _isBusy = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    final bytes = _concatenatePlanes(image.planes);

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _rotationIntToImageRotation(sensorOrientation),
      format:
          InputImageFormatValue.fromRawValue(image.format.raw as int) ??
          InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    // Camera Preview covering full screen
    // We use a Transform.scale to cover the container if aspect ratio differs
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CameraPreview(_controller!),
    );
  }
}
