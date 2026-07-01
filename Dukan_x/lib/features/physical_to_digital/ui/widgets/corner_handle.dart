// Corner Handle Widget
//
// Draggable corner handle for manual crop adjustment.
// Neon-styled with touch feedback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/p2d_theme.dart';

class CornerHandle extends StatefulWidget {
  final Offset position;
  final ValueChanged<Offset> onPositionChanged;
  final double size;
  final Color? color;

  const CornerHandle({
    super.key,
    required this.position,
    required this.onPositionChanged,
    this.size = 24,
    this.color,
  });

  @override
  State<CornerHandle> createState() => _CornerHandleState();
}

class _CornerHandleState extends State<CornerHandle> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final handleColor = widget.color ?? kP2DAccentCyan;

    return Positioned(
      left: widget.position.dx - widget.size / 2,
      top: widget.position.dy - widget.size / 2,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
          HapticFeedback.selectionClick();
        },
        onPanUpdate: (details) {
          widget.onPositionChanged(widget.position + details.delta);
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: kP2DAnimationFast,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isDragging
                ? handleColor.withOpacity(0.3)
                : handleColor.withOpacity(0.2),
            border: Border.all(color: handleColor, width: _isDragging ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: handleColor.withOpacity(_isDragging ? 0.6 : 0.3),
                blurRadius: _isDragging ? 16 : 10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: handleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Crop overlay that shows the document boundary with handles
class CropOverlay extends StatelessWidget {
  final List<Offset> corners;
  final ValueChanged<int>? onCornerDrag;
  final Function(int, Offset)? onCornerPositionChanged;

  const CropOverlay({
    super.key,
    required this.corners,
    this.onCornerDrag,
    this.onCornerPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CropLinePainter(corners: corners),
      size: Size.infinite,
    );
  }
}

class _CropLinePainter extends CustomPainter {
  final List<Offset> corners;

  _CropLinePainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Semi-transparent overlay outside crop area
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // Create path for the entire canvas
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create path for the crop area
    final cropPath = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    // Combine paths to create overlay effect
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cropPath,
    );

    canvas.drawPath(combinedPath, overlayPaint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = kP2DAccentCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(cropPath, borderPaint);

    // Draw grid lines inside crop area
    _drawGridLines(canvas, corners);
  }

  void _drawGridLines(Canvas canvas, List<Offset> corners) {
    final gridPaint = Paint()
      ..color = kP2DAccentCyan.withOpacity(0.3)
      ..strokeWidth = 1;

    // Horizontal thirds
    for (int i = 1; i < 3; i++) {
      final t = i / 3;
      final left = Offset.lerp(corners[0], corners[3], t)!;
      final right = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(left, right, gridPaint);
    }

    // Vertical thirds
    for (int i = 1; i < 3; i++) {
      final t = i / 3;
      final top = Offset.lerp(corners[0], corners[1], t)!;
      final bottom = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(top, bottom, gridPaint);
    }
  }

  @override
  bool shouldRepaint(_CropLinePainter oldDelegate) {
    return corners != oldDelegate.corners;
  }
}
