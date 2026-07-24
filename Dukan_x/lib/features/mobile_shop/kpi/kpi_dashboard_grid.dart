// ============================================================================
// MOBILE SHOP — KPI DASHBOARD GRID
// ============================================================================
// Displays all enabled KPI cards in a responsive grid layout.
// Filters metrics based on feature policy and tenant permissions.
//
// This widget replaces hardcoded/fabricated dashboard values with live
// confirmation-aware KPI cards sourced from MobileShopLocalRepository.
//
// Requirements: 2.7, 9.1–9.8, 9.13, 12.10; Audit: AF-33, AF-47
// ============================================================================

import 'package:flutter/material.dart';

import 'kpi_dashboard_provider.dart';
import 'kpi_metric.dart';
import 'kpi_state.dart';
import 'live_kpi_card.dart';

/// A responsive grid of Live KPI cards for the mobile shop dashboard.
///
/// Observes [KpiDashboardProvider] state and renders each enabled metric
/// with its current state indicator. Unavailable metrics are hidden unless
/// [showUnavailable] is true.
class KpiDashboardGrid extends StatelessWidget {
  /// The current dashboard state from the provider.
  final KpiDashboardState dashboardState;

  /// Callback to refresh all KPIs.
  final VoidCallback? onRefresh;

  /// Whether to show metrics in the unavailable state.
  final bool showUnavailable;

  /// Optional subset of metrics to display (null = all).
  final Set<KpiMetric>? visibleMetrics;

  const KpiDashboardGrid({
    super.key,
    required this.dashboardState,
    this.onRefresh,
    this.showUnavailable = false,
    this.visibleMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final configs = _filteredConfigs;

    if (configs.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _crossAxisCount(constraints.maxWidth);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: _aspectRatio(crossAxisCount),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final config = configs[index];
                final state = dashboardState[config.metric];
                return LiveKpiCard(config: config, kpiState: state);
              },
            );
          },
        ),
      ],
    );
  }

  /// Header with title and optional refresh button.
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Live KPIs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (dashboardState.lastRefreshedAt != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _formatLastRefresh(dashboardState.lastRefreshedAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (onRefresh != null)
          IconButton(
            icon: dashboardState.isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: dashboardState.isRefreshing ? null : onRefresh,
            tooltip: 'Refresh KPIs',
            iconSize: 20,
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No KPI metrics available for your account.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Filters configs based on visibility and availability.
  List<KpiMetricConfig> get _filteredConfigs {
    return kKpiMetricConfigs.where((config) {
      // Apply visibility filter if specified.
      if (visibleMetrics != null && !visibleMetrics!.contains(config.metric)) {
        return false;
      }

      // Hide unavailable metrics unless requested.
      if (!showUnavailable) {
        final state = dashboardState[config.metric];
        if (state is KpiUnavailable) return false;
      }

      return true;
    }).toList();
  }

  /// Responsive cross-axis count based on available width.
  int _crossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    if (width >= 500) return 2;
    return 1;
  }

  /// Aspect ratio based on column count for consistent sizing.
  double _aspectRatio(int columns) {
    if (columns >= 3) return 2.2;
    if (columns == 2) return 2.5;
    return 3.5;
  }

  String _formatLastRefresh(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }
}
