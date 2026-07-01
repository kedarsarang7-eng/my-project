// Crop Screen
//
// Manual crop adjustment with draggable corner handles.
// Perspective correction preview.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/p2d_theme.dart';
import '../widgets/widgets.dart';
import '../../logic/perspective_transformer.dart';
import 'p2d_filter_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class P2DCropScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset>? initialCorners;

  const P2DCropScreen({
    super.key,
    required this.imagePath,
    this.initialCorners,
  });

  @override
  State<P2DCropScreen> createState() => _P2DCropScreenState();
}

class _P2DCropScreenState extends State<P2DCropScreen> {
  late List<Offset> _corners;
  bool _isProcessing = false;
  bool _autoEnhance = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    // Initialize corners (default to near edges if not provided)
    _corners =
        widget.initialCorners ??
        [
          const Offset(0.08, 0.08),
          const Offset(0.92, 0.08),
          const Offset(0.92, 0.92),
          const Offset(0.08, 0.92),
        ];
  }

  void _updateCorner(int index, Offset newPosition) {
    if (_imageSize == null) return;

    // Clamp to image bounds (normalized)
    final clampedX = newPosition.dx.clamp(0.0, 1.0);
    final clampedY = newPosition.dy.clamp(0.0, 1.0);

    setState(() {
      _corners[index] = Offset(clampedX, clampedY);
    });
  }

  Future<void> _confirmCrop() async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final imageBytes = await File(widget.imagePath).readAsBytes();

      // Apply perspective transformation
      final transformed = await PerspectiveTransformer.transform(
        imageBytes: imageBytes,
        corners: _corners,
      );

      if (transformed != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => P2DFilterScreen(
              imageBytes: transformed,
              autoEnhance: _autoEnhance,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Crop error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to process image')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kP2DBackground,
      body: Center(
        child: BoundedBox(
          maxWidth: 600,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with crop overlay
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) {
                      // Check which corner is being dragged
                      _handleDragUpdate(details, constraints.biggest);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        Image.file(File(widget.imagePath), fit: BoxFit.contain),

                        // Crop overlay
                        CustomPaint(
                          painter: _CropOverlayPainter(
                            corners: _corners,
                            imageSize: constraints.biggest,
                          ),
                          size: Size.infinite,
                        ),

                        // Corner handles
                        ..._buildCornerHandles(constraints.biggest),
                      ],
                    ),
                  );
                },
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeonButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Adjust Corners',
                        style: TextStyle(
                          color: kP2DTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      NeonButton(
                        icon: Icons.check_rounded,
                        onTap: _isProcessing ? () {} : _confirmCrop,
                        isActive: true,
                        color: kP2DGlowSuccess,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Auto enhance toggle
                      GestureDetector(
                        onTap: () {
                          setState(() => _autoEnhance = !_autoEnhance);
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: _autoEnhance
                                ? kP2DAccentCyan.withOpacity(0.2)
                                : kP2DGlassSurface,
                            border: Border.all(
                              color: _autoEnhance
                                  ? kP2DAccentCyan
                                  : kP2DGlassBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _autoEnhance
                                    ? Icons.auto_fix_high_rounded
                                    : Icons.auto_fix_off_rounded,
                                size: 18,
                                color: _autoEnhance
                                    ? kP2DAccentCyan
                                    : kP2DTextSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Auto Enhance',
                                style: TextStyle(
                                  color: _autoEnhance
                                      ? kP2DAccentCyan
                                      : kP2DTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading overlay
              if (_isProcessing)
                Container(
                  color: kP2DBackground.withOpacity(0.8),
                  child: const Center(
                    child: CircularProgressIndicator(color: kP2DAccentCyan),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerHandles(Size containerSize) {
    return List.generate(4, (index) {
      final corner = _corners[index];
      final position = Offset(
        corner.dx * containerSize.width,
        corner.dy * containerSize.height,
      );

      return CornerHandle(
        position: position,
        onPositionChanged: (newPos) {
          final normalized = Offset(
            newPos.dx / containerSize.width,
            newPos.dy / containerSize.height,
          );
          _updateCorner(index, normalized);
        },
      );
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, Size size) {
    // Find nearest corner and update
    final touchPoint = details.localPosition;
    final normalized = Offset(
      touchPoint.dx / size.width,
      touchPoint.dy / size.height,
    );

    double minDist = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < 4; i++) {
      final dist = (_corners[i] - normalized).distance;
      if (dist < minDist) {
        minDist = dist;
        nearestIndex = i;
      }
    }

    if (minDist < 0.15) {
      // Only if close enough
      _updateCorner(nearestIndex, normalized);
    }
  }
}

class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final Size imageSize;

  _CropOverlayPainter({required this.corners, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Scale corners to actual size
    final scaledCorners = corners
        .map((c) => Offset(c.dx * size.width, c.dy * size.height))
        .toList();

    // Dark overlay outside crop area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cropPath = Path()
      ..moveTo(scaledCorners[0].dx, scaledCorners[0].dy)
      ..lineTo(scaledCorners[1].dx, scaledCorners[1].dy)
      ..lineTo(scaledCorners[2].dx, scaledCorners[2].dy)
      ..lineTo(scaledCorners[3].dx, scaledCorners[3].dy)
      ..close();

    final combined = Path.combine(
      PathOperation.difference,
      overlayPath,
      cropPath,
    );

    canvas.drawPath(combined, Paint()..color = Colors.black.withOpacity(0.6));

    // Crop border with glow
    final borderPaint = Paint()
      ..color = kP2DAccentCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(cropPath, borderPaint);

    // Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = kP2DAccentCyan.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      final t = i / 3;
      // Horizontal
      final left = Offset.lerp(scaledCorners[0], scaledCorners[3], t)!;
      final right = Offset.lerp(scaledCorners[1], scaledCorners[2], t)!;
      canvas.drawLine(left, right, gridPaint);
      // Vertical
      final top = Offset.lerp(scaledCorners[0], scaledCorners[1], t)!;
      final bottom = Offset.lerp(scaledCorners[3], scaledCorners[2], t)!;
      canvas.drawLine(top, bottom, gridPaint);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return corners != oldDelegate.corners;
  }
}
