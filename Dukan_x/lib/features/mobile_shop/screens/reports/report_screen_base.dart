/// MobileShop Report Screen Base — Shared Report Infrastructure (Dart)
///
/// Provides a reusable base widget and helpers for all mobile shop report
/// views. Each report view extends this base to get:
/// - Tenant context resolution with session-lost handling
/// - Permission-scoped access (mobile_shop:reports:view)
/// - Filter chip display for pre-applied KPI filters
/// - Consistent loading/empty/error states
/// - Bounded query support with configurable limits
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';

/// Default query limit for bounded report queries.
const int kReportDefaultLimit = 50;

/// Maximum allowed query limit for report views.
const int kReportMaxLimit = 200;

/// Base class for all mobile shop report screens.
///
/// Provides tenant resolution, filter display, and consistent state
/// management patterns. Subclasses implement [loadData] and [buildContent].
abstract class ReportScreenBase extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;
  final ReportFilterParams? initialFilter;

  const ReportScreenBase({
    super.key,
    required this.resolver,
    required this.repository,
    this.initialFilter,
  });
}

/// Base state for report screens with shared loading/error/empty patterns.
abstract class ReportScreenBaseState<T extends ReportScreenBase>
    extends State<T> {
  ScreenState<dynamic> screenState = const ScreenLoading();
  late ReportFilterParams activeFilter;
  TenantContext? _tenantContext;
  int queryLimit = kReportDefaultLimit;

  @override
  void initState() {
    super.initState();
    activeFilter = widget.initialFilter ?? const ReportFilterParams();
    _resolveTenantAndLoad();
  }

  /// Subclass must provide the report title.
  String get reportTitle;

  /// Subclass must provide the report icon.
  IconData get reportIcon;

  /// Subclass loads data given the tenant context and current filter.
  Future<void> loadData(TenantContext ctx);

  /// Subclass builds the content widget when data is available.
  Widget buildContent(BuildContext context);

  void _resolveTenantAndLoad() {
    final result = widget.resolver.requireMobileShop();
    switch (result) {
      case TenantFailure(:final error):
        setState(() => screenState = ScreenSessionLost(message: error.message));
      case TenantSuccess(:final value):
        _tenantContext = value;
        _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_tenantContext == null) return;
    setState(() => screenState = const ScreenLoading());
    await loadData(_tenantContext!);
  }

  void updateFilter(ReportFilterParams newFilter) {
    setState(() => activeFilter = newFilter);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(reportTitle),
        actions: [
          if (activeFilter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: () => updateFilter(const ReportFilterParams()),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeFilter.hasActiveFilters) _buildFilterBar(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeFilter.activeFilterDescription,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => updateFilter(const ReportFilterParams()),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return screenState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      onData: (_, __, ___) => buildContent(context),
      empty: (message) => _buildEmptyState(context, message),
      error: (code, message, isRetryable) =>
          _buildErrorState(context, message, isRetryable),
      sessionLost: (message) => _buildSessionLost(context, message),
    );
  }

  Widget _buildEmptyState(BuildContext context, String? message) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: message ?? 'No report data available',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reportIcon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'No data available for this report',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (activeFilter.hasActiveFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => updateFilter(const ReportFilterParams()),
                child: const Text('Clear filters to see all data'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message,
    bool isRetryable,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (isRetryable) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionLost(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
