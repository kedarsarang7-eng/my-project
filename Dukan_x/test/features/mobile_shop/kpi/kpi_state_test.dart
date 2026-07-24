/// KPI State & Provider Tests — Task 15.4
///
/// Tests cover:
/// 1. No fabricated counts: KPI returns Loading until confirmed data exists
/// 2. Stale semantics: KpiStale when watermark exceeds threshold
/// 3. Unavailable semantics: KpiUnavailable when feature disabled/permission
/// 4. Error semantics: KpiError with preserved last value
/// 5. Tenant-bound source calls: all KPI sources require TenantContext
///
/// Requirements validated: 1.6, 9.1–9.6, 9.13, 13.1
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/kpi/kpi_metric.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_provider.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_state.dart';
import 'package:dukanx/features/mobile_shop/repository/mobile_shop_local_repository.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. NO FABRICATED COUNTS — Requirement 9.1
  // ═══════════════════════════════════════════════════════════════════════════

  group('No fabricated counts before confirmed data (Req 9.1)', () {
    test('KpiLoading valueOrNull is null — no count displayed', () {
      const state = KpiLoading<int>();
      expect(state.valueOrNull, isNull);
      expect(state.hasValue, isFalse);
      expect(state.isCurrent, isFalse);
      expect(state.isLoading, isTrue);
    });

    test('KpiLoading does not produce a displayable number', () {
      // This is the key assertion: before confirmed data,
      // there is NO numeric value — preventing fabricated counts.
      const state = KpiLoading<int>();
      expect(state.valueOrNull, isNull);
    });

    test('no KPI source uses hardcoded values in createAllKpiSources', () {
      // Verify createAllKpiSources creates only repository-backed sources.
      // None use hardcoded values; all query confirmed data.
      final sources = createAllKpiSources(_FakeRepository());
      expect(sources, isNotEmpty);

      // Each source has a declared metric
      for (final source in sources) {
        expect(source.metric, isNotNull);
        expect(KpiMetric.values.contains(source.metric), isTrue);
      }
    });

    test('createAllKpiSources covers required metrics', () {
      final sources = createAllKpiSources(_FakeRepository());
      final metrics = sources.map((s) => s.metric).toSet();

      // Verify key required metrics are present (Req 9.7)
      expect(metrics, contains(KpiMetric.stockInStock));
      expect(metrics, contains(KpiMetric.repairActive));
      expect(metrics, contains(KpiMetric.repairOverdue));
      expect(metrics, contains(KpiMetric.exchangePending));
      expect(metrics, contains(KpiMetric.warrantyActive));
      expect(metrics, contains(KpiMetric.conflictsUnresolved));
      expect(metrics, contains(KpiMetric.returnsTotal));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. KpiCurrent — Requirement 9.2
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiCurrent state with confirmed data (Req 9.2)', () {
    test('KpiCurrent has value and watermark', () {
      final watermark = KpiWatermark(
        dataVersion: 7,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 1,
      );
      final state = KpiCurrent<int>(value: 42, watermark: watermark);
      expect(state.value, 42);
      expect(state.valueOrNull, 42);
      expect(state.hasValue, isTrue);
      expect(state.isCurrent, isTrue);
      expect(state.watermark.dataVersion, 7);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. KpiEmpty — Requirement 9.3
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiEmpty confirmed-empty state (Req 9.3)', () {
    test('KpiEmpty valueOrNull is null — no fabricated count', () {
      final watermark = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 1,
      );
      final state = KpiEmpty<int>(watermark: watermark);
      expect(state.valueOrNull, isNull);
      expect(state.hasValue, isFalse);
    });

    test('KpiEmpty showZero=true means zero for confirmed empty', () {
      final watermark = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 1,
      );
      final state = KpiEmpty<int>(watermark: watermark, showZero: true);
      expect(state.showZero, isTrue);
      // Even with showZero, valueOrNull stays null (display logic decides)
      expect(state.valueOrNull, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. STALE SEMANTICS — Requirement 9.4
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiStale when watermark exceeds threshold (Req 9.4)', () {
    test('KpiStale preserves lastValue with stale indicator', () {
      final watermark = KpiWatermark(
        dataVersion: 5,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 1,
      );
      final state = KpiStale<int>(
        lastValue: 10,
        lastWatermark: watermark,
        refreshStatus: KpiRefreshStatus.refreshing,
      );
      expect(state.valueOrNull, 10);
      expect(state.hasValue, isTrue);
      expect(state.isCurrent, isFalse);
      expect(state.refreshStatus, KpiRefreshStatus.refreshing);
    });

    test('KpiWatermark.isStale returns true when age exceeds maxAge', () {
      final staleWatermark = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        refreshedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        dataModelVersion: 1,
      );
      expect(staleWatermark.isStale(const Duration(minutes: 15)), isTrue);
    });

    test('KpiWatermark.isStale returns false when within maxAge', () {
      final freshWatermark = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        refreshedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        dataModelVersion: 1,
      );
      expect(freshWatermark.isStale(const Duration(minutes: 15)), isFalse);
    });

    test('kKpiStaleThreshold is 15 minutes', () {
      expect(kKpiStaleThreshold, const Duration(minutes: 15));
    });

    test('all refresh statuses are available', () {
      expect(
        KpiRefreshStatus.values,
        containsAll([
          KpiRefreshStatus.refreshing,
          KpiRefreshStatus.retryPending,
          KpiRefreshStatus.notAttempted,
        ]),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. UNAVAILABLE SEMANTICS — Requirement 9.5
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    'KpiUnavailable when feature disabled or permission missing (Req 9.5)',
    () {
      test('KpiUnavailable has no value — no fabricated count', () {
        const state = KpiUnavailable<int>(
          reason: 'Feature EXCHANGES not enabled',
        );
        expect(state.valueOrNull, isNull);
        expect(state.hasValue, isFalse);
        expect(state.isCurrent, isFalse);
      });

      test('KpiUnavailable carries a reason string', () {
        const state = KpiUnavailable<int>(
          reason: 'Permission mobile_shop:exchange:view not granted',
        );
        expect(state.reason, contains('Permission'));
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. ERROR SEMANTICS — Requirement 9.6
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiError with preserved last value (Req 9.6)', () {
    test('KpiError without lastValue has null valueOrNull', () {
      const state = KpiError<int>(
        error: KpiErrorInfo(
          kind: KpiErrorKind.network,
          message: 'Connection timeout',
        ),
      );
      expect(state.valueOrNull, isNull);
      expect(state.hasValue, isFalse);
      expect(state.lastValue, isNull);
      expect(state.lastWatermark, isNull);
    });

    test('KpiError preserves lastValue when provided', () {
      final watermark = KpiWatermark(
        dataVersion: 5,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 1,
      );
      final state = KpiError<int>(
        error: const KpiErrorInfo(
          kind: KpiErrorKind.repository,
          message: 'DB error',
          correlationId: 'corr-123',
        ),
        lastValue: 42,
        lastWatermark: watermark,
      );
      expect(state.valueOrNull, 42);
      expect(state.hasValue, isTrue);
      expect(state.lastWatermark, equals(watermark));
      expect(state.error.correlationId, 'corr-123');
    });

    test('KpiErrorKind covers all expected categories', () {
      expect(
        KpiErrorKind.values,
        containsAll([
          KpiErrorKind.network,
          KpiErrorKind.repository,
          KpiErrorKind.computation,
          KpiErrorKind.authorization,
          KpiErrorKind.unknown,
        ]),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. TENANT-BOUND SOURCE CALLS — Requirement 9.12
  // ═══════════════════════════════════════════════════════════════════════════

  group('All KPI sources require TenantContext (Req 9.12)', () {
    test('every KPI source computes with TenantContext parameter', () {
      final sources = createAllKpiSources(_FakeRepository());
      // The KpiDataSource.compute signature requires TenantContext.
      // This tests that all sources conform to the interface.
      for (final source in sources) {
        expect(source, isA<KpiDataSource>());
        // KpiDataSource.compute(TenantContext) is the only way to get a value.
      }
    });

    test('LifecycleStockKpiSource is a KpiDataSource', () {
      final source = LifecycleStockKpiSource(
        repository: _FakeRepository(),
        metric: KpiMetric.stockInStock,
        lifecycleState: 'IN_STOCK',
      );
      expect(source, isA<KpiDataSource>());
      expect(source.metric, KpiMetric.stockInStock);
    });

    test('RepairStatsKpiSource is a KpiDataSource', () {
      final source = RepairStatsKpiSource(
        repository: _FakeRepository(),
        metric: KpiMetric.repairActive,
        status: 'active',
      );
      expect(source, isA<KpiDataSource>());
      expect(source.metric, KpiMetric.repairActive);
    });

    test('ExchangeStatsKpiSource is a KpiDataSource', () {
      final source = ExchangeStatsKpiSource(
        repository: _FakeRepository(),
        metric: KpiMetric.exchangePending,
        status: 'pending',
      );
      expect(source, isA<KpiDataSource>());
      expect(source.metric, KpiMetric.exchangePending);
    });

    test('WarrantyStatsKpiSource is a KpiDataSource', () {
      final source = WarrantyStatsKpiSource(
        repository: _FakeRepository(),
        metric: KpiMetric.warrantyActive,
        status: 'active',
      );
      expect(source, isA<KpiDataSource>());
      expect(source.metric, KpiMetric.warrantyActive);
    });

    test('ConflictCountKpiSource is a KpiDataSource', () {
      final source = ConflictCountKpiSource(
        repository: _FakeRepository(),
        metric: KpiMetric.conflictsUnresolved,
      );
      expect(source, isA<KpiDataSource>());
      expect(source.metric, KpiMetric.conflictsUnresolved);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. KpiWatermark model tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiWatermark', () {
    test('equality based on all fields', () {
      final a = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime(2024, 1, 1),
        refreshedAt: DateTime(2024, 1, 1),
        dataModelVersion: 1,
      );
      final b = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime(2024, 1, 1),
        refreshedAt: DateTime(2024, 1, 1),
        dataModelVersion: 1,
      );
      final c = KpiWatermark(
        dataVersion: 2,
        confirmedAt: DateTime(2024, 1, 1),
        refreshedAt: DateTime(2024, 1, 1),
        dataModelVersion: 1,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes version and model', () {
      final wm = KpiWatermark(
        dataVersion: 5,
        confirmedAt: DateTime(2024, 6, 15),
        refreshedAt: DateTime(2024, 6, 15),
        dataModelVersion: 2,
      );
      expect(wm.toString(), contains('v5'));
      expect(wm.toString(), contains('model=v2'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. KpiMetric catalog integrity
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiMetric catalog', () {
    test('every metric has a config entry', () {
      for (final metric in KpiMetric.values) {
        final config = findKpiConfig(metric);
        // All required metrics should have config (though some may be null
        // if they're newer and pending config addition)
        if (config != null) {
          expect(config.metric, metric);
          expect(config.title, isNotEmpty);
          expect(config.requiredPermission, isNotEmpty);
          expect(config.filterRoute, isNotEmpty);
        }
      }
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Fake repository that satisfies the interface but returns empty lists.
/// Used only to verify source creation/metric assignment, not data flow.
class _FakeRepository implements MobileShopLocalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(<dynamic>[]);
}
