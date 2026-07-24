/// OperationState Mappers — Integration with Existing State Types (Dart)
///
/// Maps from [ConsistencyOutcome], [CommerceOutcome], [ScreenState], and
/// [KpiState] to the unified [OperationState]. This allows ALL screens to
/// use the centralized state display system regardless of their data source.
///
/// Requirements: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3
library;

import '../../billing/mobile_sale_consistency_orchestrator.dart';
import '../../kpi/kpi_state.dart';
import '../../screens/commerce/mobile_commerce_service.dart';
import '../../screens/screen_state.dart';
import 'operation_state.dart';

// ─── From ConsistencyOutcome ─────────────────────────────────────────────────

/// Maps a [ConsistencyOutcome] to the unified [OperationState].
///
/// Enforces GR-3: only [SaleOutcomeState.committed] with confirmation
/// maps to [OperationComplete]. Everything else is pending, conflicted,
/// or failed.
OperationState mapConsistencyOutcome(ConsistencyOutcome outcome) {
  switch (outcome.state) {
    case SaleOutcomeState.localPending:
      return OperationPending(
        message: 'Saved locally. Will sync when online.',
        operationId: outcome.operationId,
        kind: PendingKind.localQueued,
      );
    case SaleOutcomeState.offlineQueued:
      return OperationPending(
        message: 'Queued for delivery when connectivity returns.',
        operationId: outcome.operationId,
        kind: PendingKind.localQueued,
      );
    case SaleOutcomeState.acceptedPending:
      return OperationPending(
        message: 'Accepted by server. Reconciliation in progress.',
        operationId: outcome.operationId,
        kind: PendingKind.reconciling,
      );
    case SaleOutcomeState.committed:
      // GR-3: only confirmed if AuthoritativeConfirmation exists
      if (outcome.confirmation != null) {
        return OperationComplete(
          message: 'Operation confirmed and committed.',
          confirmedAt:
              DateTime.tryParse(outcome.confirmation!.confirmedAt) ??
              DateTime.now(),
          operationId: outcome.operationId,
        );
      }
      // Without confirmation, treat as pending (GR-3 enforcement)
      return OperationPending(
        message: 'Awaiting authoritative confirmation.',
        operationId: outcome.operationId,
        kind: PendingKind.serverAccepted,
      );
    case SaleOutcomeState.conflict:
      return OperationConflicted(
        message: outcome.errorMessage ?? 'A conflict was detected.',
        operationId: outcome.operationId,
        autoResolvable: false,
      );
    case SaleOutcomeState.rejected:
      return OperationFailed(
        message: outcome.errorMessage ?? 'Operation was rejected.',
        errorCode: outcome.errorCode,
        retryable: outcome.retryable,
        operationId: outcome.operationId,
      );
  }
}

// ─── From CommerceOutcome ────────────────────────────────────────────────────

/// Maps a [CommerceOutcome] to the unified [OperationState].
OperationState mapCommerceOutcome(CommerceOutcome outcome) {
  switch (outcome.state) {
    case CommerceOutcomeState.success:
      return OperationComplete(
        message: 'Operation completed successfully.',
        confirmedAt: DateTime.now(),
        operationId: outcome.operationId,
      );
    case CommerceOutcomeState.pending:
      return OperationPending(
        message: 'Operation pending verification.',
        operationId: outcome.operationId,
        kind: PendingKind.serverAccepted,
      );
    case CommerceOutcomeState.ambiguous:
      return OperationPending(
        message: 'Provider returned ambiguous result. Reconciling.',
        operationId: outcome.operationId,
        kind: PendingKind.reconciling,
      );
    case CommerceOutcomeState.rejected:
      return OperationFailed(
        message: outcome.errorMessage ?? 'Operation rejected.',
        errorCode: outcome.errorCode,
        retryable: false,
        operationId: outcome.operationId,
      );
    case CommerceOutcomeState.offlinePreserved:
      return OperationPending(
        message: 'Saved offline. Will submit when online.',
        operationId: outcome.operationId,
        kind: PendingKind.localQueued,
      );
    case CommerceOutcomeState.featureDisabled:
      return OperationDisabled(
        reason: outcome.errorMessage ?? 'Feature not available.',
        disabledReason: DisabledReason.generic,
      );
    case CommerceOutcomeState.connectivityRequired:
      return OperationDisabled(
        reason: 'Online connectivity required for this operation.',
        disabledReason: DisabledReason.offline,
      );
  }
}

