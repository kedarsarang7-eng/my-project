/// MobileShop Status Card — Interactive/Non-Interactive Status Display (Dart)
///
/// Provides [MobileShopStatusCard] with explicit interactive or non-interactive
/// semantics. Interactive cards apply represented tenant-scoped filters;
/// non-interactive cards expose semantic state without an InkWell.
///
/// Fixes AF-47: status cards with empty onTap replaced with functional
/// filter navigation or non-interactive semantics.
///
/// Requirements: 5.10, 5.11, 11.12
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Status Card Action ──────────────────────────────────────────────────────

/// Defines an action for an interactive status card.
///
/// When non-null, the card is interactive and navigates to [routePath]
/// with [queryParams] applied as the exact filter.
class MobileShopStatusCardAction {
  /// The route path to navigate to (e.g., '/mobile-shop/service-jobs').
  final String routePath;

  /// Query parameters representing the exact filter to apply
  /// (e.g., {'status': 'overdue'}).
  final Map<String, String> queryParams;

  const MobileShopStatusCardAction({
    required this.routePath,
    this.queryParams = const {},
  });

  /// Named constructor for clarity.
  const MobileShopStatusCardAction.filterAction({
    required this.routePath,
    required this.queryParams,
  });
}

// ─── Status Card Widget ──────────────────────────────────────────────────────

/// A status card that is either interactive (navigates to a filtered view)
/// or non-interactive (exposes semantic state only).
///
/// When [action] is non-null:
/// - Wrapped in InkWell with proper semantics
/// - onTap navigates to the exact filtered view
/// - Accessible: tap hint, button role
///
/// When [action] is null:
/// - No InkWell, no tap handler
/// - Semantics: 'Status: $title is $value'
/// - Non-interactive visual treatment
class MobileShopStatusCard extends StatelessWidget {
  /// The title label for the status metric (e.g., "Overdue Repairs").
  final String title;

  /// The display value (e.g., "12", "₹45,000").
  final String value;

  /// The leading icon for the card.
  final IconData icon;

  /// Optional action. If non-null, the card is interactive and navigates
  /// to the specified route with query params. If null, the card is
  /// non-interactive with semantic-only state.
  final MobileShopStatusCardAction? action;

  /// Optional icon color override.
  final Color? iconColor;

  const MobileShopStatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = action != null;

    final cardContent = _buildCardContent(context, theme);

    if (isInteractive) {
      return Semantics(
        button: true,
        label: '$title: $value. Tap to view details.',
        child: InkWell(
          onTap: () => _navigateToFilter(context),
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }

    // Non-interactive: expose semantic state without InkWell
    return Semantics(label: 'Status: $title is $value', child: cardContent);
  }

  /// Builds the visual card content (shared between interactive and
  /// non-interactive variants).
  Widget _buildCardContent(BuildContext context, ThemeData theme) {
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return Card(
      elevation: action != null ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: action == null
            ? BorderSide(color: theme.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: effectiveIconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  /// Navigates to the filtered view using GoRouter.
  void _navigateToFilter(BuildContext context) {
    final cardAction = action!;
    final uri = Uri(
      path: cardAction.routePath,
      queryParameters: cardAction.queryParams.isNotEmpty
          ? cardAction.queryParams
          : null,
    );
    GoRouter.of(context).go(uri.toString());
  }
}
