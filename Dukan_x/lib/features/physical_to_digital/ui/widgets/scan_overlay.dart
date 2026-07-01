// Scan Overlay Widget
//
// CustomPainter-based overlay for document detection visualization.
// Shows glowing document outline with animated pulse effect.

import 'package:flutter/material.dart';
import '../theme/p2d_theme.dart';

class ScanOverlay extends StatefulWidget {
  /// Detected document corners (normalized 0-1 coordinates)
  /// Order: top-left, top-right, bottom-right, bottom-left
  final List<Offset>? corners;

  /// Whether document is stable and ready for capture
  final bool isStable;

  /// Show subtle grid pattern
  final bool showGrid;

  const ScanOverlay({
    super.key,
    this.corners,
    this.isStable = false,
    this.showGrid = true,
  });

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanOverlayPainter(
            corners: widget.corners,
            isStable: widget.isStable,
            showGrid: widget.showGrid,
            pulseValue: _pulseController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final List<Offset>? corners;
  final bool isStable;
  final bool showGrid;
  final double pulseValue;

  _ScanOverlayPainter({
    this.corners,
    this.isStable = false,
    this.showGrid = true,
    this.pulseValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle grid
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Draw document outline if detected
    if (corners != null && corners!.length == 4) {
      _drawDocumentOutline(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kP2DAccentCyan.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const gridSpacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDocumentOutline(Canvas canvas, Size size) {
    final scaledCorners = corners!.map((c) {
      return Offset(c.dx * size.width, c.dy * size.height);
    }).toList();

    final outlineColor = isStable ? kP2DGlowSuccess : kP2DAccentCyan;
    final glowOpacity = 0.3 + (pulseValue * 0.4);
    final strokeWidth = isStable ? 3.0 : 2.0;

    // Glow effect (multiple strokes with decreasing opacity)
    for (int i = 3; i >= 0; i--) {
      final glowPaint = Paint()
        ..color = outlineColor.withOpacity(glowOpacity * (1 - i * 0.2))
        ..strokeWidth = strokeWidth + (i * 4)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      _drawPath(canvas, scaledCorners, glowPaint);
    }

    // Main outline
    final outlinePaint = Paint()
      ..color = outlineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawPath(canvas, scaledCorners, outlinePaint);

    // Corner dots
    final dotPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.fill;

    for (final corner in scaledCorners) {
      canvas.drawCircle(corner, isStable ? 8 : 6, dotPaint);
    }
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter oldDelegate) {
    return corners != oldDelegate.corners ||
        isStable != oldDelegate.isStable ||
        showGrid != oldDelegate.showGrid ||
        pulseValue != oldDelegate.pulseValue;
  }
}

/// Status indicator showing detection state
class DetectionStatusIndicator extends StatelessWidget {
  final bool isDetected;
  final bool isStable;

  const DetectionStatusIndicator({
    super.key,
    this.isDetected = false,
    this.isStable = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStable
        ? kP2DGlowSuccess
        : isDetected
        ? kP2DAccentCyan
        : kP2DTextMuted;

    final text = isStable
        ? 'Ready'
        : isDetected
        ? 'Hold steady...'
        : 'Searching...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kP2DGlassSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [kP2DNeonGlow(color, blur: 8)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