// ─── From ScreenState ────────────────────────────────────────────────────────

/// Maps a [ScreenState] to the unified [OperationState].
///
/// Useful when a screen wants to render its data-fetch state through
/// the centralized widget system.
OperationState mapScreenState<T>(ScreenState<T> state) {
  return switch (state) {
    ScreenLoading() => const OperationLoading(),
    ScreenData(:final isStale, :final lastRefreshed) =>
      isStale
          ? OperationStale(
              message: 'Data may be outdated.',
              lastConfirmedAt: lastRefreshed,
              refreshStatus: StaleRefreshStatus.refreshing,
            )
          : OperationComplete(
              message: 'Data loaded.',
              confirmedAt: lastRefreshed ?? DateTime.now(),
            ),
    ScreenEmpty(:final message) => OperationEmpty(
      message: message ?? 'No items found.',
    ),
    ScreenError(
      :final errorCode,
      :final message,
      :final isRetryable,
      :final correlationId,
    ) =>
      OperationFailed(
        message: message,
        errorCode: errorCode,
        retryable: isRetryable,
        correlationId: correlationId,
      ),
    ScreenSessionLost(:final message) => OperationSignedOut(message: message),
  };
}

// ─── From KpiState ───────────────────────────────────────────────────────────

/// Maps a [KpiState] to the unified [OperationState].
///
/// Enforces GR-3: no fabricated success. Loading/unavailable states
/// never appear as "complete".
OperationState mapKpiState<T>(KpiState<T> state) {
  return switch (state) {
    KpiLoading() => const OperationLoading(message: 'Loading KPI data…'),
    KpiCurrent(:final watermark) => OperationComplete(
      message: 'KPI data is current.',
      confirmedAt: watermark.confirmedAt,
    ),
    KpiEmpty(:final watermark, :final showZero) => OperationEmpty(
      message: showZero ? 'Zero' : 'No data available.',
      showZero: showZero,
    ),
    KpiStale(:final lastWatermark, :final refreshStatus) => OperationStale(
      message: 'KPI data may be outdated.',
      lastConfirmedAt: lastWatermark.confirmedAt,
      refreshStatus: switch (refreshStatus) {
        KpiRefreshStatus.refreshing => StaleRefreshStatus.refreshing,
        KpiRefreshStatus.retryPending => StaleRefreshStatus.retryPending,
        KpiRefreshStatus.notAttempted => StaleRefreshStatus.notAttempted,
      },
    ),
    KpiUnavailable(:final reason) => OperationUnavailable(message: reason),
    KpiError(:final error) => OperationFailed(
      message: error.message,
      correlationId: error.correlationId,
      retryable: error.kind == KpiErrorKind.network,
    ),
  };
}

// ─── From raw confirmation status string ─────────────────────────────────────

/// Maps a raw status string (from Drift/local DB) to [OperationState].
///
/// Useful for list items where only a status string is available.
OperationState mapConfirmationStatus(String? status) {
  if (status == null) return const OperationLoading();
  switch (status) {
    case 'pending':
    case 'pendingSync':
      return const OperationPending(
        message: 'Pending synchronization.',
        kind: PendingKind.localQueued,
      );
    case 'serverConfirmed':
      return OperationComplete(
        message: 'Confirmed.',
        confirmedAt: DateTime.now(),
      );
    case 'conflict':
      return const OperationConflicted(
        message: 'A conflict requires resolution.',
      );
    case 'acceptedPending':
      return const OperationPending(
        message: 'Accepted by server. Reconciliation in progress.',
        kind: PendingKind.reconciling,
      );
    case 'offlineQueued':
      return const OperationPending(
        message: 'Queued offline.',
        kind: PendingKind.localQueued,
      );
    case 'rejected':
      return const OperationFailed(
        message: 'Operation was rejected.',
        retryable: false,
      );
    default:
      return const OperationLoading();
  }
}
