/// MobileShop Reconciliation Exceptions Report (Dart)
///
/// Displays failed/stale reconciliation items and unresolved conflicts.
/// This is the target for the "Reconciliation Issues" and "Unresolved
/// Conflicts" KPI cards.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Reconciliation Exceptions Report — failed/stale reconciliation items.
///
/// KPI cards for conflictsUnresolved and reconciliationFailures navigate
/// here with pre-applied status filters.
class ReconciliationExceptionsReportScreen extends ReportScreenBase {
  const ReconciliationExceptionsReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<ReconciliationExceptionsReportScreen> createState() =>
      _ReconciliationExceptionsReportScreenState();
}

class _ReconciliationExceptionsReportScreenState
    extends ReportScreenBaseState<ReconciliationExceptionsReportScreen> {
  List<_ExceptionItem> _items = [];
  int _unresolvedCount = 0;
  int _failedCount = 0;

  @override
  String get reportTitle => 'Reconciliation Exceptions';

  @override
  IconData get reportIcon => Icons.sync_problem_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      // Load conflicts.
      final conflicts = await widget.repository.listConflicts(
        ctx,
        resolutionStatus: activeFilter.status == 'failed'
            ? null
            : ConflictResolutionStatus.unresolved,
      );

      if (conflicts.isEmpty) {
        setState(
          () => screenState = ScreenEmpty(
            message: activeFilter.status != null
                ? 'No exceptions with status "${activeFilter.status}"'
                : 'No reconciliation exceptions',
          ),
        );
        return;
      }

      final items = <_ExceptionItem>[];
      int unresolved = 0;
      int failed = 0;

      for (final conflict in conflicts) {
        final resolution = conflict.resolutionStatus;
        if (resolution == ConflictResolutionStatus.unresolved) unresolved++;
        // Treat long-standing unresolved as potentially failed.
        final isOld =
            DateTime.now().difference(conflict.createdAt).inHours > 24;
        if (isOld) failed++;

        items.add(
          _ExceptionItem(
            id: conflict.id,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            conflictType: conflict.reason,
            resolutionStatus: resolution,
            createdAt: conflict.createdAt,
            details: conflict.resolutionEvidence,
          ),
        );
      }

      _items = items;
      _unresolvedCount = unresolved;
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
          message: 'Failed to load reconciliation exceptions: $e',
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
          color: theme.colorScheme.errorContainer.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$_unresolvedCount',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text('Unresolved', style: theme.textTheme.labelSmall),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$_failedCount',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  Text('Stale (>24h)', style: theme.textTheme.labelSmall),
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
                  _ExceptionTile(item: _items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExceptionItem {
  final String id;
  final String entityType;
  final String entityId;
  final String conflictType;
  final String resolutionStatus;
  final DateTime? createdAt;
  final String? details;

  const _ExceptionItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.resolutionStatus,
    this.createdAt,
    this.details,
  });
}

class _ExceptionTile extends StatelessWidget {
  final _ExceptionItem item;

  const _ExceptionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStale =
        item.createdAt != null &&
        DateTime.now().difference(item.createdAt!).inHours > 24;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isStale ? Colors.red : Colors.orange).withOpacity(
            0.15,
          ),
          child: Icon(
            isStale ? Icons.error : Icons.warning_amber,
            color: isStale ? Colors.red : Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          '${item.entityType} • ${item.conflictType}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entity: ${item.entityId.length > 12 ? '${item.entityId.substring(0, 12)}…' : item.entityId}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            if (item.details != null)
              Text(
                item.details!,
                style: theme.textTheme.bodySmall,
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
                color: (isStale ? Colors.red : Colors.orange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isStale ? 'Stale' : item.resolutionStatus,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isStale ? Colors.red : Colors.orange,
                ),
              ),
            ),
            if (item.createdAt != null)
              Text(
                '${DateTime.now().difference(item.createdAt!).inHours}h ago',
                style: theme.textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
