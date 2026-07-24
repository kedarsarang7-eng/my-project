/// MobileShop Semantics Helper — Accessible Control Wrappers (Dart)
///
/// Provides helpers for ensuring all interactive mobile shop elements have
/// proper semantic names, roles, states, and 48x48dp minimum touch targets.
///
/// Every interactive control (card, scanner, status tile, icon) is wrapped
/// with appropriate Semantics labels and minimum tap target sizes.
///
/// Requirements: 11.3, 11.4, 11.7, 11.8
library;

import 'package:flutter/material.dart';

import 'mobile_shop_theme.dart';

// ─── Accessible Touch Target ─────────────────────────────────────────────────

/// Wraps a widget to guarantee the minimum 48x48dp touch target required
/// by WCAG 2.5.5 / Material guidelines.
///
/// If the child is smaller than 48dp in either dimension, transparent
/// padding is added to meet the minimum.
class AccessibleTouchTarget extends StatelessWidget {
  /// The interactive widget to wrap.
  final Widget child;

  /// Semantic label for the tap target.
  final String? semanticLabel;

  /// Minimum dimension (defaults to 48dp per WCAG).
  final double minSize;

  const AccessibleTouchTarget({
    super.key,
    required this.child,
    this.semanticLabel,
    this.minSize = MobileShopSpacing.touchTarget,
  });

  @override
  Widget build(BuildContext context) {
    Widget target = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: child,
    );

    if (semanticLabel != null) {
      target = Semantics(label: semanticLabel, child: target);
    }

    return target;
  }
}

// ─── Accessible Icon Button ──────────────────────────────────────────────────

/// An icon button with enforced 48dp touch target and semantic label.
///
/// Replaces bare [IconButton] usage in mobile shop screens to guarantee
/// accessibility compliance.
class MobileShopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? tooltip;
  final double? iconSize;
  final Color? color;

  const MobileShopIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
    this.iconSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: IconButton(
        icon: Icon(icon, size: iconSize, color: color),
        onPressed: onPressed,
        tooltip: tooltip ?? semanticLabel,
        constraints: const BoxConstraints(
          minWidth: MobileShopSpacing.touchTarget,
          minHeight: MobileShopSpacing.touchTarget,
        ),
      ),
    );
  }
}

// ─── Status Semantics ────────────────────────────────────────────────────────

/// Describes a status with non-color indicators (text + icon + color).
///
/// Fulfills requirement 11.3: status communicated via text/semantic state
/// in addition to color and icon.
@immutable
class StatusDescriptor {
  /// Human-readable status label (always shown as text).
  final String label;

  /// Icon representation of status.
  final IconData icon;

  /// Color used for the status (supplementary, not sole indicator).
  final Color color;

  /// Whether this status represents an active/live state.
  final bool isActive;

  const StatusDescriptor({
    required this.label,
    required this.icon,
    required this.color,
    this.isActive = false,
  });
}

/// A status indicator widget that uses text + icon + color (non-color-only).
///
/// Always displays:
/// - Icon with semantic meaning
/// - Text label (never color-only)
/// - Color as supplementary visual cue
///
/// Requirements: 11.3, 11.7
class MobileShopStatusIndicator extends StatelessWidget {
  final StatusDescriptor status;

  /// Optional: show as a chip-style badge.
  final bool asChip;

  const MobileShopStatusIndicator({
    super.key,
    required this.status,
    this.asChip = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (asChip) {
      return Semantics(
        label: 'Status: ${status.label}',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MobileShopSpacing.sm,
            vertical: MobileShopSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: status.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 14, color: status.color),
              const SizedBox(width: MobileShopSpacing.xs),
              Text(
                status.label,
                style: MobileShopTheme.of(
                  context,
                ).chipLabelStyle.copyWith(color: status.color),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: 'Status: ${status.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: MobileShopSpacing.xs),
          Text(
            status.label,
            style: theme.textTheme.bodySmall?.copyWith(color: status.color),
          ),
        ],
      ),
    );
  }
}

// ─── Busy State Announcer ────────────────────────────────────────────────────

/// A widget that announces async progress to assistive technologies and
/// prevents duplicate activation during busy state.
///
/// Requirements: 11.8 — announce progress, expose busy state, prevent
/// duplicate activation.
class BusyStateWrapper extends StatelessWidget {
  /// Whether the action is currently in progress.
  final bool isBusy;

  /// Semantic announcement when busy (e.g., "Saving service job").
  final String busyAnnouncement;

  /// The child widget (typically a button).
  final Widget child;

  /// Optional loading indicator to overlay.
  final Widget? loadingIndicator;

  const BusyStateWrapper({
    super.key,
    required this.isBusy,
    required this.busyAnnouncement,
    required this.child,
    this.loadingIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isBusy ? busyAnnouncement : null,
      liveRegion: isBusy,
      child: AbsorbPointer(
        absorbing: isBusy,
        child: AnimatedOpacity(
          opacity: isBusy ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            alignment: Alignment.center,
            children: [
              child,
              if (isBusy)
                loadingIndicator ??
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live Region Announcer ───────────────────────────────────────────────────

/// Wraps content that should be announced to screen readers when it changes.
///
/// Uses [Semantics.liveRegion] to ensure dynamic state changes
/// (loading → data, error messages) are announced.
class LiveRegionAnnouncer extends StatelessWidget {
  /// The content whose changes should be announced.
  final Widget child;

  /// Semantic label override for the announcement.
  final String? announcement;

  const LiveRegionAnnouncer({
    super.key,
    required this.child,
    this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(liveRegion: true, label: announcement, child: child);
  }
}

// ─── Accessible Card ─────────────────────────────────────────────────────────

/// A card widget that applies correct interactive/non-interactive semantics.
///
/// When [onTap] is provided: button semantics, visible tap hint, 48dp target.
/// When [onTap] is null: container semantics, no interaction.
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  final EdgeInsetsGeometry padding;

  const AccessibleCard({
    super.key,
    required this.child,
    this.onTap,
    required this.semanticLabel,
    this.padding = const EdgeInsets.all(MobileShopSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = onTap != null;

    final cardWidget = Card(
      child: Padding(padding: padding, child: child),
    );

    if (isInteractive) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MobileShopSpacing.touchTarget,
            ),
            child: cardWidget,
          ),
        ),
      );
    }

    return Semantics(label: semanticLabel, child: cardWidget);
  }
}
