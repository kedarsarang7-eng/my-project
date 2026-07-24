/// MobileShop Warranty Report — Active/Expiring/Claimed Warranties (Dart)
///
/// Displays warranty records grouped by status: active, expiring soon,
/// and claimed. Navigated from warranty KPI cards with pre-applied filters.
///
/// Requirements: 9.7–9.9, 9.12–9.13
library;

import 'package:flutter/material.dart';

import '../../auth/tenant_context_resolver.dart';
import '../../repository/mobile_shop_local_repository.dart';
import '../screen_state.dart';
import 'report_filter_params.dart';
import 'report_screen_base.dart';

/// Warranty Report — active, expiring, and claimed warranty records.
///
/// KPI cards for warranty metrics navigate here with status/claimStatus
/// pre-applied.
class WarrantyReportScreen extends ReportScreenBase {
  const WarrantyReportScreen({
    super.key,
    required super.resolver,
    required super.repository,
    super.initialFilter,
  });

  @override
  State<WarrantyReportScreen> createState() => _WarrantyReportScreenState();
}

class _WarrantyReportScreenState
    extends ReportScreenBaseState<WarrantyReportScreen> {
  List<_WarrantyReportItem> _items = [];
  int _activeCount = 0;
  int _expiringCount = 0;
  int _claimedCount = 0;

  @override
  String get reportTitle => 'Warranty Report';

  @override
  IconData get reportIcon => Icons.verified_user_outlined;

  @override
  Future<void> loadData(TenantContext ctx) async {
    try {
      // Use status or claimStatus filter.
      final statusFilter = activeFilter.status ?? activeFilter.claimStatus;
      final records = await widget.repository.listWarranties(
        ctx,
        status: statusFilter,
        limit: queryLimit,
      );

      final confirmed = records.where((r) => r.isServerConfirmed).toList();

      if (confirmed.isEmpty) {
        setState(
          () => screenState = ScreenEmpty(
            message: statusFilter != null
                ? 'No warranties with status "$statusFilter"'
                : 'No warranty data available',
          ),
        );
        return;
      }

      final items = <_WarrantyReportItem>[];
      int active = 0, expiring = 0, claimed = 0;

      for (final record in confirmed) {
        final entity = record.entity;
        final status = entity.status ?? 'unknown';

        if (status == 'active') active++;
        if (status == 'expiring_soon') expiring++;
        if (status == 'claimed' || entity.claimStatus == 'open') claimed++;

        items.add(
          _WarrantyReportItem(
            warrantyId: entity.entityId,
            imei: entity.imei,
            brand: entity.provider ?? 'Unknown',
            model: '',
            status: status,
            expiresAt: entity.endDate,
            claimStatus: entity.claimStatus,
          ),
        );
      }

      _items = items;
      _activeCount = active;
      _expiringCount = expiring;
      _claimedCount = claimed;
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
          message: 'Failed to load warranty report: $e',
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
                label: 'Active',
                value: _activeCount,
                color: Colors.green,
              ),
              _SummaryColumn(
                label: 'Expiring',
                value: _expiringCount,
                color: Colors.orange,
              ),
              _SummaryColumn(
                label: 'Claims',
                value: _claimedCount,
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
              itemBuilder: (context, index) =>
                  _WarrantyTile(item: _items[index]),
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

class _WarrantyReportItem {
  final String warrantyId;
  final String imei;
  final String brand;
  final String model;
  final String status;
  final DateTime? expiresAt;
  final String? claimStatus;

  const _WarrantyReportItem({
    required this.warrantyId,
    required this.imei,
    required this.brand,
    required this.model,
    required this.status,
    this.expiresAt,
    this.claimStatus,
  });
}

class _WarrantyTile extends StatelessWidget {
  final _WarrantyReportItem item;

  const _WarrantyTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withOpacity(0.15),
          child: Icon(Icons.verified_user, color: _statusColor, size: 20),
        ),
        title: Text(
          '${item.brand} ${item.model}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMEI: ${item.imei}', style: theme.textTheme.bodySmall),
            Row(
              children: [
                _Chip(label: item.status, color: _statusColor),
                if (item.claimStatus != null) ...[
                  const SizedBox(width: 4),
                  _Chip(
                    label: 'Claim: ${item.claimStatus!}',
                    color: Colors.red,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: item.expiresAt != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Expires', style: theme.textTheme.labelSmall),
                  Text(
                    _formatDate(item.expiresAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Color get _statusColor => switch (item.status) {
    'active' => Colors.green,
    'expiring_soon' => Colors.orange,
    'claimed' => Colors.red,
    'expired' => Colors.grey,
    _ => Colors.blue,
  };

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
