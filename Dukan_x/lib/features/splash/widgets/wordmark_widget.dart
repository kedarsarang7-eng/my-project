import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WordmarkWidget extends StatelessWidget {
  const WordmarkWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      "Myvyaparmitra",
      style: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 42,
        color: const Color(0xFFF1F5F9),
      ),
    );
  }
}
