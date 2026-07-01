import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaglineWidget extends StatelessWidget {
  final Animation<double> animation;

  const TaglineWidget({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final text = "VYAPAR KA NAYA ANDAAZ";
    final characters = text.split('');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(characters.length, (index) {
        // Stagger 40ms each. The whole animation is 600ms (3000ms to 3600ms).
        // Max stagger delay = index * (40 / 600).
        final delay = index * (40 / 600);
        final charDuration = 0.2; // 20% of the total 600ms to fade in
        
        final charAnim = CurvedAnimation(
          parent: animation,
          curve: Interval(
            delay.clamp(0.0, 1.0),
            (delay + charDuration).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        );

        return FadeTransition(
          opacity: charAnim,
          child: Text(
            characters[index],
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w300,
              fontSize: 16,
              letterSpacing: 3.0,
              color: const Color(0xFF64748B),
            ),
          ),
        );
      }),
    );
  }
}
