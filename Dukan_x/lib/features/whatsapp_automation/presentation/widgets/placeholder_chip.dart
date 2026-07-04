// ============================================================================
// PlaceholderChip Widget — Renders template placeholders as styled chips
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Renders a single template placeholder as a styled chip.
class PlaceholderChip extends StatelessWidget {
  final String placeholder;

  const PlaceholderChip({super.key, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      decoration: BoxDecoration(
        color: FuturisticColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FuturisticColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.data_object, size: 12, color: FuturisticColors.primary),
          const SizedBox(width: 3),
          Text(
            '{{$placeholder}}',
            style: TextStyle(
              color: FuturisticColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a row of placeholder chips from a list.
class PlaceholderChipRow extends StatelessWidget {
  final List<String> placeholders;

  const PlaceholderChipRow({super.key, required this.placeholders});

  @override
  Widget build(BuildContext context) {
    if (placeholders.isEmpty) {
      return Text(
        'No placeholders',
        style: TextStyle(
          color: FuturisticColors.textMuted,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      children: placeholders
          .map((p) => PlaceholderChip(placeholder: p))
          .toList(),
    );
  }
}
