/// MobileShop Reports Hub — Navigation Hub for All Reports (Dart)
///
/// Serves as the entry point for `/mobile-shop/reports`. Lists all
/// available report types with their descriptions, allowing users to
/// navigate to specific report views.
///
/// Also supports direct filter-based navigation: when a KPI card's
/// filterRoute points to a specific report (e.g., /mobile-shop/reports/warranty),
/// the hub is bypassed and the user lands directly on that report.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';

/// Report type metadata for the hub display.
class _ReportType {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String routePath;
  final Color color;

  const _ReportType({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.routePath,
    required this.color,
  });
}

/// All available report types shown in the hub.
const _allReports = <_ReportType>[
  _ReportType(
    id: 'imei_history',
    title: 'IMEI History',
    description: 'Lifecycle transitions over time per device',
    icon: Icons.history_outlined,
    routePath: '/mobile-shop/reports/imei-history',
    color: Colors.blue,
  ),
  _ReportType(
    id: 'brand_model_sales',
    title: 'Brand/Model Sales',
    description: 'Sales aggregated by brand and model',
    icon: Icons.sell_outlined,
    routePath: '/mobile-shop/reports/brand-model-sales',
    color: Colors.green,
  ),
  _ReportType(
    id: 'unit_margin',
    title: 'Unit Margin',
    description: 'Per-unit profit margin (sale - acquisition)',
    icon: Icons.trending_up_outlined,
    routePath: '/mobile-shop/reports/unit-margin',
    color: Colors.teal,
  ),
  _ReportType(
    id: 'repair_revenue',
    title: 'Repair Revenue & Status',
    description: 'Revenue from repairs and status distribution',
    icon: Icons.build_outlined,
    routePath: '/mobile-shop/reports/repair-revenue',
    color: Colors.orange,
  ),
  _ReportType(
    id: 'exchange_margin',
    title: 'Exchange Margin',
    description: 'Net margin from exchange transactions',
    icon: Icons.swap_horiz_outlined,
    routePath: '/mobile-shop/reports/exchange-margin',
    color: Colors.purple,
  ),
  _ReportType(
    id: 'warranty',
    title: 'Warranty Report',
    description: 'Active, expiring, and claimed warranties',
    icon: Icons.verified_user_outlined,
    routePath: '/mobile-shop/reports/warranty',
    color: Colors.indigo,
  ),
  _ReportType(
    id: 'used_stock_aging',
    title: 'Used-Stock Aging',
    description: 'Days since intake for second-hand inventory',
    icon: Icons.access_time_outlined,
    routePath: '/mobile-shop/reports/used-stock-aging',
    color: Colors.amber,
  ),
  _ReportType(
    id: 'demo',
    title: 'Demo Units',
    description: 'Demo devices and utilization tracking',
    icon: Icons.devices_other_outlined,
    routePath: '/mobile-shop/reports/demo',
    color: Colors.deepPurple,
  ),
  _ReportType(
    id: 'returns',
    title: 'Returns Analysis',
    description: 'Return reasons and disposition analysis',
    icon: Icons.assignment_return_outlined,
    routePath: '/mobile-shop/reports/returns',
    color: Colors.red,
  ),
  _ReportType(
    id: 'sync',
    title: 'Sync Status',
    description: 'Synchronization status and pending operations',
    icon: Icons.sync_outlined,
    routePath: '/mobile-shop/reports/sync',
    color: Colors.cyan,
  ),
  _ReportType(
    id: 'reconciliation',
    title: 'Reconciliation Exceptions',
    description: 'Failed or stale reconciliation items',
    icon: Icons.sync_problem_outlined,
    routePath: '/mobile-shop/reports/reconciliation',
    color: Colors.deepOrange,
  ),
];

/// Reports Hub Screen — entry point listing all available report types.
class MobileReportsHubScreen extends StatelessWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  const MobileReportsHubScreen({
    super.key,
    required this.resolver,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Reports')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allReports.length,
        itemBuilder: (context, index) {
          final report = _allReports[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => GoRouter.of(context).go(report.routePath),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: report.color.withOpacity(0.15),
                      child: Icon(report.icon, color: report.color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
