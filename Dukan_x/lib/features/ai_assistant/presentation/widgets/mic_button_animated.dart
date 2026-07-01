import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';

class MicButtonAnimated extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  final Color glowColor;
  final bool isEnabled;

  const MicButtonAnimated({
    super.key,
    required this.isListening,
    required this.onTap,
    this.glowColor = Colors.pinkAccent,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      animate: isListening && isEnabled,
      glowColor: glowColor,
      duration: const Duration(milliseconds: 2000),
      repeat: true,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: glowColor.withOpacity(0.5), width: 2),
              gradient: LinearGradient(
                colors: [
                  glowColor.withOpacity(0.2),
                  glowColor.withOpacity(0.0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: glowColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
