// ============================================================================
// MOBILE SHOP — LIVE KPI PROVIDER
// ============================================================================
// Tenant-bound providers that compute KPI values from confirmed local
// repository data. Values are NEVER shown as "current" unless backed by
// server-confirmed records.
//
// Each provider:
// - Requires TenantContext (tenant isolation)
// - Only counts serverConfirmed records (not pending)
// - Tracks watermark/freshness metadata
// - Reports loading/current/empty/stale/unavailable/error states
//
// Requirements: 2.7, 9.1–9.8, 9.13, 12.10; Audit: AF-33, AF-47
// ============================================================================

import '../auth/tenant_context.dart';
import '../config/feature_policy_config.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'kpi_metric.dart';
import 'kpi_state.dart';

/// Duration after which a KPI watermark is considered stale.
const Duration kKpiStaleThreshold = Duration(minutes: 15);

/// Abstract interface for a single KPI data source.
///
/// Implementations query the local repository for confirmed data and
/// compute the metric value with watermark metadata.
abstract class KpiDataSource {
  /// The metric this source provides.
  KpiMetric get metric;

  /// Computes the current KPI value from confirmed repository data.
  ///
  /// Returns [KpiState] representing the computed result with freshness
  /// metadata. NEVER returns a "current" state for unconfirmed/pending data.
  Future<KpiState<int>> compute(TenantContext ctx);
}

// ─── Lifecycle Stock KPI Sources ─────────────────────────────────────────────

/// Computes IMEI unit count for a specific lifecycle state.
class LifecycleStockKpiSource implements KpiDataSource {
  final MobileShopLocalRepository _repository;
  final String _lifecycleState;

  @override
  final KpiMetric metric;

  LifecycleStockKpiSource({
    required MobileShopLocalRepository repository,
    required this.metric,
    required String lifecycleState,
  }) : _repository = repository,
       _lifecycleState = lifecycleState;

  @override
  Future<KpiState<int>> compute(TenantContext ctx) async {
    try {
      final records = await _repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
      );

      // Filter by lifecycle state from confirmed records only.
      final matching = records.where(
        (r) => r.entity.lifecycleState == _lifecycleState,
      );

      final syncedAt = _latestSyncTime(records);
      if (syncedAt == null) {
        // No confirmed data available yet
        return const KpiLoading();
      }

      final watermark = KpiWatermark(
        dataVersion: _maxServerVersion(records),
        confirmedAt: syncedAt,
        refreshedAt: syncedAt,
        dataModelVersion: 1,
      );

      final count = matching.length;
      if (count == 0) {
        return KpiEmpty(watermark: watermark, showZero: true);
      }

      if (watermark.isStale(kKpiStaleThreshold)) {
        return KpiStale(
          lastValue: count,
          lastWatermark: watermark,
          refreshStatus: KpiRefreshStatus.notAttempted,
        );
      }

      return KpiCurrent(value: count, watermark: watermark);
    } catch (e) {
      return KpiError(
        error: KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'Failed to compute stock count: $e',
        ),
      );
    }
  }
}

// ─── Repair Stats KPI Sources ────────────────────────────────────────────────

/// Computes service job count for a specific status.
class RepairStatsKpiSource implements KpiDataSource {
  final MobileShopLocalRepository _repository;
  final String _status;

  @override
  final KpiMetric metric;

  RepairStatsKpiSource({
    required MobileShopLocalRepository repository,
    required this.metric,
    required String status,
  }) : _repository = repository,
       _status = status;

  @override
  Future<KpiState<int>> compute(TenantContext ctx) async {
    try {
      final records = await _repository.listServiceJobs(ctx, status: _status);

      // Only count confirmed records.
      final confirmed = records.where((r) => r.isServerConfirmed);

      final syncedAt = _latestSyncTimeFromJobs(records);
      if (syncedAt == null) {
        return const KpiLoading();
      }

      final watermark = KpiWatermark(
        dataVersion: _maxServerVersionFromJobs(records),
        confirmedAt: syncedAt,
        refreshedAt: syncedAt,
        dataModelVersion: 1,
      );

      final count = confirmed.length;
      if (count == 0) {
        return KpiEmpty(watermark: watermark, showZero: true);
      }

      if (watermark.isStale(kKpiStaleThreshold)) {
        return KpiStale(
          lastValue: count,
          lastWatermark: watermark,
          refreshStatus: KpiRefreshStatus.notAttempted,
        );
      }

      return KpiCurrent(value: count, watermark: watermark);
    } catch (e) {
      return KpiError(
        error: KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'Failed to compute repair stats: $e',
        ),
      );
    }
  }

  DateTime? _latestSyncTimeFromJobs(List<LocalRecord<dynamic>> records) {
    DateTime? latest;
    for (final r in records) {
      if (r.syncedAt != null &&
          (latest == null || r.syncedAt!.isAfter(latest))) {
        latest = r.syncedAt;
      }
    }
    return latest;
  }

  int _maxServerVersionFromJobs(List<LocalRecord<dynamic>> records) {
    int max = 0;
    for (final r in records) {
      if (r.serverVersion > max) max = r.serverVersion;
    }
    return max;
  }
}

