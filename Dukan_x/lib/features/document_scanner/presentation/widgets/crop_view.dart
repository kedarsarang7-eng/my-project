import 'dart:io';
import 'package:flutter/material.dart';

// Minimal implementation of a manual cropper using 4 points overlay
// For production, this would use a more sophisticated gesture handler
// with magnifiers (like 'image_cropper' plugin but custom UI)
class CropView extends StatefulWidget {
  final File imageFile;
  final Function(List<Offset>) onCropConfirmed;

  const CropView({
    super.key,
    required this.imageFile,
    required this.onCropConfirmed,
  });

  @override
  State<CropView> createState() => _CropViewState();
}

class _CropViewState extends State<CropView> {
  // Normalized 0..1 coordinates
  List<Offset> _corners = [
    const Offset(0.1, 0.1), // TL
    const Offset(0.9, 0.1), // TR
    const Offset(0.9, 0.9), // BR
    const Offset(0.1, 0.9), // BL
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.contain),

                  // Valid for MVP: Simple draggable corners
                  // Use CustomPaint for connecting lines
                  CustomPaint(
                    painter: _CropPainter(_corners),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),

                  // Interactive Handles
                  ..._corners.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final pt = entry.value;

                    return Positioned(
                      left: pt.dx * constraints.maxWidth - 20,
                      top: pt.dy * constraints.maxHeight - 20,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            double nx =
                                (pt.dx * constraints.maxWidth +
                                    details.delta.dx) /
                                constraints.maxWidth;
                            double ny =
                                (pt.dy * constraints.maxHeight +
                                    details.delta.dy) /
                                constraints.maxHeight;
                            // Clamp
                            nx = nx.clamp(0.0, 1.0);
                            ny = ny.clamp(0.0, 1.0);

                            _corners[idx] = Offset(nx, ny);
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.crop_free,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),

        // Confirmation toolbar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  // Reset
                  setState(() {
                    _corners = [
                      const Offset(0.1, 0.1),
                      const Offset(0.9, 0.1),
                      const Offset(0.9, 0.9),
                      const Offset(0.1, 0.9),
                    ];
                  });
                },
                child: const Text(
                  "Reset",
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text("Confirm Crop"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => widget.onCropConfirmed(_corners),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CropPainter extends CustomPainter {
  final List<Offset> points;
  _CropPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (points.length == 4) {
      // Convert normalized to pixels
      final p0 = Offset(points[0].dx * size.width, points[0].dy * size.height);
      final p1 = Offset(points[1].dx * size.width, points[1].dy * size.height);
      final p2 = Offset(points[2].dx * size.width, points[2].dy * size.height);
      final p3 = Offset(points[3].dx * size.width, points[3].dy * size.height);

      path.moveTo(p0.dx, p0.dy);
      path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.close();
    }

    canvas.drawPath(path, paint);

    // Draw semi-transparent fill
    paint.style = PaintingStyle.fill;
    paint.color = Colors.cyan.withOpacity(0.1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
