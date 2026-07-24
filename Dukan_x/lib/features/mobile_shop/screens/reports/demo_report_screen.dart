/// MobileShop Demo Report — Demo Units and Utilization (Dart)
///
/// Displays demo units and their utilization status. Shows which units
/// are currently assigned as demo devices and their condition.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Demo Report — demo units and their utilization.
///
/// KPI card for stockDemo navigates here with lifecycle filter 'DEMO'.
class DemoReportScreen extends ReportScreenBase {
  const DemoReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<DemoReportScreen> createState() => _DemoReportScreenState();
}

class _DemoReportScreenState extends ReportScreenBaseState<DemoReportScreen> {
  List<_DemoItem> _items = [];

  @override
  String get reportTitle => 'Demo Units';

  @override
  IconData get reportIcon => Icons.devices_other_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: queryLimit,
      );

      // Filter to demo units.
      final demoUnits = records
          .where((r) => r.entity.lifecycleState == 'DEMO')
          .toList();

      if (demoUnits.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(message: 'No demo units found'),
        );
        return;
      }

      final now = DateTime.now();
      _items = demoUnits.map((r) {
        final assignedDate = r.entity.updatedAt;
        final daysAsDemo = now.difference(assignedDate).inDays;

        return _DemoItem(
          imei: r.entity.imei,
          brand: r.entity.brand ?? 'Unknown',
          model: r.entity.model ?? 'Unknown',
          daysAsDemo: daysAsDemo,
          assignedDate: assignedDate,
          condition: r.entity.condition ?? 'Good',
        );
      }).toList();

      _items.sort((a, b) => b.daysAsDemo.compareTo(a.daysAsDemo));

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
          message: 'Failed to load demo report: $e',
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
              Text(
                '${_items.length} Demo Units',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                Text(
                  'Avg ${_items.fold(0, (sum, i) => sum + i.daysAsDemo) ~/ _items.length} days',
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
              itemBuilder: (context, index) => _DemoTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoItem {
  final String imei;
  final String brand;
  final String model;
  final int daysAsDemo;
  final DateTime? assignedDate;
  final String condition;

  const _DemoItem({
    required this.imei,
    required this.brand,
    required this.model,
    required this.daysAsDemo,
    this.assignedDate,
    required this.condition,
  });
}

class _DemoTile extends StatelessWidget {
  final _DemoItem item;

  const _DemoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withOpacity(0.15),
          child: const Icon(Icons.devices, color: Colors.purple, size: 20),
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
            Text(
              'Condition: ${item.condition}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.daysAsDemo}d',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: item.daysAsDemo > 90 ? Colors.orange : null,
              ),
            ),
            Text('as demo', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
