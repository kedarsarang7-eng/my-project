/// MobileShop Sync Report — Synchronization Status and Pending Ops (Dart)
///
/// Displays synchronization status, pending outbox mutations, and
/// failed operations. Helps diagnose connectivity/sync issues.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Sync Report — synchronization status and pending operations.
///
/// Shows outbox mutations (queued, sending, failed) and sync checkpoints.
class SyncReportScreen extends ReportScreenBase {
  const SyncReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<SyncReportScreen> createState() => _SyncReportScreenState();
}

class _SyncReportScreenState extends ReportScreenBaseState<SyncReportScreen> {
  List<_SyncItem> _items = [];
  int _queuedCount = 0;
  int _sendingCount = 0;
  int _failedCount = 0;

  @override
  String get reportTitle => 'Sync Status';

  @override
  IconData get reportIcon => Icons.sync_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      // Fetch outbox mutations for status overview.
      final mutations = await widget.repository.getNextMutations(
        ctx,
        kReportMaxLimit,
      );

      if (mutations.isEmpty) {
        setState(
          () => screenState = const ScreenEmpty(
            message: 'No pending sync operations',
          ),
        );
        return;
      }

      final items = <_SyncItem>[];
      int queued = 0, sending = 0, failed = 0;

      for (final mutation in mutations) {
        final status = mutation.status;
        if (status == OutboxStatus.queued) queued++;
        if (status == OutboxStatus.sending) sending++;
        if (status == OutboxStatus.failed) failed++;

        // Apply status filter if from KPI navigation.
        if (activeFilter.status != null && status != activeFilter.status) {
          continue;
        }

        items.add(
          _SyncItem(
            operationId: mutation.operationId,
            entityType: mutation.entityType,
            action: 'MUTATION',
            status: status,
            errorMessage: null,
            createdAt: mutation.createdAt,
            retryCount: mutation.retryCount,
          ),
        );
      }

      _items = items;
      _queuedCount = queued;
      _sendingCount = sending;
      _failedCount = failed;
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
          message: 'Failed to load sync report: $e',
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
              _SummaryColumn(
                label: 'Queued',
                value: _queuedCount,
                color: Colors.blue,
              ),
              _SummaryColumn(
                label: 'Sending',
                value: _sendingCount,
                color: Colors.amber,
              ),
              _SummaryColumn(
                label: 'Failed',
                value: _failedCount,
                color: Colors.red,
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
              itemBuilder: (context, index) => _SyncTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _SyncItem {
  final String operationId;
  final String entityType;
  final String action;
  final String status;
  final String? errorMessage;
  final DateTime? createdAt;
  final int retryCount;

  const _SyncItem({
    required this.operationId,
    required this.entityType,
    required this.action,
    required this.status,
    this.errorMessage,
    this.createdAt,
    required this.retryCount,
  });
}

class _SyncTile extends StatelessWidget {
  final _SyncItem item;

  const _SyncTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (item.status) {
      'queued' => Colors.blue,
      'sending' => Colors.amber,
      'sent' => Colors.green,
      'failed' => Colors.red,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(
            item.status == 'failed' ? Icons.error : Icons.sync,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          '${item.entityType} • ${item.action}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Op: ${item.operationId.substring(0, 8)}…',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            if (item.errorMessage != null)
              Text(
                item.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
            if (item.retryCount > 0)
              Text(
                '${item.retryCount} retries',
                style: theme.textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
