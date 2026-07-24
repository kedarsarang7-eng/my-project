/// ReconciliationStatusDisplay — UI for Pending/Confirmed/Conflicted States
///
/// Displays the reconciliation and confirmation status for mobile operations.
/// Prevents unconfirmed outcomes from appearing as committed or current.
///
/// Key behaviors:
/// - Shows "Pending Sync" for locally queued operations
/// - Shows "Awaiting Confirmation" for accepted-pending reconciliation
/// - Shows "Confirmed" ONLY when AuthoritativeConfirmation is present
/// - Shows "Conflict" with resolution guidance for conflicts
/// - Never shows "committed" or "successful" without server confirmation
///
/// Requirements: 12.7–12.10; GR-3
library;

import 'package:flutter/material.dart';

import 'mobile_sale_consistency_orchestrator.dart';

/// Visual representation of operation confirmation status.
///
/// Used in bill lists, detail screens, and status cards to clearly communicate
/// whether an operation is local-only, pending, confirmed, or conflicted.
class ReconciliationStatusDisplay extends StatelessWidget {
  /// The current operation outcome to display.
  final ConsistencyOutcome? outcome;

  /// Optional operation ID for tracing.
  final String? operationId;

  /// Whether to show a compact (inline) or expanded view.
  final bool compact;

  const ReconciliationStatusDisplay({
    super.key,
    this.outcome,
    this.operationId,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (outcome == null) {
      return const SizedBox.shrink();
    }

    final config = _statusConfig(outcome!.state);

    if (compact) {
      return _CompactStatus(config: config);
    }

    return _ExpandedStatus(config: config, outcome: outcome!);
  }

  _StatusDisplayConfig _statusConfig(SaleOutcomeState state) {
    switch (state) {
      case SaleOutcomeState.localPending:
        return const _StatusDisplayConfig(
          label: 'Pending Sync',
          semanticLabel: 'Operation pending synchronization',
          icon: Icons.cloud_upload_outlined,
          color: _StatusColors.pending,
          description: 'Saved locally. Will sync when online.',
        );
      case SaleOutcomeState.offlineQueued:
        return const _StatusDisplayConfig(
          label: 'Offline',
          semanticLabel: 'Operation queued offline',
          icon: Icons.cloud_off_outlined,
          color: _StatusColors.offline,
          description: 'Queued for delivery when connectivity returns.',
        );
      case SaleOutcomeState.acceptedPending:
        return const _StatusDisplayConfig(
          label: 'Processing',
          semanticLabel: 'Operation accepted, awaiting completion',
          icon: Icons.hourglass_top_rounded,
          color: _StatusColors.reconciling,
          description: 'Accepted by server. Reconciliation in progress.',
        );
      case SaleOutcomeState.committed:
        return const _StatusDisplayConfig(
          label: 'Confirmed',
          semanticLabel: 'Operation confirmed by server',
          icon: Icons.check_circle_outline,
          color: _StatusColors.confirmed,
          description: 'Confirmed and committed.',
        );
      case SaleOutcomeState.conflict:
        return const _StatusDisplayConfig(
          label: 'Conflict',
          semanticLabel: 'Operation has a conflict requiring resolution',
          icon: Icons.warning_amber_rounded,
          color: _StatusColors.conflict,
          description: 'A conflict was detected. Review required.',
        );
      case SaleOutcomeState.rejected:
        return const _StatusDisplayConfig(
          label: 'Rejected',
          semanticLabel: 'Operation was rejected',
          icon: Icons.cancel_outlined,
          color: _StatusColors.rejected,
          description: 'Operation was rejected by the server.',
        );
    }
  }
}

/// Compact inline status indicator (icon + label).
class _CompactStatus extends StatelessWidget {
  final _StatusDisplayConfig config;

  const _CompactStatus({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: config.semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 16, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: theme.textTheme.labelSmall?.copyWith(color: config.color),
          ),
        ],
      ),
    );
  }
}

/// Expanded status with description and optional action.
class _ExpandedStatus extends StatelessWidget {
  final _StatusDisplayConfig config;
  final ConsistencyOutcome outcome;

  const _ExpandedStatus({required this.config, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: config.semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: config.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: config.color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(config.icon, size: 24, color: config.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    config.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: config.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (outcome.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      outcome.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: config.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Config Types ────────────────────────────────────────────────────────────

@immutable
class _StatusDisplayConfig {
  final String label;
  final String semanticLabel;
  final IconData icon;
  final Color color;
  final String description;

  const _StatusDisplayConfig({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.color,
    required this.description,
  });
}

/// Status color constants — non-color-dependent status is also
/// communicated via icon and text (Req 11.3, 11.7).
abstract class _StatusColors {
  static const pending = Color(0xFF1976D2); // Blue
  static const offline = Color(0xFF757575); // Grey
  static const reconciling = Color(0xFFF57C00); // Orange
  static const confirmed = Color(0xFF388E3C); // Green
  static const conflict = Color(0xFFF9A825); // Amber
  static const rejected = Color(0xFFD32F2F); // Red
}

// ─── Helper for Bill Lists ───────────────────────────────────────────────────

/// Maps a local confirmation status string (from Drift) to an outcome state
/// for display purposes.
///
/// This bridges the repository's confirmation status with the UI display.
SaleOutcomeState? confirmationStatusToOutcomeState(String? status) {
  if (status == null) return null;
  switch (status) {
    case 'pending':
    case 'pendingSync':
      return SaleOutcomeState.localPending;
    case 'serverConfirmed':
      return SaleOutcomeState.committed;
    case 'conflict':
      return SaleOutcomeState.conflict;
    case 'acceptedPending':
      return SaleOutcomeState.acceptedPending;
    case 'offlineQueued':
      return SaleOutcomeState.offlineQueued;
    case 'rejected':
      return SaleOutcomeState.rejected;
    default:
      return null;
  }
}
