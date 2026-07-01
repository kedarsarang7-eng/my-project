import 'package:flutter/material.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.blueAccent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0, // Handled by container
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
