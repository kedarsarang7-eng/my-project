// Physical → Digital Camera Screen
//
// Fullscreen live camera with AI document detection.
// Futuristic glassmorphism UI with minimal floating controls.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../theme/p2d_theme.dart';
import '../widgets/widgets.dart';
import '../../logic/document_detector.dart';
import 'p2d_crop_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class P2DCameraScreen extends StatefulWidget {
  const P2DCameraScreen({super.key});

  @override
  State<P2DCameraScreen> createState() => _P2DCameraScreenState();
}

class _P2DCameraScreenState extends State<P2DCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _flashOn = false;
  bool _autoMode = true;

  // Detection state
  List<Offset>? _detectedCorners;
  bool _isDocumentStable = false;
  int _stableFrameCount = 0;
  static const int _requiredStableFrames = 10;

  // Document detector
  late DocumentDetector _detector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = DocumentDetector();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startImageStream() {
    if (_controller == null) return;

    _controller!.startImageStream((image) async {
      if (_isProcessing || !_autoMode) return;
      _isProcessing = true;

      try {
        final corners = await _detector.detectDocument(image);

        if (mounted) {
          setState(() {
            if (corners != null) {
              // Normalize corners to 0-1 range
              final width = image.width.toDouble();
              final height = image.height.toDouble();
              _detectedCorners = corners
                  .map((c) => Offset(c.dx / width, c.dy / height))
                  .toList();

              // Check stability
              _stableFrameCount++;
              if (_stableFrameCount >= _requiredStableFrames) {
                _isDocumentStable = true;
                if (_autoMode) {
                  _captureDocument();
                }
              }
            } else {
              _detectedCorners = null;
              _isDocumentStable = false;
              _stableFrameCount = 0;
            }
          });
        }
      } catch (e) {
        debugPrint('Detection error: $e');
      }

      _isProcessing = false;
    });
  }

  Future<void> _captureDocument() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop stream before capture
      await _controller!.stopImageStream();

      HapticFeedback.heavyImpact();

      final file = await _controller!.takePicture();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => P2DCropScreen(
              imagePath: file.path,
              initialCorners: _detectedCorners,
            ),
          ),
        ).then((_) {
          // Restart stream when returning
          if (mounted && _controller != null) {
            _startImageStream();
          }
        });
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      // Restart stream on error
      if (mounted) _startImageStream();
    }
  }

  void _toggleFlash() {
    if (_controller == null) return;

    setState(() => _flashOn = !_flashOn);
    _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    HapticFeedback.lightImpact();
  }

  void _toggleAutoMode() {
    setState(() {
      _autoMode = !_autoMode;
      if (!_autoMode) {
        _isDocumentStable = false;
        _stableFrameCount = 0;
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kP2DBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: kP2DAccentCyan),
            ),

          // Scan overlay
          ScanOverlay(corners: _detectedCorners, isStable: _isDocumentStable),

          // Top status bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: DetectionStatusIndicator(
                isDetected: _detectedCorners != null,
                isStable: _isDocumentStable,
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Capture button
                CaptureButton(
                  onTap: _captureDocument,
                  isReady: _isDocumentStable,
                ),
                const SizedBox(height: 24),

                // Control bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flash toggle
                      NeonButton(
                        icon: _flashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleFlash,
                        isActive: _flashOn,
                        tooltip: 'Flash',
                      ),

                      // Auto mode toggle
                      NeonButton(
                        icon: Icons.auto_awesome_rounded,
                        onTap: _toggleAutoMode,
                        isActive: _autoMode,
                        tooltip: _autoMode ? 'Auto Capture' : 'Manual',
                        color: kP2DAccentPurple,
                      ),

                      // Settings
                      NeonButton(
                        icon: Icons.tune_rounded,
                        onTap: () {
                          if (context.isDesktop || context.isTablet) {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
                                  child: const _CameraSettingsContent(),
                                ),
                              ),
                            );
                          } else {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.black87,
                              builder: (context) => const _CameraSettingsContent(),
                            );
                          }
                        },
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: NeonButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraSettingsContent extends StatelessWidget {
  const _CameraSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: Column(
        children: [
          const Text(
            'Camera Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(
              Icons.grid_on,
              color: Colors.white,
            ),
            title: const Text(
              'Show Grid',
              style: TextStyle(color: Colors.white),
            ),
            trailing: Switch(
              value: false,
              onChanged: (v) {},
            ),
          ),
        ],
      ),
    );
  }
}
