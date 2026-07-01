import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

enum BadgeStatus {
  success,
  warning,
  error,
  info,
  neutral,
  paid,
  unpaid,
  overdue,
  pending,
}

/// Premium Status Badge
///
/// A futuristic status badge with:
/// - Neon glow effect
/// - Multiple status types
/// - Optional outline variant
/// - Dot indicator option
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus type;
  final bool outline;
  final bool showDot;
  final bool glow;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeStatus.neutral,
    this.outline = false,
    this.showDot = false,
    this.glow = false,
  });

  /// Convenience constructors for common statuses
  const StatusBadge.paid({super.key, this.label = 'Paid'})
    : type = BadgeStatus.paid,
      outline = false,
      showDot = true,
      glow = true;

  const StatusBadge.unpaid({super.key, this.label = 'Unpaid'})
    : type = BadgeStatus.unpaid,
      outline = false,
      showDot = true,
      glow = false;

  const StatusBadge.overdue({super.key, this.label = 'Overdue'})
    : type = BadgeStatus.overdue,
      outline = false,
      showDot = true,
      glow = true;

  const StatusBadge.pending({super.key, this.label = 'Pending'})
    : type = BadgeStatus.pending,
      outline = false,
      showDot = true,
      glow = false;

  Color _getColor() {
    switch (type) {
      case BadgeStatus.success:
      case BadgeStatus.paid:
        return FuturisticColors.success;
      case BadgeStatus.warning:
      case BadgeStatus.pending:
        return FuturisticColors.warning;
      case BadgeStatus.error:
      case BadgeStatus.unpaid:
        return FuturisticColors.error;
      case BadgeStatus.overdue:
        return const Color(0xFFDC2626); // Deeper red
      case BadgeStatus.info:
        return FuturisticColors.premiumBlue;
      case BadgeStatus.neutral:
        return FuturisticColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(outline ? 0.8 : 0.3),
          width: 1,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status from string helper
StatusBadge statusBadgeFromString(String status) {
  switch (status.toLowerCase()) {
    case 'paid':
      return const StatusBadge.paid();
    case 'unpaid':
      return const StatusBadge.unpaid();
    case 'overdue':
      return const StatusBadge.overdue();
    case 'pending':
      return const StatusBadge.pending();
    case 'partial':
      return const StatusBadge(
        label: 'Partial',
        type: BadgeStatus.warning,
        showDot: true,
      );
    case 'sent':
      return const StatusBadge(
        label: 'Sent',
        type: BadgeStatus.info,
        showDot: true,
      );
    case 'draft':
      return const StatusBadge(
        label: 'Draft',
        type: BadgeStatus.neutral,
        showDot: true,
      );
    default:
      return StatusBadge(label: status, type: BadgeStatus.neutral);
  }
}
