import 'package:flutter/material.dart';

class ProgressBarWidget extends StatelessWidget {
  final bool isVisible;

  const ProgressBarWidget({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: const LinearProgressIndicator(
        color: Color(0xFF2563EB),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
