/// MobileShop Used-Stock Aging Report — Days Since Intake (Dart)
///
/// Displays days since intake for second-hand inventory items,
/// helping identify slow-moving used stock that may need price adjustment.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Used-Stock Aging Report — days since intake for second-hand inventory.
///
/// KPI cards for used stock (intake pipeline, available) navigate here.
class UsedStockAgingReportScreen extends ReportScreenBase {
  const UsedStockAgingReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<UsedStockAgingReportScreen> createState() =>
      _UsedStockAgingReportScreenState();
}

class _UsedStockAgingReportScreenState
    extends ReportScreenBaseState<UsedStockAgingReportScreen> {
  List<_UsedStockAgingItem> _items = [];
  int _avgDays = 0;
  int _maxDays = 0;

  @override
  String get reportTitle => 'Used Stock Aging';

  @override
  IconData get reportIcon => Icons.access_time_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: kReportMaxLimit,
      );

      // Filter to second-hand/used units.
      final usedStates = {'USED_AVAILABLE', 'USED_INTAKE'};
      final statusFilter = activeFilter.status;

      var usedUnits = records.where(
        (r) => usedStates.contains(r.entity.lifecycleState),
      );

      // Apply additional status filter if from KPI card.
      if (statusFilter == 'intake') {
        usedUnits = usedUnits.where(
          (r) => r.entity.lifecycleState == 'USED_INTAKE',
        );
      } else if (statusFilter == 'available') {
        usedUnits = usedUnits.where(
          (r) => r.entity.lifecycleState == 'USED_AVAILABLE',
        );
      }

      final now = DateTime.now();
      final items = <_UsedStockAgingItem>[];

      for (final record in usedUnits) {
        final intakeDate = record.entity.createdAt;
        final daysSinceIntake = now.difference(intakeDate).inDays;

        items.add(
          _UsedStockAgingItem(
            imei: record.entity.imei,
            brand: record.entity.brand ?? 'Unknown',
            model: record.entity.model ?? 'Unknown',
            daysSinceIntake: daysSinceIntake,
            intakeDate: intakeDate,
            lifecycleState: record.entity.lifecycleState,
          ),
        );
      }

      items.sort((a, b) => b.daysSinceIntake.compareTo(a.daysSinceIntake));

      if (items.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(message: 'No used stock found'),
        );
        return;
      }

      _items = items;
      _maxDays = items.first.daysSinceIntake;
      _avgDays =
          items.fold(0, (sum, i) => sum + i.daysSinceIntake) ~/ items.length;
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
          message: 'Failed to load used stock aging: $e',
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$_avgDays',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Avg Days', style: theme.textTheme.labelSmall),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$_maxDays',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _maxDays > 90 ? Colors.red : null,
                    ),
                  ),
                  Text('Max Days', style: theme.textTheme.labelSmall),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${_items.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Total Units', style: theme.textTheme.labelSmall),
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
              itemBuilder: (context, index) => _AgingTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsedStockAgingItem {
  final String imei;
  final String brand;
  final String model;
  final int daysSinceIntake;
  final DateTime? intakeDate;
  final String lifecycleState;

  const _UsedStockAgingItem({
    required this.imei,
    required this.brand,
    required this.model,
    required this.daysSinceIntake,
    this.intakeDate,
    required this.lifecycleState,
  });
}

class _AgingTile extends StatelessWidget {
  final _UsedStockAgingItem item;

  const _AgingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agingColor = item.daysSinceIntake > 90
        ? Colors.red
        : item.daysSinceIntake > 60
        ? Colors.orange
        : item.daysSinceIntake > 30
        ? Colors.amber
        : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: agingColor.withOpacity(0.15),
          child: Text(
            '${item.daysSinceIntake}d',
            style: TextStyle(
              color: agingColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
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
        trailing: item.intakeDate != null
            ? Text(
                '${item.intakeDate!.day}/${item.intakeDate!.month}/${item.intakeDate!.year}',
                style: theme.textTheme.labelSmall,
              )
            : null,
      ),
    );
  }
}
