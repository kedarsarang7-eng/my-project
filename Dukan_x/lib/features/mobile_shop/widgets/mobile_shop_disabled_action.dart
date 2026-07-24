/// MobileShop Disabled Action — Programmatically Disabled Controls (Dart)
///
/// Wraps an action button/icon that should be disabled when preconditions
/// are not met. Visually distinct (reduced opacity), no tap response,
/// with a tooltip explaining WHY it's disabled.
///
/// Ensures controls that cannot perform their represented action are
/// programmatically disabled for accessibility (not just visually dimmed).
///
/// Requirements: 11.12, 8.6
library;

import 'package:flutter/material.dart';

// ─── Disabled Reason ─────────────────────────────────────────────────────────

/// Predefined reasons for why an action is unavailable.
///
/// Used both for the tooltip message and semantic label.
enum MobileShopDisabledReason {
  /// User must sign in to perform this action.
  signInRequired('Sign in required'),

  /// User lacks the required permission.
  permissionRequired('Permission required'),

  /// Device is offline and action requires connectivity.
  offline('Offline'),

  /// The action's precondition is not met (generic).
  unavailable('Action unavailable');

  /// Human-readable description for tooltip and semantics.
  final String label;

  const MobileShopDisabledReason(this.label);
}

// ─── Disabled Action Widget ──────────────────────────────────────────────────

/// A wrapper that renders a child action widget in a disabled state when
/// [isDisabled] is true.
///
/// When disabled:
/// - Reduced opacity (0.38 — Material "disabled" opacity)
/// - No tap response (IgnorePointer)
/// - Shows tooltip with [reason] on long-press
/// - Semantics: `enabled: false`, label includes disabled reason
///
/// When enabled:
/// - Renders child as-is with full interactivity
///
/// Usage:
/// ```dart
/// MobileShopDisabledAction(
///   isDisabled: !hasPermission,
///   reason: MobileShopDisabledReason.permissionRequired,
///   child: IconButton(
///     icon: Icon(Icons.edit),
///     onPressed: () => editItem(),
///   ),
/// )
/// ```
class MobileShopDisabledAction extends StatelessWidget {
  /// Whether the action is currently disabled.
  final bool isDisabled;

  /// The reason the action is unavailable (shown in tooltip and semantics).
  final MobileShopDisabledReason reason;

  /// Optional custom disabled message (overrides [reason.label] for tooltip).
  final String? disabledMessage;

  /// The action widget to wrap (button, icon button, etc.).
  final Widget child;

  const MobileShopDisabledAction({
    super.key,
    required this.isDisabled,
    required this.reason,
    this.disabledMessage,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDisabled) {
      return child;
    }

    final message = disabledMessage ?? reason.label;

    return Semantics(
      enabled: false,
      label: message,
      child: Tooltip(
        message: message,
        child: Opacity(opacity: 0.38, child: IgnorePointer(child: child)),
      ),
    );
  }
}