// ─── Exchange Stats KPI Sources ──────────────────────────────────────────────

/// Computes exchange count/value for a specific status.
class ExchangeStatsKpiSource implements KpiDataSource {
  final MobileShopLocalRepository _repository;
  final String _status;
  final bool _computeValue;

  @override
  final KpiMetric metric;

  ExchangeStatsKpiSource({
    required MobileShopLocalRepository repository,
    required this.metric,
    required String status,
    bool computeValue = false,
  }) : _repository = repository,
       _status = status,
       _computeValue = computeValue;

  @override
  Future<KpiState<int>> compute(TenantContext ctx) async {
    try {
      final records = await _repository.listExchanges(ctx, status: _status);

      final confirmed = records.where((r) => r.isServerConfirmed);

      final syncedAt = _latestSyncTimeFromExchanges(records);
      if (syncedAt == null) {
        return const KpiLoading();
      }

      final watermark = KpiWatermark(
        dataVersion: _maxServerVersionFromExchanges(records),
        confirmedAt: syncedAt,
        refreshedAt: syncedAt,
        dataModelVersion: 1,
      );

      if (_computeValue) {
        // Sum adjustment values (paise) for value-based KPIs.
        int totalPaise = 0;
        for (final r in confirmed) {
          final adjustmentPaise = r.entity.adjustmentPaise;
          if (adjustmentPaise != null) {
            totalPaise += adjustmentPaise;
          }
        }
        if (totalPaise == 0 && confirmed.isEmpty) {
          return KpiEmpty(watermark: watermark, showZero: true);
        }
        if (watermark.isStale(kKpiStaleThreshold)) {
          return KpiStale(
            lastValue: totalPaise,
            lastWatermark: watermark,
            refreshStatus: KpiRefreshStatus.notAttempted,
          );
        }
        return KpiCurrent(value: totalPaise, watermark: watermark);
      }

      final count = confirmed.length;
      if (count == 0) {
        return KpiEmpty(watermark: watermark, showZero: true);
      }

      if (watermark.isStale(kKpiStaleThreshold)) {
        return KpiStale(
          lastValue: count,
          lastWatermark: watermark,
          refreshStatus: KpiRefreshStatus.notAttempted,
        );
      }

      return KpiCurrent(value: count, watermark: watermark);
    } catch (e) {
      return KpiError(
        error: KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'Failed to compute exchange stats: $e',
        ),
      );
    }
  }

  DateTime? _latestSyncTimeFromExchanges(List<LocalRecord<dynamic>> records) {
    DateTime? latest;
    for (final r in records) {
      if (r.syncedAt != null &&
          (latest == null || r.syncedAt!.isAfter(latest))) {
        latest = r.syncedAt;
      }
    }
    return latest;
  }

  int _maxServerVersionFromExchanges(List<LocalRecord<dynamic>> records) {
    int max = 0;
    for (final r in records) {
      if (r.serverVersion > max) max = r.serverVersion;
    }
    return max;
  }
}

// ─── Warranty Stats KPI Sources ──────────────────────────────────────────────

/// Computes warranty count for a specific status/claim state.
class WarrantyStatsKpiSource implements KpiDataSource {
  final MobileShopLocalRepository _repository;
  final String _status;

  @override
  final KpiMetric metric;

  WarrantyStatsKpiSource({
    required MobileShopLocalRepository repository,
    required this.metric,
    required String status,
  }) : _repository = repository,
       _status = status;

  @override
  Future<KpiState<int>> compute(TenantContext ctx) async {
    try {
      final records = await _repository.listWarranties(ctx, status: _status);

      final confirmed = records.where((r) => r.isServerConfirmed);

      final syncedAt = _latestSyncTimeFromWarranties(records);
      if (syncedAt == null) {
        return const KpiLoading();
      }

      final watermark = KpiWatermark(
        dataVersion: _maxServerVersionFromWarranties(records),
        confirmedAt: syncedAt,
        refreshedAt: syncedAt,
        dataModelVersion: 1,
      );

      final count = confirmed.length;
      if (count == 0) {
        return KpiEmpty(watermark: watermark, showZero: true);
      }

      if (watermark.isStale(kKpiStaleThreshold)) {
        return KpiStale(
          lastValue: count,
          lastWatermark: watermark,
          refreshStatus: KpiRefreshStatus.notAttempted,
        );
      }

      return KpiCurrent(value: count, watermark: watermark);
    } catch (e) {
      return KpiError(
        error: KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'Failed to compute warranty stats: $e',
        ),
      );
    }
  }

  DateTime? _latestSyncTimeFromWarranties(List<LocalRecord<dynamic>> records) {
    DateTime? latest;
    for (final r in records) {
      if (r.syncedAt != null &&
          (latest == null || r.syncedAt!.isAfter(latest))) {
        latest = r.syncedAt;
      }
    }
    return latest;
  }

  int _maxServerVersionFromWarranties(List<LocalRecord<dynamic>> records) {
    int max = 0;
    for (final r in records) {
      if (r.serverVersion > max) max = r.serverVersion;
    }
    return max;
  }
}

