/// MobileShop Repair Revenue/Status Report (Dart)
///
/// Displays revenue from repairs and status distribution across service
/// jobs. Sources from confirmed local repository data only.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Repair Revenue/Status Report — revenue and status distribution.
///
/// KPI cards for repair metrics (active, overdue, completed) navigate
/// here with a pre-applied status filter.
class RepairRevenueReportScreen extends ReportScreenBase {
  const RepairRevenueReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<RepairRevenueReportScreen> createState() =>
      _RepairRevenueReportScreenState();
}

class _RepairRevenueReportScreenState
    extends ReportScreenBaseState<RepairRevenueReportScreen> {
  List<_RepairReportItem> _items = [];
  Map<String, int> _statusCounts = {};
  int _totalRevenuePaise = 0;

  @override
  String get reportTitle => 'Repair Revenue & Status';

  @override
  IconData get reportIcon => Icons.build_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listServiceJobs(
        ctx,
        status: activeFilter.status,
        limit: queryLimit,
      );

      // Only count confirmed records for revenue.
      final confirmed = records.where((r) => r.isServerConfirmed).toList();

      if (confirmed.isEmpty) {
        setState(
          () => screenState = ScreenEmpty(
            message: activeFilter.status != null
                ? 'No repair jobs with status "${activeFilter.status}"'
                : 'No repair data available',
          ),
        );
        return;
      }

      // Build items and aggregate stats.
      final items = <_RepairReportItem>[];
      final statusCounts = <String, int>{};
      int totalRevenue = 0;

      for (final record in confirmed) {
        final entity = record.entity;
        final status = entity.status ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        final revenuePaise = entity.actualCostPaise ?? 0;
        totalRevenue += revenuePaise;

        items.add(
          _RepairReportItem(
            jobId: entity.entityId,
            customerName: entity.customerName ?? 'Unknown',
            imei: entity.imei ?? '—',
            status: status,
            revenuePaise: revenuePaise,
            createdAt: entity.createdAt,
          ),
        );
      }

      _items = items;
      _statusCounts = statusCounts;
      _totalRevenuePaise = totalRevenue;
      setState(
        () => screenState = ScreenData(
          data: _items,
          lastRefreshed: DateTime.now(),
        ),
      );
    } catch (e) {
      setState(
        () => screenState = ScreenError(
          errorCode: 'REPORT_LOAD_FAILED',
          message: 'Failed to load repair report: $e',
          isRetryable: true,
        ),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Revenue', style: theme.textTheme.labelSmall),
                      Text(
                        '₹${(_totalRevenuePaise / 100).toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${_items.length} jobs',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Status distribution
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _statusCounts.entries
                    .map(
                      (e) => Chip(
                        label: Text(
                          '${e.key}: ${e.value}',
                          style: theme.textTheme.labelSmall,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                loadData(widget.resolver.requireMobileShop().valueOrNull!),
            child: ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) => _RepairTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RepairReportItem {
  final String jobId;
  final String customerName;
  final String imei;
  final String status;
  final int revenuePaise;
  final DateTime? createdAt;

  const _RepairReportItem({
    required this.jobId,
    required this.customerName,
    required this.imei,
    required this.status,
    required this.revenuePaise,
    this.createdAt,
  });
}

class _RepairTile extends StatelessWidget {
  final _RepairReportItem item;

  const _RepairTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(theme).withOpacity(0.15),
          child: Icon(Icons.build, color: _statusColor(theme), size: 20),
        ),
        title: Text(
          item.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMEI: ${item.imei}', style: theme.textTheme.bodySmall),
            _StatusChip(label: item.status, color: _statusColor(theme)),
          ],
        ),
        trailing: item.revenuePaise > 0
            ? Text(
                '₹${(item.revenuePaise / 100).toStringAsFixed(0)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              )
            : null,
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    return switch (item.status) {
      'active' => Colors.blue,
      'overdue' => Colors.orange,
      'completed' => Colors.green,
      _ => theme.colorScheme.primary,
    };
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
