/// OperationStateCard — Reusable Card for Any Operation State (Dart)
///
/// Renders distinct visuals (icon, color, text, actions) for each
/// [OperationState] variant. Announces state changes to assistive technology
/// using [Semantics] liveRegion. Exposes typed recovery actions.
///
/// Key differences from [ReconciliationStatusDisplay]:
/// - Works with ANY operation (not just billing/sync)
/// - Includes recovery action buttons (retry, contact support, sign in, etc.)
/// - Announces progress to screen readers
/// - Prevents "spinner forever" with timeout awareness
///
/// Requirements: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3
library;

import 'package:flutter/material.dart';

import 'operation_state.dart';

// ─── Callbacks ───────────────────────────────────────────────────────────────

/// Callback for recovery action invocation.
typedef OnRecoveryAction = void Function(RecoveryAction action);

// ─── OperationStateCard ──────────────────────────────────────────────────────

/// A card widget that renders distinct visuals for each [OperationState].
///
/// Features:
/// - Distinct icon, color, label, and description per state
/// - Recovery action buttons when applicable
/// - Semantics liveRegion for screen reader announcements
/// - Compact and expanded variants
/// - Non-color-dependent status (text + icon always present)
class OperationStateCard extends StatelessWidget {
  /// The current operation state to display.
  final OperationState state;

  /// Callback when a recovery action is invoked.
  final OnRecoveryAction? onRecoveryAction;

  /// Whether to show a compact (inline) or expanded view.
  final bool compact;

  /// Optional title override for the card.
  final String? title;

  const OperationStateCard({
    super.key,
    required this.state,
    this.onRecoveryAction,
    this.compact = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveConfig(state);

    // Wrap in Semantics liveRegion for screen reader announcements
    return Semantics(
      liveRegion: true,
      label: state.accessibilityAnnouncement,
      child: compact
          ? _CompactStateView(config: config)
          : _ExpandedStateView(
              config: config,
              state: state,
              title: title,
              onRecoveryAction: onRecoveryAction,
            ),
    );
  }

  /// Resolves visual configuration for a given operation state.
  _StateVisualConfig _resolveConfig(OperationState state) {
    return switch (state) {
      OperationLoading(:final progress) => _StateVisualConfig(
        icon: Icons.hourglass_top_rounded,
        color: _StateColors.loading,
        label: state.label,
        showProgress: true,
        progress: progress,
      ),
      OperationEmpty() => _StateVisualConfig(
        icon: Icons.inbox_outlined,
        color: _StateColors.empty,
        label: state.label,
      ),
      OperationDisabled() => _StateVisualConfig(
        icon: Icons.block_outlined,
        color: _StateColors.disabled,
        label: state.label,
      ),
      OperationPending(:final kind) => _StateVisualConfig(
        icon: switch (kind) {
          PendingKind.localQueued => Icons.cloud_upload_outlined,
          PendingKind.serverAccepted => Icons.cloud_done_outlined,
          PendingKind.reconciling => Icons.sync_outlined,
        },
        color: _StateColors.pending,
        label: state.label,
      ),
      OperationStale() => _StateVisualConfig(
        icon: Icons.update_outlined,
        color: _StateColors.stale,
        label: state.label,
      ),
      OperationConflicted() => _StateVisualConfig(
        icon: Icons.warning_amber_rounded,
        color: _StateColors.conflicted,
        label: state.label,
      ),
      OperationUnavailable() => _StateVisualConfig(
        icon: Icons.cloud_off_outlined,
        color: _StateColors.unavailable,
        label: state.label,
      ),
      OperationFailed() => _StateVisualConfig(
        icon: Icons.error_outline_rounded,
        color: _StateColors.failed,
        label: state.label,
      ),
      OperationComplete() => _StateVisualConfig(
        icon: Icons.check_circle_outline_rounded,
        color: _StateColors.complete,
        label: state.label,
      ),
      OperationSignedOut() => _StateVisualConfig(
        icon: Icons.lock_outline_rounded,
        color: _StateColors.signedOut,
        label: state.label,
      ),
    };
  }
}

// ─── Compact View ────────────────────────────────────────────────────────────

class _CompactStateView extends StatelessWidget {
  final _StateVisualConfig config;

  const _CompactStateView({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.showProgress)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: config.progress,
              color: config.color,
            ),
          )
        else
          Icon(config.icon, size: 16, color: config.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            config.label,
            style: theme.textTheme.labelSmall?.copyWith(color: config.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Expanded View ───────────────────────────────────────────────────────────

class _ExpandedStateView extends StatelessWidget {
  final _StateVisualConfig config;
  final OperationState state;
  final String? title;
  final OnRecoveryAction? onRecoveryAction;

  const _ExpandedStateView({
    required this.config,
    required this.state,
    this.title,
    this.onRecoveryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: icon + label
          Row(
            children: [
              if (config.showProgress)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: config.progress,
                    color: config.color,
                  ),
                )
              else
                Icon(config.icon, size: 24, color: config.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title ?? config.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: config.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description text
          Text(
            state.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // Recovery actions
          if (state.recoveryActions.isNotEmpty && onRecoveryAction != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.recoveryActions
                  .map(
                    (action) => _RecoveryActionChip(
                      action: action,
                      color: config.color,
                      onTap: () => onRecoveryAction!(action),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Recovery Action Chip ────────────────────────────────────────────────────

class _RecoveryActionChip extends StatelessWidget {
  final RecoveryAction action;
  final Color color;
  final VoidCallback onTap;

  const _RecoveryActionChip({
    required this.action,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_actionIcon(action.type), size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(RecoveryActionType type) {
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

// ─── Visual Configuration ────────────────────────────────────────────────────

@immutable
class _StateVisualConfig {
  final IconData icon;
  final Color color;
  final String label;
  final bool showProgress;
  final double? progress;

  const _StateVisualConfig({
    required this.icon,
    required this.color,
    required this.label,
    this.showProgress = false,
    this.progress,
  });
}

/// State colors — non-color-dependent status is always communicated
/// via icon AND text (Req 11.3, 11.7).
abstract class _StateColors {
  static const loading = Color(0xFF1976D2); // Blue
  static const empty = Color(0xFF757575); // Grey
  static const disabled = Color(0xFF9E9E9E); // Light grey
  static const pending = Color(0xFF1976D2); // Blue
  static const stale = Color(0xFFF57C00); // Orange
  static const conflicted = Color(0xFFF9A825); // Amber
  static const unavailable = Color(0xFF757575); // Grey
  static const failed = Color(0xFFD32F2F); // Red
  static const complete = Color(0xFF388E3C); // Green
  static const signedOut = Color(0xFF5D4037); // Brown
}
