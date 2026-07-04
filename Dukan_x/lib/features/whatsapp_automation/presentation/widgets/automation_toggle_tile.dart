// ============================================================================
// AutomationToggleTile Widget — List tile with enable/disable switch for rules
// ============================================================================
// Supports an explicit `unavailable` state for deferred/non-granted
// capabilities (Req 15.5): shows a disabled indicator instead of a toggle.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// A list tile with an enable/disable toggle switch.
///
/// When [unavailable] is true the tile renders an explicit "Unavailable"
/// indicator instead of the toggle, satisfying Req 15.5 (deferred capabilities
/// show an explicit unavailable state with no fabricated data).
class AutomationToggleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool enabled;
  final bool isLoading;

  /// When true, the capability is deferred or not granted for this business.
  /// An explicit "Unavailable" chip replaces the toggle (Req 15.5).
  final bool unavailable;

  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  const AutomationToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.enabled,
    this.isLoading = false,
    this.unavailable = false,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: unavailable ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          color: unavailable
              ? FuturisticColors.textMuted
              : FuturisticColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 12),
            )
          : null,
      trailing: _buildTrailing(),
    );
  }

  Widget _buildTrailing() {
    if (unavailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FuturisticColors.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: FuturisticColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 12, color: FuturisticColors.textMuted),
            const SizedBox(width: 4),
            Text(
              'UNAVAILABLE',
              style: TextStyle(
                color: FuturisticColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: FuturisticColors.primary,
        ),
      );
    }

    return Switch(
      value: enabled,
      onChanged: onToggle,
      activeColor: FuturisticColors.success,
      inactiveThumbColor: FuturisticColors.textMuted,
    );
  }
}
