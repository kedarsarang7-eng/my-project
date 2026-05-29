// ============================================================================
// ID CARD SCANNER SCREEN - Staff Mobile App
// ============================================================================
// Purpose: Staff scans their ID card to start shift
// Features:
//   - Full-screen camera with animated scanning frame
//   - ML Kit OCR for real-time text recognition
//   - Success state with staff photo and confirmation
//   - Manual ID entry fallback
//   - Error handling for blur/bad lighting
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../services/attendance_service.dart';
import '../bloc/id_scanner_bloc.dart';
import '../bloc/id_scanner_event.dart';
import '../bloc/id_scanner_state.dart';

/// ID Card Scanner Screen
/// 
/// Staff scans their ID card to check in and start their shift.
/// Uses ML Kit OCR to extract staff ID from the card.
class IDCardScannerScreen extends StatelessWidget {
  const IDCardScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => IDScannerBloc(
        attendanceService: context.read<AttendanceService>(),
      ),
      child: const _IDCardScannerView(),
    );
  }
}

class _IDCardScannerView extends StatefulWidget {
  const _IDCardScannerView();

  @override
  State<_IDCardScannerView> createState() => _IDCardScannerViewState();
}

class _IDCardScannerViewState extends State<_IDCardScannerView>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  
  late AnimationController _frameAnimationController;
  late AnimationController _pulseAnimationController;
  
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isScanning = true;
  

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer();
    
    _frameAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _frameAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        context.read<IDScannerBloc>().add(const CameraError('No cameras available'));
        return;
      }

      // Use back camera for ID scanning
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startImageStream();
      }
    } catch (e) {
      context.read<IDScannerBloc>().add(CameraError(e.toString()));
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) {
      if (!_isProcessingFrame && _isScanning) {
        _processFrame(image);
      }
    });
  }

  /// Staff ID pattern: PP-YYYY-NNNN  (case-insensitive, flexible separator)
  static final _staffIdPattern = RegExp(
    r'\bPP[-\s]?\d{4}[-\s]?\d{4}\b',
    caseSensitive: false,
  );

  Future<void> _processFrame(CameraImage image) async {
    _isProcessingFrame = true;

    try {
      // Throttle to avoid overwhelming ML Kit on low-end devices.
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isScanning || !mounted) return;

      // ── Build InputImage from CameraImage ────────────────────────────────
      // ML Kit requires either a file path or raw bytes + metadata.
      // We use the raw-bytes path so no temp file I/O is needed.
      final InputImage inputImage;

      if (image.planes.isEmpty) return;

      if (Platform.isAndroid) {
        // Android streams NV21 (YUV420) — planes[0] is Y, planes[1] is VU.
        // Concatenate all plane bytes for the InputImageByteData path.
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      } else {
        // iOS streams BGRA8888 — single plane.
        inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }

      // ── Run OCR ──────────────────────────────────────────────────────────
      final recognized = await _textRecognizer.processImage(inputImage);

      // ── Extract staff ID ─────────────────────────────────────────────────
      // Collect all text from every block/line/element into one string
      // so the regex can match across word boundaries.
      final allText = recognized.blocks
          .expand((b) => b.lines)
          .expand((l) => l.elements)
          .map((e) => e.text)
          .join(' ');

      final match = _staffIdPattern.firstMatch(allText);
      if (match != null && mounted && _isScanning) {
        // Normalise to canonical PP-YYYY-NNNN format.
        final raw = match.group(0)!.replaceAll(RegExp(r'[\s]'), '-').toUpperCase();
        setState(() => _isScanning = false);
        // ignore: use_build_context_synchronously
        context.read<IDScannerBloc>().add(IDDetected(extractedId: raw, confidence: 1.0));
      }
    } catch (e) {
      // Non-fatal — next frame will retry automatically.
      debugPrint('OCR frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _retryScan() {
    setState(() => _isScanning = true);
    context.read<IDScannerBloc>().add(const RetryScan());
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualEntrySheet(
        onSubmit: (staffId) {
          Navigator.pop(context);
          // Validate staff ID manually
          context.read<IDScannerBloc>().add(
            ManualIdEntered(staffId: staffId),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IDScannerBloc, IDScannerState>(
      listener: (context, state) {
        if (state is StaffFound || state is ProcessingShift) {
          // Stop the image stream while confirmation / processing is shown
          // to avoid wasted CPU and spurious re-detections.
          if (_isScanning) setState(() => _isScanning = false);
        }

        if (state is ScanError) {
          // Resume scanning so the user can try again without tapping retry.
          if (!_isScanning) setState(() => _isScanning = true);

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.actionHint),
                backgroundColor: Colors.red[700],
                duration: Duration(
                  seconds: state.isRetryable ? 4 : 6,
                ),
                action: state.isRetryable
                    ? SnackBarAction(
                        label: 'RETRY',
                        textColor: Colors.white,
                        onPressed: _retryScan,
                      )
                    : null,
              ),
            );
        }

        if (state is ShiftStarted) {
          // Navigate to active shift dashboard
          Navigator.pushReplacementNamed(
            context,
            '/active-shift',
            arguments: {
              'shiftId': state.shiftId,
              'checkInTime': state.checkInTime,
            },
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Camera Preview
              if (_isCameraInitialized && _cameraController != null)
                CameraPreview(_cameraController!)
              else
                const _CameraPlaceholder(),

              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),

              // Scanning Frame (only when scanning)
              if (_isScanning && state is! StaffFound)
                _ScanningFrame(
                  frameAnimation: _frameAnimationController,
                  pulseAnimation: _pulseAnimationController,
                ),

              // UI Content based on state
              if (state is ScanningIdle || state is ScanningActive)
                _ScanningUI(
                  onManualEntry: _showManualEntry,
                )
              else if (state is StaffFound)
                _StaffConfirmationUI(
                  staffName: state.staffName,
                  staffId: state.staffId,
                  photoUrl: state.photoUrl,
                  onConfirm: () {
                    context.read<IDScannerBloc>().add(
                      const ConfirmShiftStart(),
                    );
                  },
                  onRetry: _retryScan,
                )
              else if (state is ProcessingShift)
                const _ProcessingUI(),

              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// SCANNING FRAME WIDGET
// ============================================================================

class _ScanningFrame extends StatelessWidget {
  final AnimationController frameAnimation;
  final AnimationController pulseAnimation;

  const _ScanningFrame({
    required this.frameAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([frameAnimation, pulseAnimation]),
        builder: (context, child) {
          return Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.green.withValues(alpha: 
                  0.5 + (pulseAnimation.value * 0.5),
                ),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Corner brackets
                Positioned(
                  top: 0,
                  left: 0,
                  child: _CornerBracket(
                    rotation: 0,
                    opacity: frameAnimation.value < 0.25 ? 1.0 : 0.3,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _CornerBracket(
                    rotation: 90,
                    opacity: frameAnimation.value >= 0.25 && frameAnimation.value < 0.5 ? 1.0 : 0.3,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _CornerBracket(
                    rotation: 180,
                    opacity: frameAnimation.value >= 0.5 && frameAnimation.value < 0.75 ? 1.0 : 0.3,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _CornerBracket(
                    rotation: 270,
                    opacity: frameAnimation.value >= 0.75 ? 1.0 : 0.3,
                  ),
                ),
                // Scanning line
                Positioned(
                  top: frameAnimation.value * 180,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.green.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final double rotation;
  final double opacity;

  const _CornerBracket({required this.rotation, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.green, width: 3),
              left: BorderSide(color: Colors.green, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCANNING UI
// ============================================================================

class _ScanningUI extends StatelessWidget {
  final VoidCallback onManualEntry;

  const _ScanningUI({required this.onManualEntry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 100),
          // Title
          Text(
            'Scan Your ID Card',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Align card within the frame',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const Spacer(),
          // Instructions
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInstruction(Icons.credit_card, 'Hold card steady'),
                const SizedBox(height: 8),
                _buildInstruction(Icons.lightbulb_outline, 'Ensure good lighting'),
                const SizedBox(height: 8),
                _buildInstruction(Icons.center_focus_strong, 'Keep card in frame'),
              ],
            ),
          ),
          // Manual entry button
          TextButton(
            onPressed: onManualEntry,
            child: Text(
              'Enter ID Manually',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInstruction(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

// ============================================================================
// STAFF CONFIRMATION UI
// ============================================================================

class _StaffConfirmationUI extends StatelessWidget {
  final String staffName;
  final String staffId;
  final String? photoUrl;
  final VoidCallback onConfirm;
  final VoidCallback onRetry;

  const _StaffConfirmationUI({
    required this.staffName,
    required this.staffId,
    this.photoUrl,
    required this.onConfirm,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            // Staff info
            if (photoUrl != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(photoUrl!),
              )
            else
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey,
                child: Text(
                  staffName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              staffName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $staffId',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now()),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Start Shift',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROCESSING UI
// ============================================================================

class _ProcessingUI extends StatelessWidget {
  const _ProcessingUI();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 24),
            Text(
              'Starting your shift...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CAMERA PLACEHOLDER
// ============================================================================

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MANUAL ENTRY SHEET
// ============================================================================

class _ManualEntrySheet extends StatefulWidget {
  final Function(String) onSubmit;

  const _ManualEntrySheet({required this.onSubmit});

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _controller = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter Staff ID',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your Staff ID and PIN to start shift',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Staff ID',
              hintText: 'e.g., PP-2024-0042',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            decoration: InputDecoration(
              labelText: 'PIN',
              hintText: 'Enter 4-digit PIN',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty && _pinController.text.length == 4) {
                  widget.onSubmit(_controller.text.toUpperCase());
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
