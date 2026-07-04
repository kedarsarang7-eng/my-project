// ============================================================================
// ConsentBadge Widget — Shows opted_in/opted_out/pending consent state
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/models/whatsapp_customer_model.dart';

/// Colored badge showing customer consent state.
class ConsentBadge extends StatelessWidget {
  final ConsentState consentState;

  const ConsentBadge({super.key, required this.consentState});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (consentState) {
      ConsentState.optedIn => (FuturisticColors.success, 'Opted In'),
      ConsentState.optedOut => (FuturisticColors.error, 'Opted Out'),
      ConsentState.pending => (FuturisticColors.warning, 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
