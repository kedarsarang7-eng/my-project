import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';

class CreditScoreWidget extends StatelessWidget {
  final double score;
  final bool isLoading;

  const CreditScoreWidget({
    super.key,
    required this.score,
    this.isLoading = false,
  });

  Color _getScoreColor(double score) {
    if (score >= 80) return FuturisticColors.success;
    if (score >= 50) return FuturisticColors.warning;
    return FuturisticColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final color = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'Trust Score: ${score.round()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
