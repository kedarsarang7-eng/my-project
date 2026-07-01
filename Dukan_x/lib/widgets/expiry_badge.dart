import 'package:flutter/material.dart';

/// ExpiryBadge — Visual indicator for product expiry status.
/// Shows different colors and labels based on days until expiry:
///   - 🔴 Red: Expired (daysRemaining < 0)
///   - 🟠 Orange pulse: Expiring within 7 days
///   - 🟡 Yellow: Expiring within 30 days
///   - 🟢 Green: Safe (> 30 days)
///
/// Usage:
///   ExpiryBadge(expiryDate: product.expiryDate)
///   ExpiryBadge(daysRemaining: 5)
///   ExpiryBadge.compact(daysRemaining: -1)  // small dot indicator
class ExpiryBadge extends StatelessWidget {
  final DateTime? expiryDate;
  final int? daysRemaining;
  final bool compact;
  final bool showLabel;

  const ExpiryBadge({
    super.key,
    this.expiryDate,
    this.daysRemaining,
    this.compact = false,
    this.showLabel = true,
  });

  /// Compact dot-only indicator (no text)
  const ExpiryBadge.compact({
    super.key,
    this.expiryDate,
    this.daysRemaining,
  })  : compact = true,
        showLabel = false;

  int get _daysRemaining {
    if (daysRemaining != null) return daysRemaining!;
    if (expiryDate == null) return 999; // No expiry = safe
    final now = DateTime.now();
    final expiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return expiry.difference(today).inDays;
  }

  Color get _color {
    final days = _daysRemaining;
    if (days < 0) return const Color(0xFFEF4444); // Red — expired
    if (days <= 7) return const Color(0xFFF97316); // Orange — urgent
    if (days <= 30) return const Color(0xFFEAB308); // Yellow — warning
    return const Color(0xFF22C55E); // Green — safe
  }

  Color get _bgColor {
    final days = _daysRemaining;
    if (days < 0) return const Color(0x20EF4444);
    if (days <= 7) return const Color(0x20F97316);
    if (days <= 30) return const Color(0x20EAB308);
    return const Color(0x2022C55E);
  }

  String get _label {
    final days = _daysRemaining;
    if (days < 0) return 'EXPIRED';
    if (days == 0) return 'TODAY';
    if (days <= 7) return '${days}d left';
    if (days <= 30) return '${days}d';
    return 'OK';
  }

  IconData get _icon {
    final days = _daysRemaining;
    if (days < 0) return Icons.dangerous_rounded;
    if (days <= 7) return Icons.warning_amber_rounded;
    if (days <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (expiryDate == null && daysRemaining == null) {
      return const SizedBox.shrink(); // No expiry info — hide badge
    }

    if (compact) {
      return _buildCompactDot();
    }

    return _buildFullBadge();
  }

  Widget _buildCompactDot() {
    final days = _daysRemaining;
    final shouldPulse = days >= 0 && days <= 7;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: shouldPulse
            ? [BoxShadow(color: _color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
    );
  }

  Widget _buildFullBadge() {
    final days = _daysRemaining;
    final isUrgent = days <= 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.w500,
                color: _color,
                letterSpacing: isUrgent ? 0.5 : 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
