import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient blue = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF2979FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violet = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF6200EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emerald = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunset = LinearGradient(
    colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glass = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGlass = LinearGradient(
    colors: [Color(0x991E293B), Color(0xCC0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> neonBlue = [
    BoxShadow(
      color: const Color(0xFF2979FF).withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> neonGreen = [
    BoxShadow(
      color: const Color(0xFF00E676).withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
