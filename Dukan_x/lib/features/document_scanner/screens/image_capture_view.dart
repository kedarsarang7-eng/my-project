import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../presentation/widgets/camera_view.dart';
import '../presentation/widgets/scanner_controls.dart';
import 'dart:io';

class ImageCaptureView extends StatefulWidget {
  final Function(XFile) onImageCaptured;

  const ImageCaptureView({super.key, required this.onImageCaptured});

  @override
  State<ImageCaptureView> createState() => _ImageCaptureViewState();
}

class _ImageCaptureViewState extends State<ImageCaptureView> {
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isAutoCapture = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CameraView(
          onImage: (inputImage) async {
            // Logic for auto-capture would go here using ObjectDetector
            // For now we just implement manual capture via button
          },
        ),

        // Controls
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: MicroToolbar(
              isFlashOn: _isFlashOn,
              onToggleFlash: () => setState(() => _isFlashOn = !_isFlashOn),
              isAutoCapture: _isAutoCapture,
              onToggleAuto: () =>
                  setState(() => _isAutoCapture = !_isAutoCapture),
            ),
          ),
        ),

        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: ShutterButton(
              isProcessing: _isProcessing,
              onTap: _capturePhoto,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Use ImagePicker for reliable capture/selection across platforms
      final ImagePicker picker = ImagePicker();
      // Prefer camera, fallback to gallery if needed or let user choose logic could be added
      // For "Capture" context, Camera is primary.
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        widget.onImageCaptured(image);
      } else {
        // User cancelled, maybe try gallery?
        // keeping mostly silent or showing message
        // For desktop where camera might not be available directly in all emulators:
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          // Fallback to gallery/filesystem for desktop if camera returned null/unsupported
          // (Though pickImage(camera) might just throw or do nothing on some desktop impls)
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      // Fallback to gallery on error (e.g. no camera)
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          widget.onImageCaptured(image);
        }
      } catch (e2) {
        debugPrint('Error picking image: $e2');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
