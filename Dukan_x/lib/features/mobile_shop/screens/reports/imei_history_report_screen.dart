/// MobileShop IMEI History Report — Lifecycle Transitions Over Time (Dart)
///
/// Displays lifecycle transitions over time per device. Supports filtering
/// by lifecycle state (from KPI card navigation) and bounded queries.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// IMEI History Report — lifecycle transitions for all devices over time.
///
/// Shows when devices moved between states (IN_STOCK → SOLD, etc.).
/// KPI cards for lifecycle stock metrics navigate here with a pre-applied
/// lifecycle filter.
class ImeiHistoryReportScreen extends ReportScreenBase {
  const ImeiHistoryReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<ImeiHistoryReportScreen> createState() =>
      _ImeiHistoryReportScreenState();
}

class _ImeiHistoryReportScreenState
    extends ReportScreenBaseState<ImeiHistoryReportScreen> {
  List<_ImeiHistoryItem> _items = [];

  @override
  String get reportTitle => 'IMEI History';

  @override
  IconData get reportIcon => Icons.history_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      final records = await widget.repository.listImeiUnits(
        ctx,
        confirmationStatus: ConfirmationStatus.serverConfirmed,
        limit: queryLimit,
      );

      // Apply lifecycle filter if specified.
      final filtered = activeFilter.lifecycle != null
          ? records
                .where((r) => r.entity.lifecycleState == activeFilter.lifecycle)
                .toList()
          : records;

      if (filtered.isEmpty) {
        setState(
          () => screenState = ScreenEmpty(
            message: activeFilter.lifecycle != null
                ? 'No devices with lifecycle "${activeFilter.lifecycle}"'
                : 'No IMEI history available',
          ),
        );
      } else {
        _items = filtered
            .map(
              (r) => _ImeiHistoryItem(
                imei: r.entity.imei,
                brand: r.entity.brand ?? 'Unknown',
                model: r.entity.model ?? 'Unknown',
                lifecycleState: r.entity.lifecycleState,
                lastTransitionAt: r.syncedAt,
                serverVersion: r.serverVersion,
                isConfirmed: r.isServerConfirmed,
              ),
            )
            .toList();
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
          message: 'Failed to load IMEI history: $e',
          isRetryable: true,
        ),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async =>
          loadData(widget.resolver.requireMobileShop().valueOrNull!),
      child: ListView.builder(
        itemCount: _items.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) => _ImeiHistoryTile(item: _items[index]),
      ),
    );
  }
}

class _ImeiHistoryItem {
  final String imei;
  final String brand;
  final String model;
  final String lifecycleState;
  final DateTime? lastTransitionAt;
  final int serverVersion;
  final bool isConfirmed;

  const _ImeiHistoryItem({
    required this.imei,
    required this.brand,
    required this.model,
    required this.lifecycleState,
    this.lastTransitionAt,
    required this.serverVersion,
    required this.isConfirmed,
  });
}

class _ImeiHistoryTile extends StatelessWidget {
  final _ImeiHistoryItem item;

  const _ImeiHistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _lifecycleColor(theme).withOpacity(0.15),
          child: Icon(
            Icons.smartphone,
            color: _lifecycleColor(theme),
            size: 20,
          ),
        ),
        title: Text(
          item.imei,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
        subtitle: Text('${item.brand} ${item.model}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _LifecycleChip(state: item.lifecycleState),
            const SizedBox(height: 4),
            Text('v${item.serverVersion}', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Color _lifecycleColor(ThemeData theme) {
    return switch (item.lifecycleState) {
      'IN_STOCK' => Colors.green,
      'SOLD' => Colors.blue,
      'RESERVED' => Colors.orange,
      'RETURNED' => Colors.red,
      'DEMO' => Colors.purple,
      'IN_SERVICE' => Colors.amber,
      'EXCHANGED' => Colors.teal,
      'DAMAGED' => Colors.red.shade900,
      'RETIRED' => Colors.grey,
      _ => theme.colorScheme.primary,
    };
  }
}

class _LifecycleChip extends StatelessWidget {
  final String state;

  const _LifecycleChip({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
