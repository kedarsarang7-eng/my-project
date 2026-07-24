/// MobileShop Brand/Model Sales Report — Sales Aggregated by Brand/Model (Dart)
///
/// Aggregates sales from confirmed IMEI units by brand and model,
/// displaying total units sold per brand/model combination.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Brand/Model Sales Report — sales aggregated by brand and model.
///
/// Shows how many units have been sold per brand/model, sourced from
/// confirmed IMEI units with lifecycle state SOLD.
class BrandModelSalesReportScreen extends ReportScreenBase {
  const BrandModelSalesReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<BrandModelSalesReportScreen> createState() =>
      _BrandModelSalesReportScreenState();
}

class _BrandModelSalesReportScreenState
    extends ReportScreenBaseState<BrandModelSalesReportScreen> {
  List<_BrandModelSalesRow> _rows = [];
  int _totalSold = 0;

  @override
  String get reportTitle => 'Brand/Model Sales';

  @override
  IconData get reportIcon => Icons.sell_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: kReportMaxLimit,
      );

      // Filter to sold units only.
      final soldUnits = records.where((r) => r.entity.lifecycleState == 'SOLD');

      // Aggregate by brand/model.
      final aggregation = <String, _BrandModelSalesRow>{};
      for (final record in soldUnits) {
        final brand = record.entity.brand ?? 'Unknown';
        final model = record.entity.model ?? 'Unknown';

        // Apply optional brand/model filter from KPI navigation.
        if (activeFilter.brand != null && brand != activeFilter.brand) continue;
        if (activeFilter.model != null && model != activeFilter.model) continue;

        final key = '$brand|$model';
        final existing = aggregation[key];
        if (existing != null) {
          aggregation[key] = _BrandModelSalesRow(
            brand: brand,
            model: model,
            unitsSold: existing.unitsSold + 1,
          );
        } else {
          aggregation[key] = _BrandModelSalesRow(
            brand: brand,
            model: model,
            unitsSold: 1,
          );
        }
      }

      final rows = aggregation.values.toList()
        ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

      if (rows.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(
            message: 'No sales data available',
          ),
        );
      } else {
        _rows = rows;
        _totalSold = rows.fold(0, (sum, r) => sum + r.unitsSold);
        setState(
          () => screenState = ScreenData(
            data: _rows,
            lastRefreshed: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      setState(
        () => screenState = ScreenError(
          errorCode: 'REPORT_LOAD_FAILED',
          message: 'Failed to load sales report: $e',
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
              Text(
                'Total Sold: $_totalSold units',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_rows.length} brand/model combinations',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                loadData(widget.resolver.requireMobileShop().valueOrNull!),
            child: ListView.builder(
              itemCount: _rows.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) =>
                  _BrandModelTile(row: _rows[index], totalSold: _totalSold),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandModelSalesRow {
  final String brand;
  final String model;
  final int unitsSold;

  const _BrandModelSalesRow({
    required this.brand,
    required this.model,
    required this.unitsSold,
  });
}

class _BrandModelTile extends StatelessWidget {
  final _BrandModelSalesRow row;
  final int totalSold;

  const _BrandModelTile({required this.row, required this.totalSold});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = totalSold > 0 ? (row.unitsSold / totalSold) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.brand,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(row.model, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '${row.unitsSold}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
