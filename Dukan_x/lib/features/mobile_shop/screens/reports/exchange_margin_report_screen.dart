/// MobileShop Exchange Margin Report — Net Margin from Exchanges (Dart)
///
/// Displays net margin from exchange transactions — the financial adjustment
/// between old device trade-in and new device sale.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Exchange Margin Report — net margin from exchange transactions.
///
/// KPI cards for exchange metrics navigate here with status filters.
class ExchangeMarginReportScreen extends ReportScreenBase {
  const ExchangeMarginReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<ExchangeMarginReportScreen> createState() =>
      _ExchangeMarginReportScreenState();
}

class _ExchangeMarginReportScreenState
    extends ReportScreenBaseState<ExchangeMarginReportScreen> {
  List<_ExchangeMarginItem> _items = [];
  int _totalAdjustmentPaise = 0;
  int _completedCount = 0;
  int _pendingCount = 0;

  @override
  String get reportTitle => 'Exchange Margin';

  @override
  IconData get reportIcon => Icons.swap_horiz_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listExchanges(
        ctx,
        status: activeFilter.status,
        limit: queryLimit,
      );

      final confirmed = records.where((r) => r.isServerConfirmed).toList();

      if (confirmed.isEmpty) {
        setState(
          () => screenState = ScreenEmpty(
            message: activeFilter.status != null
                ? 'No exchanges with status "${activeFilter.status}"'
                : 'No exchange data available',
          ),
        );
        return;
      }

      final items = <_ExchangeMarginItem>[];
      int totalAdj = 0;
      int completed = 0;
      int pending = 0;

      for (final record in confirmed) {
        final entity = record.entity;
        final adjustPaise = entity.adjustmentPaise ?? 0;
        totalAdj += adjustPaise;

        final status = entity.status ?? 'unknown';
        if (status == 'completed') completed++;
        if (status == 'pending') pending++;

        items.add(
          _ExchangeMarginItem(
            exchangeId: entity.entityId,
            oldImei: entity.oldDeviceImei ?? '—',
            newImei: entity.newDeviceImei ?? '—',
            adjustmentPaise: adjustPaise,
            status: status,
          ),
        );
      }

      items.sort((a, b) => b.adjustmentPaise.compareTo(a.adjustmentPaise));

      _items = items;
      _totalAdjustmentPaise = totalAdj;
      _completedCount = completed;
      _pendingCount = pending;
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
          message: 'Failed to load exchange margin report: $e',
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net Adjustment', style: theme.textTheme.labelSmall),
                  Text(
                    '₹${(_totalAdjustmentPaise / 100).toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Completed', style: theme.textTheme.labelSmall),
                  Text('$_completedCount', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending', style: theme.textTheme.labelSmall),
                  Text('$_pendingCount', style: theme.textTheme.titleSmall),
                ],
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
              itemBuilder: (context, index) =>
                  _ExchangeMarginTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExchangeMarginItem {
  final String exchangeId;
  final String oldImei;
  final String newImei;
  final int adjustmentPaise;
  final String status;

  const _ExchangeMarginItem({
    required this.exchangeId,
    required this.oldImei,
    required this.newImei,
    required this.adjustmentPaise,
    required this.status,
  });
}

class _ExchangeMarginTile extends StatelessWidget {
  final _ExchangeMarginItem item;

  const _ExchangeMarginTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = item.adjustmentPaise >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.15),
          child: const Icon(Icons.swap_horiz, color: Colors.teal, size: 20),
        ),
        title: Text(
          'Old: ${item.oldImei}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          'New: ${item.newImei}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        trailing: Text(
          '${isPositive ? '+' : ''}₹${(item.adjustmentPaise / 100).toStringAsFixed(0)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}
