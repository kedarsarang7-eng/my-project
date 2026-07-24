/// KPI Dashboard Provider Tests — Task 15.4
///
/// Tests cover:
/// - Feature policy gating (KpiUnavailable for disabled features)
/// - Permission gating (KpiUnavailable for missing permissions)
/// - Tenant resolution failure handling
/// - Dashboard-wide refresh and reset behavior
///
/// Requirements validated: 9.1–9.8, 9.13, 13.1
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/tenant_context_resolver.dart';
import 'package:dukanx/features/mobile_shop/config/feature_policy_config.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_dashboard_provider.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_metric.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_state.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';
import 'package:dukanx/features/mobile_shop/repository/mobile_shop_local_repository.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Dashboard Provider — Unavailable semantics (Req 9.5)
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiDashboardProvider unavailable semantics', () {
    test('all metrics unavailable when tenant resolver fails', () async {
      final resolver = _FailingTenantResolver();
      final repository = _NoDataRepository();

      final provider = KpiDashboardProvider(
        tenantResolver: resolver,
        repository: repository,
      );

      await provider.refresh();

      // All metrics should be Unavailable
      for (final metric in KpiMetric.values) {
        expect(provider.state[metric], isA<KpiUnavailable<int>>());
      }
    });

    test(
      'metric marked unavailable when required feature is disabled',
      () async {
        final resolver = _SuccessTenantResolver(_fullPermsTenant);
        final repository = _NoDataRepository();

        // Create a policy where EXCHANGES is disabled
        const restrictedPolicy = FeaturePolicyConfig(
          features: [
            FeaturePolicyEntry(
              featureId: 'IMEI_TRACKING',
              name: 'IMEI',
              enabledByDefault: true,
              requiredCapability: 'imei_tracking',
              onlineRequired: false,
              description: 'IMEI tracking',
            ),
            FeaturePolicyEntry(
              featureId: 'SERVICE_JOBS',
              name: 'Service',
              enabledByDefault: true,
              requiredCapability: 'service_jobs',
              onlineRequired: false,
              description: 'Service jobs',
            ),
            FeaturePolicyEntry(
              featureId: 'EXCHANGES',
              name: 'Exchanges',
              enabledByDefault: false, // disabled!
              requiredCapability: 'exchanges',
              onlineRequired: false,
              description: 'Exchange feature',
            ),
          ],
        );

        final provider = KpiDashboardProvider(
          tenantResolver: resolver,
          repository: repository,
          featurePolicy: restrictedPolicy,
        );

        await provider.refresh();

        // Exchange metrics should be unavailable due to disabled feature
        expect(
          provider.state[KpiMetric.exchangePending],
          isA<KpiUnavailable<int>>(),
        );
        expect(
          provider.state[KpiMetric.exchangeValuePaise],
          isA<KpiUnavailable<int>>(),
        );
      },
    );

    test(
      'metric marked unavailable when user lacks required permission',
      () async {
        // Tenant WITHOUT exchange:view permission
        const limitedTenant = TenantContext(
          tenantId: 'tenant-002',
          businessId: 'biz-002',
          subjectId: 'user-002',
          businessType: MobileShopBusinessType.mobileShop,
          permissions: {
            MobileShopPermissions.imeiView,
            MobileShopPermissions.serviceView,
            // Exchange permission intentionally absent
          },
          correlationId: 'corr-002',
        );

        final resolver = _SuccessTenantResolver(limitedTenant);
        final repository = _NoDataRepository();

        final provider = KpiDashboardProvider(
          tenantResolver: resolver,
          repository: repository,
        );

        await provider.refresh();

        // Exchange metrics should be unavailable due to permission
        expect(
          provider.state[KpiMetric.exchangePending],
          isA<KpiUnavailable<int>>(),
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Dashboard state management
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiDashboardState', () {
    test('initial state has all metrics in Loading', () {
      final state = KpiDashboardState.initial();
      for (final metric in KpiMetric.values) {
        expect(state[metric], isA<KpiLoading<int>>());
      }
      expect(state.lastRefreshedAt, isNull);
      expect(state.isRefreshing, isFalse);
    });

    test('operator [] returns Loading for unknown metrics', () {
      final state = KpiDashboardState(metrics: {});
      expect(state[KpiMetric.stockInStock], isA<KpiLoading<int>>());
    });

    test('copyWith preserves unmodified fields', () {
      final now = DateTime.now();
      final state = KpiDashboardState(
        metrics: {KpiMetric.stockInStock: const KpiLoading()},
        lastRefreshedAt: now,
        isRefreshing: false,
      );

      final refreshing = state.copyWith(isRefreshing: true);
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.lastRefreshedAt, now);
      expect(refreshing.metrics, state.metrics);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Provider reset behavior
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiDashboardProvider reset', () {
    test('reset clears all state to initial Loading', () async {
      final resolver = _SuccessTenantResolver(_fullPermsTenant);
      final repository = _NoDataRepository();

      final provider = KpiDashboardProvider(
        tenantResolver: resolver,
        repository: repository,
      );

      await provider.refresh();
      // After refresh, lastRefreshedAt should be set
      expect(provider.state.lastRefreshedAt, isNotNull);

      provider.reset();

      // After reset, all metrics back to Loading, no lastRefreshedAt
      for (final metric in KpiMetric.values) {
        expect(provider.state[metric], isA<KpiLoading<int>>());
      }
      expect(provider.state.lastRefreshedAt, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Provider refresh lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  group('KpiDashboardProvider refresh lifecycle', () {
    test('refresh sets lastRefreshedAt after completion', () async {
      final resolver = _SuccessTenantResolver(_fullPermsTenant);
      final repository = _NoDataRepository();

      final provider = KpiDashboardProvider(
        tenantResolver: resolver,
        repository: repository,
      );

      await provider.refresh();
      expect(provider.state.lastRefreshedAt, isNotNull);
      expect(provider.state.isRefreshing, isFalse);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test doubles
// ═══════════════════════════════════════════════════════════════════════════════

/// Full-permissions mobile shop tenant for testing.
const _fullPermsTenant = TenantContext(
  tenantId: 'tenant-001',
  businessId: 'biz-001',
  subjectId: 'user-001',
  businessType: MobileShopBusinessType.mobileShop,
  permissions: {
    MobileShopPermissions.imeiView,
    MobileShopPermissions.imeiManage,
    MobileShopPermissions.serviceView,
    MobileShopPermissions.exchangeView,
    MobileShopPermissions.warrantyView,
    MobileShopPermissions.secondHandView,
    MobileShopPermissions.financeView,
    MobileShopPermissions.reportsView,
    MobileShopPermissions.settingsView,
    MobileShopPermissions.auditView,
  },
  correlationId: 'corr-001',
);

class _FailingTenantResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> requireMobileShop() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantResult<TenantContext> require() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantContext? get current => null;

  @override
  void invalidate() {}
}

class _SuccessTenantResolver implements TenantContextResolver {
  final TenantContext _ctx;
  _SuccessTenantResolver(this._ctx);

  @override
  TenantResult<TenantContext> requireMobileShop() => TenantSuccess(_ctx);

  @override
  TenantResult<TenantContext> require() => TenantSuccess(_ctx);

  @override
  TenantContext? get current => _ctx;

  @override
  void invalidate() {}
}

/// Repository that returns empty data (no confirmed records).
/// Simulates a fresh tenant with no synced data.
class _NoDataRepository implements MobileShopLocalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(<dynamic>[]);
}
