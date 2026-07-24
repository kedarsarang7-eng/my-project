/// RecoveryActionButton — Typed Recovery Action Widget (Dart)
///
/// A standalone button widget for individual [RecoveryAction] invocations.
/// Used when screens need recovery actions outside of [OperationStateCard]
/// (e.g., in error dialogs, empty states, or bottom sheets).
///
/// Features:
/// - Typed action mapping to icon + label
/// - Accessible: semantic button role, tap hint
/// - Supports primary (filled) and secondary (outlined) variants
/// - Carries correlation ID for support actions
///
/// Requirements: 11.7–11.8, 12.4–12.10; GR-3
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import 'operation_state.dart';

// ─── RecoveryActionButton ────────────────────────────────────────────────────

/// A button that executes a typed [RecoveryAction].
///
/// Can be used standalone or in a group for multiple recovery actions.
///
/// Usage:
/// ```dart
/// RecoveryActionButton(
///   action: RecoveryAction.retry(operationId: 'op-123'),
///   onPressed: () => retryOperation('op-123'),
/// )
/// ```
class RecoveryActionButton extends StatelessWidget {
  /// The recovery action this button represents.
  final RecoveryAction action;

  /// Callback when the button is pressed.
  /// If null, uses the default behavior for the action type.
  final VoidCallback? onPressed;

  /// Whether this is a primary (filled) or secondary (outlined) button.
  final bool isPrimary;

  /// Whether the button is in a loading/busy state.
  final bool isLoading;

  const RecoveryActionButton({
    super.key,
    required this.action,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconForAction(action.type);

    final Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(action.label),
      ],
    );

    if (isPrimary) {
      return Semantics(
        button: true,
        label: '${action.label}. ${action.description ?? ''}',
        child: FilledButton(
          onPressed: isLoading ? null : () => _handlePress(context),
          child: buttonContent,
        ),
      );
    }

    return Semantics(
      button: true,
      label: '${action.label}. ${action.description ?? ''}',
      child: OutlinedButton(
        onPressed: isLoading ? null : () => _handlePress(context),
        child: buttonContent,
      ),
    );
  }

  void _handlePress(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
      return;
    }
    // Default behavior per action type
    _defaultAction(context, action);
  }

  /// Default behavior when no custom [onPressed] is provided.
  static void _defaultAction(BuildContext context, RecoveryAction action) {
    switch (action.type) {
      case RecoveryActionType.signIn:
        GoRouter.of(context).go(RoutePaths.authGate);
      case RecoveryActionType.viewConflicts:
        // Navigate to conflicts view if available
        GoRouter.of(context).go('/mobile-shop/conflicts');
      case RecoveryActionType.viewDetails:
        // Could show a bottom sheet with operation details
        _showOperationDetails(context, action);
      case RecoveryActionType.contactSupport:
        _showSupportDialog(context, action);
      case RecoveryActionType.retry:
      case RecoveryActionType.waitForReconciliation:
      case RecoveryActionType.dismiss:
        // These require explicit callback — no default navigation
        break;
    }
  }

  static void _showOperationDetails(
    BuildContext context,
    RecoveryAction action,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operation Details',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (action.operationId != null)
              _DetailRow(label: 'Operation ID', value: action.operationId!),
            if (action.correlationId != null)
              _DetailRow(label: 'Correlation ID', value: action.correlationId!),
            if (action.description != null)
              _DetailRow(label: 'Description', value: action.description!),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showSupportDialog(BuildContext context, RecoveryAction action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide the following reference when contacting support:',
            ),
            const SizedBox(height: 12),
            if (action.correlationId != null)
              SelectableText(
                'Reference: ${action.correlationId}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(RecoveryActionType type) {
    return switch (type) {
      RecoveryActionType.retry => Icons.refresh_rounded,
      RecoveryActionType.contactSupport => Icons.support_agent_rounded,
      RecoveryActionType.signIn => Icons.login_rounded,
      RecoveryActionType.viewConflicts => Icons.compare_arrows_rounded,
      RecoveryActionType.waitForReconciliation =>
        Icons.hourglass_bottom_rounded,
      RecoveryActionType.dismiss => Icons.close_rounded,
      RecoveryActionType.viewDetails => Icons.info_outline_rounded,
    };
  }
}

// ─── Recovery Action Group ───────────────────────────────────────────────────

/// Renders a group of [RecoveryActionButton]s from an [OperationState].
///
/// Automatically picks the first action as primary and the rest as secondary.
/// Usage:
/// ```dart
/// RecoveryActionGroup(
///   state: failedState,
///   onAction: (action) => handleRecovery(action),
/// )
/// ```
class RecoveryActionGroup extends StatelessWidget {
  /// The operation state whose recovery actions to display.
  final OperationState state;

  /// Callback when any recovery action is pressed.
  final void Function(RecoveryAction action) onAction;

  /// Optional map of action types currently loading.
  final Set<RecoveryActionType> loadingActions;

  const RecoveryActionGroup({
    super.key,
    required this.state,
    required this.onAction,
    this.loadingActions = const {},
  });

  @override
  Widget build(BuildContext context) {
    final actions = state.recoveryActions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < actions.length; i++)
          RecoveryActionButton(
            action: actions[i],
            isPrimary: i == 0,
            isLoading: loadingActions.contains(actions[i].type),
            onPressed: () => onAction(actions[i]),
          ),
      ],
    );
  }
}

// ─── Internal Widgets ────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