// ─── Conflict & Reconciliation KPI Sources ───────────────────────────────────

/// Computes unresolved conflict count.
class ConflictCountKpiSource implements KpiDataSource {
  final MobileShopLocalRepository _repository;

  @override
  final KpiMetric metric;

  ConflictCountKpiSource({
    required MobileShopLocalRepository repository,
    required this.metric,
  }) : _repository = repository;

  @override
  Future<KpiState<int>> compute(TenantContext ctx) async {
    try {
      final conflicts = await _repository.listConflicts(
        ctx,
        resolutionStatus: ConflictResolutionStatus.unresolved,
      );

      // Conflicts are local state; use current time as watermark.
      final now = DateTime.now();
      final watermark = KpiWatermark(
        dataVersion: conflicts.length,
        confirmedAt: now,
        refreshedAt: now,
        dataModelVersion: 1,
      );

      final count = conflicts.length;
      if (count == 0) {
        return KpiEmpty(watermark: watermark, showZero: true);
      }

      return KpiCurrent(value: count, watermark: watermark);
    } catch (e) {
      return KpiError(
        error: KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'Failed to compute conflict count: $e',
        ),
      );
    }
  }
}

// ─── Helper Functions ────────────────────────────────────────────────────────

DateTime? _latestSyncTime(List<LocalRecord<dynamic>> records) {
  DateTime? latest;
  for (final r in records) {
    if (r.syncedAt != null && (latest == null || r.syncedAt!.isAfter(latest))) {
      latest = r.syncedAt;
    }
  }
  return latest;
}

int _maxServerVersion(List<LocalRecord<dynamic>> records) {
  int max = 0;
  for (final r in records) {
    if (r.serverVersion > max) max = r.serverVersion;
  }
  return max;
}

// ─── KPI Provider Registry ───────────────────────────────────────────────────

/// Creates all KPI data sources for the complete dashboard.
///
/// Each source queries ONLY confirmed data from the local repository.
/// No fabricated/hardcoded values are used.
List<KpiDataSource> createAllKpiSources(MobileShopLocalRepository repository) {
  return [
    // Lifecycle stock
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.stockInStock,
      lifecycleState: 'IN_STOCK',
    ),
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.stockReserved,
      lifecycleState: 'RESERVED',
    ),
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.stockSold,
      lifecycleState: 'SOLD',
    ),
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.stockDemo,
      lifecycleState: 'DEMO',
    ),

    // Repair stats
    RepairStatsKpiSource(
      repository: repository,
      metric: KpiMetric.repairActive,
      status: 'active',
    ),
    RepairStatsKpiSource(
      repository: repository,
      metric: KpiMetric.repairOverdue,
      status: 'overdue',
    ),
    RepairStatsKpiSource(
      repository: repository,
      metric: KpiMetric.repairCompleted,
      status: 'completed',
    ),

    // Exchange stats
    ExchangeStatsKpiSource(
      repository: repository,
      metric: KpiMetric.exchangePending,
      status: 'pending',
    ),
    ExchangeStatsKpiSource(
      repository: repository,
      metric: KpiMetric.exchangeValuePaise,
      status: 'pending',
      computeValue: true,
    ),
    ExchangeStatsKpiSource(
      repository: repository,
      metric: KpiMetric.exchangeCompleted,
      status: 'completed',
    ),

    // Warranty stats
    WarrantyStatsKpiSource(
      repository: repository,
      metric: KpiMetric.warrantyActive,
      status: 'active',
    ),
    WarrantyStatsKpiSource(
      repository: repository,
      metric: KpiMetric.warrantyExpiringSoon,
      status: 'expiring_soon',
    ),
    WarrantyStatsKpiSource(
      repository: repository,
      metric: KpiMetric.warrantyClaims,
      status: 'open',
    ),

    // Used stock (use lifecycle filter from IMEI units)
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.usedStockAvailable,
      lifecycleState: 'USED_AVAILABLE',
    ),

    // Conflicts
    ConflictCountKpiSource(
      repository: repository,
      metric: KpiMetric.conflictsUnresolved,
    ),

    // Returns (lifecycle-based)
    LifecycleStockKpiSource(
      repository: repository,
      metric: KpiMetric.returnsTotal,
      lifecycleState: 'RETURNED',
    ),
  ];
}
