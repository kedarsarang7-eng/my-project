// ============================================================
// Dukan Billing Software - Order Management Screen
// Desktop-optimized order dashboard for business owners
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/business_order_models.dart';
import '../../providers/business_marketplace_providers.dart';
import '../widgets/order_detail_panel.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/order_stats_cards.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends ConsumerState<OrderManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMarketplaceEnabled = ref.watch(isMarketplaceEnabledProvider);
    final statsAsync = ref.watch(orderStatsProvider);
    final pendingCount = ref.watch(pendingActionsCountProvider);
    final viewMode = ref.watch(orderViewModeProvider);

    if (!isMarketplaceEnabled) {
      return const Scaffold(
        body: BoundedBox(
          maxWidth: 800,
          child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Marketplace is not enabled for your business category'),
            ],
          ),
        ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Online Orders'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // View Mode Toggle
          SegmentedButton<OrderViewMode>(
            segments: const [
              ButtonSegment(
                value: OrderViewMode.list,
                icon: Icon(Icons.list),
                label: Text('List'),
              ),
              ButtonSegment(
                value: OrderViewMode.grid,
                icon: Icon(Icons.grid_view),
                label: Text('Grid'),
              ),
              ButtonSegment(
                value: OrderViewMode.kanban,
                icon: Icon(Icons.view_kanban),
                label: Text('Board'),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (selected) {
              ref.read(orderViewModeProvider.notifier).state = selected.first;
            },
          ),
          const SizedBox(width: 16),
          
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ordersProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Main Content
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Stats Cards
                statsAsync.when(
                  data: (stats) => OrderStatsCards(stats: stats),
                  loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                
                // Filters Bar
                _buildFiltersBar(context),
                
                // Orders List
                Expanded(
                  child: _buildOrdersView(viewMode),
                ),
              ],
            ),
          ),
          
          // Order Detail Panel
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: const OrderDetailPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context) {
    final filters = ref.watch(orderFiltersProvider);
    final showExpressOnly = ref.watch(showExpressOnlyProvider);
    final searchQuery = ref.watch(orderSearchQueryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 300,
            child: SearchBar(
              hintText: 'Search orders...',
              leading: const Icon(Icons.search),
              trailing: [
                if (searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => ref.read(orderSearchQueryProvider.notifier).state = '',
                  ),
              ],
              onChanged: (value) => ref.read(orderSearchQueryProvider.notifier).state = value,
            ),
          ),
          const SizedBox(width: 16),
          
          // Status Filter
          DropdownButton<BusinessOrderStatus?>(
            value: filters.status,
            hint: const Text('All Statuses'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...BusinessOrderStatus.values.map((s) => DropdownMenuItem(
                value: s,
                child: Text(_formatStatus(s)),
              )),
            ],
            onChanged: (value) {
              ref.read(orderFiltersProvider.notifier).state = filters.copyWith(status: value);
              ref.read(ordersProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 16),
          
          // Express Filter
          FilterChip(
            label: const Text('Express Only'),
            selected: showExpressOnly,
            onSelected: (selected) {
              ref.read(showExpressOnlyProvider.notifier).state = selected;
            },
          ),
          const Spacer(),
          
          // Date Range
          TextButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: const Text('Today'),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersView(OrderViewMode viewMode) {
    final ordersAsync = ref.watch(filteredOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        switch (viewMode) {
          case OrderViewMode.list:
            return _buildListView(orders);
          case OrderViewMode.grid:
            return _buildGridView(orders);
          case OrderViewMode.kanban:
            return _buildKanbanView(orders);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error: $error'),
            TextButton(
              onPressed: () => ref.read(ordersProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<BusinessOrder> orders) {
    return DataTable2(
      columns: const [
        DataColumn2(label: Text('Order ID'), size: ColumnSize.S),
        DataColumn2(label: Text('Customer'), size: ColumnSize.L),
        DataColumn2(label: Text('Items'), size: ColumnSize.S),
        DataColumn2(label: Text('Total'), size: ColumnSize.S),
        DataColumn2(label: Text('Status'), size: ColumnSize.M),
        DataColumn2(label: Text('Time'), size: ColumnSize.S),
        DataColumn2(label: Text('Actions'), size: ColumnSize.S),
      ],
      rows: orders.map((order) => DataRow2(
        onTap: () => ref.read(selectedOrderIdProvider.notifier).state = order.orderId,
        selected: ref.watch(selectedOrderIdProvider) == order.orderId,
        cells: [
          DataCell(Text('#${order.orderId.substring(0, 8)}...')),
          DataCell(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(order.customer.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(order.customer.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )),
          DataCell(Text('${order.itemCount}')),
          DataCell(Text('₹${order.total.toStringAsFixed(2)}')),
          DataCell(OrderStatusBadge(status: order.status)),
          DataCell(Text(_formatTime(order.createdAt))),
          DataCell(_buildActionButtons(order)),
        ],
      )).toList(),
    );
  }

  Widget _buildGridView(List<BusinessOrder> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 3),
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          isSelected: ref.watch(selectedOrderIdProvider) == order.orderId,
          onTap: () => ref.read(selectedOrderIdProvider.notifier).state = order.orderId,
        );
      },
    );
  }

  Widget _buildKanbanView(List<BusinessOrder> orders) {
    final columns = [
      BusinessOrderStatus.placed,
      BusinessOrderStatus.accepted,
      BusinessOrderStatus.preparing,
      BusinessOrderStatus.readyForDispatch,
      BusinessOrderStatus.outForDelivery,
    ];

    return Row(
      children: columns.map((status) {
        final statusOrders = orders.where((o) => o.status == status).toList();
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Column Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatStatus(status),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${statusOrders.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Cards
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: statusOrders.length,
                    itemBuilder: (context, index) {
                      final order = statusOrders[index];
                      return _OrderCard(
                        order: order,
                        isSelected: ref.watch(selectedOrderIdProvider) == order.orderId,
                        onTap: () => ref.read(selectedOrderIdProvider.notifier).state = order.orderId,
                        compact: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BusinessOrder order) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (order.status == BusinessOrderStatus.placed)
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Accept',
            onPressed: () => _acceptOrder(order.orderId),
          ),
        if (order.status == BusinessOrderStatus.placed)
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
            onPressed: () => _rejectOrder(order.orderId),
          ),
        if (order.status == BusinessOrderStatus.accepted)
          IconButton(
            icon: const Icon(Icons.restaurant, color: Colors.orange),
            tooltip: 'Start Preparing',
            onPressed: () => _updateStatus(order.orderId, BusinessOrderStatus.preparing),
          ),
        if (order.status == BusinessOrderStatus.preparing)
          IconButton(
            icon: const Icon(Icons.inventory, color: Colors.blue),
            tooltip: 'Ready for Dispatch',
            onPressed: () => _updateStatus(order.orderId, BusinessOrderStatus.readyForDispatch),
          ),
      ],
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(
        orderId,
        status: BusinessOrderStatus.accepted,
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(ordersProvider.notifier).updateOrderStatus(
          orderId,
          status: BusinessOrderStatus.rejected,
        );
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _updateStatus(String orderId, BusinessOrderStatus status) async {
    try {
      await ref.read(ordersProvider.notifier).updateOrderStatus(
        orderId,
        status: status,
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatStatus(BusinessOrderStatus status) {
    return status.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .toUpperCase();
  }

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(BusinessOrderStatus status) {
    switch (status) {
      case BusinessOrderStatus.placed:
        return Colors.blue;
      case BusinessOrderStatus.accepted:
      case BusinessOrderStatus.preparing:
        return Colors.orange;
      case BusinessOrderStatus.readyForDispatch:
      case BusinessOrderStatus.outForDelivery:
        return Colors.purple;
      case BusinessOrderStatus.delivered:
        return Colors.green;
      case BusinessOrderStatus.cancelled:
      case BusinessOrderStatus.rejected:
        return Colors.red;
    }
  }
}

class _OrderCard extends StatelessWidget {
  final BusinessOrder order;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const _OrderCard({
    required this.order,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.orderId.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  OrderStatusBadge(status: order.status, compact: compact),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(order.customer.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(order.customer.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${order.itemCount} items'),
                    Text(
                      '₹${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
