/// MobileShop Return Report — Return Reasons and Disposition (Dart)
///
/// Analyzes device returns by reason and disposition status. Shows why
/// devices were returned and what happened to them afterward.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Return Report — return reasons and disposition analysis.
///
/// KPI card for returnsTotal navigates here with lifecycle 'RETURNED'.
class ReturnReportScreen extends ReportScreenBase {
  const ReturnReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<ReturnReportScreen> createState() => _ReturnReportScreenState();
}

class _ReturnReportScreenState
    extends ReportScreenBaseState<ReturnReportScreen> {
  List<_ReturnItem> _items = [];
  Map<String, int> _reasonCounts = {};

  @override
  String get reportTitle => 'Returns Analysis';

  @override
  IconData get reportIcon => Icons.assignment_return_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: kReportMaxLimit,
      );

      // Filter to returned units.
      final returned = records
          .where((r) => r.entity.lifecycleState == 'RETURNED')
          .toList();

      if (returned.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(message: 'No returns found'),
        );
        return;
      }

      final items = <_ReturnItem>[];
      final reasonCounts = <String, int>{};

      for (final record in returned) {
        final reason = record.entity.condition ?? 'Not specified';
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;

        items.add(
          _ReturnItem(
            imei: record.entity.imei,
            brand: record.entity.brand ?? 'Unknown',
            model: record.entity.model ?? 'Unknown',
            reason: reason,
            disposition: 'Returned',
            returnedAt: record.syncedAt,
          ),
        );
      }

      _items = items;
      _reasonCounts = reasonCounts;
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
          message: 'Failed to load return report: $e',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_items.length} Returns',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text('By Reason:', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _reasonCounts.entries
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
              itemBuilder: (context, index) => _ReturnTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReturnItem {
  final String imei;
  final String brand;
  final String model;
  final String reason;
  final String disposition;
  final DateTime? returnedAt;

  const _ReturnItem({
    required this.imei,
    required this.brand,
    required this.model,
    required this.reason,
    required this.disposition,
    this.returnedAt,
  });
}

class _ReturnTile extends StatelessWidget {
  final _ReturnItem item;

  const _ReturnTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.15),
          child: const Icon(
            Icons.assignment_return,
            color: Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          '${item.brand} ${item.model}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.imei,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Row(
              children: [
                _Chip(label: item.reason, color: Colors.orange),
                const SizedBox(width: 4),
                _Chip(label: item.disposition, color: Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
