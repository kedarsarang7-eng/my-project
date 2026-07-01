import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _PremiumLogoPainter(),
      ),
    );
  }
}

class _PremiumLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Cinematic abstract 'M' and 'V' integration for Myvyaparmitra
    
    // Left ribbon (Brand Blue)
    final path1 = Path()
      ..moveTo(size.width * 0.10, size.height * 0.90)
      ..lineTo(size.width * 0.35, size.height * 0.10)
      ..lineTo(size.width * 0.50, size.height * 0.45)
      ..lineTo(size.width * 0.30, size.height * 0.90)
      ..close();

    // Right ribbon (Brand Orange)
    final path2 = Path()
      ..moveTo(size.width * 0.90, size.height * 0.90)
      ..lineTo(size.width * 0.65, size.height * 0.10)
      ..lineTo(size.width * 0.50, size.height * 0.45)
      ..lineTo(size.width * 0.70, size.height * 0.90)
      ..close();
    
    // Gradient for path1 (Blue)
    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(path1.getBounds())
      ..style = PaintingStyle.fill;
      
    // Gradient for path2 (Orange)
    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFFDBA74)],
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
      ).createShader(path2.getBounds())
      ..style = PaintingStyle.fill;
      
    // Add glowing shadows
    canvas.drawShadow(path1, const Color(0xFF2563EB).withOpacity(0.6), 12, true);
    canvas.drawPath(path1, paint1);

    canvas.drawShadow(path2, const Color(0xFFF97316).withOpacity(0.6), 12, true);
    canvas.drawPath(path2, paint2);
    
    // Central glowing diamond connecting them (White/Silver)
    final centerPath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.20)
      ..lineTo(size.width * 0.68, size.height * 0.45)
      ..lineTo(size.width * 0.50, size.height * 0.70)
      ..lineTo(size.width * 0.32, size.height * 0.45)
      ..close();
      
    final paintCenter = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF8FAFC), Color(0xFF94A3B8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(centerPath.getBounds());
      
    canvas.drawShadow(centerPath, Colors.white.withOpacity(0.8), 16, true);
    canvas.drawPath(centerPath, paintCenter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
