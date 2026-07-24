// ============================================================================
// MOBILE SHOP — KPI DASHBOARD PROVIDER
// ============================================================================
// Orchestrates all KPI data sources for the mobile shop dashboard.
// Manages per-metric state, applies feature-policy gating, ensures
// tenant-bound access, and respects confirmation semantics.
//
// A metric's KPI is shown as:
//  - Loading: no confirmed data yet
//  - Current: fresh confirmed data with watermark
//  - Empty: confirmed but zero matching records
//  - Stale: confirmed data but watermark exceeds threshold
//  - Unavailable: feature not enabled or permission absent
//  - Error: fetch/computation failure
//
// Requirements: 2.7, 9.1–9.8, 9.13, 12.10; Audit: AF-33, AF-47
// ============================================================================

import 'package:flutter/foundation.dart';

import '../auth/tenant_context.dart';
import '../auth/tenant_context_resolver.dart';
import '../config/feature_policy_config.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'kpi_metric.dart';
import 'kpi_provider.dart';
import 'kpi_state.dart';

/// The complete dashboard KPI state for all metrics.
@immutable
class KpiDashboardState {
  /// Per-metric state map.
  final Map<KpiMetric, KpiState<int>> metrics;

  /// When the dashboard was last fully refreshed.
  final DateTime? lastRefreshedAt;

  /// Whether a refresh is currently in progress.
  final bool isRefreshing;

  const KpiDashboardState({
    required this.metrics,
    this.lastRefreshedAt,
    this.isRefreshing = false,
  });

  /// Creates an initial state with all metrics in loading.
  factory KpiDashboardState.initial() => KpiDashboardState(
    metrics: {for (final m in KpiMetric.values) m: const KpiLoading()},
  );

  /// Returns the state for a specific metric.
  KpiState<int> operator [](KpiMetric metric) =>
      metrics[metric] ?? const KpiLoading();

  /// Returns a copy with updated metrics.
  KpiDashboardState copyWith({
    Map<KpiMetric, KpiState<int>>? metrics,
    DateTime? lastRefreshedAt,
    bool? isRefreshing,
  }) => KpiDashboardState(
    metrics: metrics ?? this.metrics,
    lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );
}

/// Manages the dashboard KPI state for a single tenant session.
///
/// This provider:
/// - Requires valid TenantContext before computing any metric
/// - Checks feature policy and permissions before each metric
/// - Only uses confirmed (not pending) local data
/// - Reports proper state transitions per Req 9.1–9.6
/// - Never returns fabricated/hardcoded values (Audit AF-33, AF-47)
class KpiDashboardProvider extends ChangeNotifier {
  final TenantContextResolver _tenantResolver;
  final MobileShopLocalRepository _repository;
  final FeaturePolicyConfig _featurePolicy;

  late List<KpiDataSource> _sources;
  KpiDashboardState _state = KpiDashboardState.initial();

  KpiDashboardProvider({
    required TenantContextResolver tenantResolver,
    required MobileShopLocalRepository repository,
    FeaturePolicyConfig featurePolicy = kFeaturePolicyConfig,
  }) : _tenantResolver = tenantResolver,
       _repository = repository,
       _featurePolicy = featurePolicy {
    _sources = createAllKpiSources(_repository);
  }

  /// The current dashboard state.
  KpiDashboardState get state => _state;

  /// Refreshes ALL KPI metrics from the local repository.
  ///
  /// This method:
  /// 1. Resolves the current tenant context (fail-closed if absent)
  /// 2. For each metric, checks feature policy and permission
  /// 3. Computes from ONLY confirmed data
  /// 4. Updates state with appropriate KpiState per metric
  Future<void> refresh() async {
    final tenantResult = _tenantResolver.requireMobileShop();

    if (tenantResult.isFailure) {
      // No valid mobile shop context — all metrics unavailable.
      _state = KpiDashboardState(
        metrics: {
          for (final m in KpiMetric.values)
            m: const KpiUnavailable(reason: 'Not authenticated as mobile shop'),
        },
        lastRefreshedAt: _state.lastRefreshedAt,
        isRefreshing: false,
      );
      notifyListeners();
      return;
    }

    final ctx = tenantResult.valueOrNull!;

    // Mark refreshing state.
    _state = _state.copyWith(isRefreshing: true);
    notifyListeners();

    final newMetrics = <KpiMetric, KpiState<int>>{};

    for (final source in _sources) {
      final config = findKpiConfig(source.metric);
      if (config == null) {
        newMetrics[source.metric] = const KpiLoading();
        continue;
      }

      // Check feature policy.
      if (config.requiredFeature != null) {
        final feature = _featurePolicy.getFeature(config.requiredFeature!);
        if (feature == null || !feature.enabledByDefault) {
          newMetrics[source.metric] = KpiUnavailable(
            reason: 'Feature ${config.requiredFeature} not enabled',
          );
          continue;
        }
      }

      // Check permission.
      if (!ctx.hasPermission(config.requiredPermission)) {
        newMetrics[source.metric] = KpiUnavailable(
          reason: 'Permission ${config.requiredPermission} not granted',
        );
        continue;
      }

      // Compute from confirmed local data.
      newMetrics[source.metric] = await source.compute(ctx);
    }

    // Fill any metrics not covered by sources.
    for (final metric in KpiMetric.values) {
      if (!newMetrics.containsKey(metric)) {
        newMetrics[metric] = const KpiLoading();
      }
    }

    _state = KpiDashboardState(
      metrics: newMetrics,
      lastRefreshedAt: DateTime.now(),
      isRefreshing: false,
    );
    notifyListeners();
  }

  /// Refreshes a single metric.
  Future<void> refreshMetric(KpiMetric metric) async {
    final tenantResult = _tenantResolver.requireMobileShop();
    if (tenantResult.isFailure) return;

    final ctx = tenantResult.valueOrNull!;
    final source = _sources.where((s) => s.metric == metric).firstOrNull;
    if (source == null) return;

    final config = findKpiConfig(metric);
    if (config == null) return;

    // Check feature and permission gating.
    if (config.requiredFeature != null) {
      final feature = _featurePolicy.getFeature(config.requiredFeature!);
      if (feature == null || !feature.enabledByDefault) {
        _updateSingleMetric(
          metric,
          KpiUnavailable(
            reason: 'Feature ${config.requiredFeature} not enabled',
          ),
        );
        return;
      }
    }
    if (!ctx.hasPermission(config.requiredPermission)) {
      _updateSingleMetric(
        metric,
        KpiUnavailable(
          reason: 'Permission ${config.requiredPermission} not granted',
        ),
      );
      return;
    }

    final result = await source.compute(ctx);
    _updateSingleMetric(metric, result);
  }

  void _updateSingleMetric(KpiMetric metric, KpiState<int> newState) {
    final updated = Map<KpiMetric, KpiState<int>>.from(_state.metrics);
    updated[metric] = newState;
    _state = _state.copyWith(metrics: updated);
    notifyListeners();
  }

  /// Clears all state (call on tenant switch or sign-out).
  void reset() {
    _state = KpiDashboardState.initial();
    notifyListeners();
  }
}
