import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

enum OccupancyStatus { empty, occupied, reserved, dirty }

class OccupancyTableData {
  final String tableId;
  final String tableNumber;
  final OccupancyStatus status;
  final int guestCount;

  const OccupancyTableData({
    required this.tableId,
    required this.tableNumber,
    required this.status,
    required this.guestCount,
  });
}

class OccupancyGridWidget extends StatelessWidget {
  final List<OccupancyTableData>? tables;
  final int columns;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onTableTapped;

  const OccupancyGridWidget({
    super.key,
    this.tables,
    this.columns = 4,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onTableTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ShimmerGrid(itemCount: 8, crossAxisCount: 4);
    if (error != null) {
      return ErrorRetryWidget(message: error!, onRetry: onRetry ?? () {});
    }

    final items = tables ?? const [];
    if (items.isEmpty) {
      return const IllustratedEmptyState(
        icon: Icons.table_restaurant_outlined,
        title: 'No tables yet',
        subtitle: 'Your occupancy grid will appear once tables are configured.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200 ? columns : constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final table = items[index];
            return InkWell(
              onTap: onTableTapped == null ? null : () => onTableTapped!(table.tableId),
              borderRadius: BorderRadius.circular(18),
              child: _TableCard(table: table),
            );
          },
        );
      },
    );
  }
}

class _TableCard extends StatelessWidget {
  final OccupancyTableData table;

  const _TableCard({required this.table});

  Color _color(BuildContext context) {
    switch (table.status) {
      case OccupancyStatus.empty:
        return const Color(0xFF10B981);
      case OccupancyStatus.occupied:
        return const Color(0xFF3B82F6);
      case OccupancyStatus.reserved:
        return const Color(0xFFF59E0B);
      case OccupancyStatus.dirty:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _icon() {
    switch (table.status) {
      case OccupancyStatus.empty:
        return Icons.event_available;
      case OccupancyStatus.occupied:
        return Icons.person;
      case OccupancyStatus.reserved:
        return Icons.bookmark;
      case OccupancyStatus.dirty:
        return Icons.cleaning_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Table ${table.tableNumber}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Icon(_icon(), color: color),
            ],
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                table.status.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Text(
            '${table.guestCount} guests',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
