/// MobileShop Unit Margin Report — Per-Unit Profit Margin (Dart)
///
/// Displays per-unit profit margin (sale price - acquisition cost) for
/// confirmed sold devices. Sources from confirmed local repository data.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Unit Margin Report — per-unit profit margin (sale - acquisition).
///
/// Shows net margin for each sold device, enabling profitability analysis
/// by brand, model, or date range.
class UnitMarginReportScreen extends ReportScreenBase {
  const UnitMarginReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<UnitMarginReportScreen> createState() => _UnitMarginReportScreenState();
}

class _UnitMarginReportScreenState
    extends ReportScreenBaseState<UnitMarginReportScreen> {
  List<_UnitMarginItem> _items = [];
  int _totalMarginPaise = 0;
  int _avgMarginPaise = 0;

  @override
  String get reportTitle => 'Unit Margin';

  @override
  IconData get reportIcon => Icons.trending_up_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: kReportMaxLimit,
      );

      // Filter to sold units that have pricing data.
      final soldUnits = records.where((r) => r.entity.lifecycleState == 'SOLD');

      final items = <_UnitMarginItem>[];
      for (final record in soldUnits) {
        final salePricePaise = record.entity.salePricePaise;
        final acquisitionPaise = record.entity.acquisitionCostPaise;

        if (salePricePaise == null || acquisitionPaise == null) continue;

        // Apply brand/model filter if specified.
        if (activeFilter.brand != null &&
            record.entity.brand != activeFilter.brand)
          continue;

        final marginPaise = salePricePaise - acquisitionPaise;
        items.add(
          _UnitMarginItem(
            imei: record.entity.imei,
            brand: record.entity.brand ?? 'Unknown',
            model: record.entity.model ?? 'Unknown',
            salePricePaise: salePricePaise,
            acquisitionPricePaise: acquisitionPaise,
            marginPaise: marginPaise,
          ),
        );
      }

      items.sort((a, b) => b.marginPaise.compareTo(a.marginPaise));

      if (items.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(
            message: 'No margin data available for sold units',
          ),
        );
      } else {
        _items = items;
        _totalMarginPaise = items.fold(0, (sum, i) => sum + i.marginPaise);
        _avgMarginPaise = _totalMarginPaise ~/ items.length;
        setState(
          () => screenState = ScreenData(
            data: _items,
            lastRefreshed: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      setState(
        () => screenState = ScreenError(
          errorCode: 'REPORT_LOAD_FAILED',
          message: 'Failed to load margin report: $e',
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
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Margin', style: theme.textTheme.labelSmall),
                  Text(
                    _formatRupees(_totalMarginPaise),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _totalMarginPaise >= 0
                          ? Colors.green.shade700
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Avg Margin', style: theme.textTheme.labelSmall),
                  Text(
                    _formatRupees(_avgMarginPaise),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${_items.length} units',
                style: theme.textTheme.labelMedium,
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
                  _UnitMarginTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRupees(int paise) {
    final rupees = paise / 100;
    if (rupees.abs() >= 100000) {
      return '₹${(rupees / 100000).toStringAsFixed(1)}L';
    }
    if (rupees.abs() >= 1000) {
      return '₹${(rupees / 1000).toStringAsFixed(1)}K';
    }
    return '₹${rupees.toStringAsFixed(0)}';
  }
}

class _UnitMarginItem {
  final String imei;
  final String brand;
  final String model;
  final int salePricePaise;
  final int acquisitionPricePaise;
  final int marginPaise;

  const _UnitMarginItem({
    required this.imei,
    required this.brand,
    required this.model,
    required this.salePricePaise,
    required this.acquisitionPricePaise,
    required this.marginPaise,
  });

  double get marginPercent => acquisitionPricePaise > 0
      ? (marginPaise / acquisitionPricePaise) * 100
      : 0;
}

class _UnitMarginTile extends StatelessWidget {
  final _UnitMarginItem item;

  const _UnitMarginTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = item.marginPaise >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isPositive ? Colors.green : Colors.red).withOpacity(
            0.15,
          ),
          child: Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          '${item.brand} ${item.model}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.imei,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${(item.marginPaise / 100).toStringAsFixed(0)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            Text(
              '${item.marginPercent.toStringAsFixed(1)}%',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
