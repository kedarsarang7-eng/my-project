// Jewellery - Custom Order Management Screen
// Offline-first via JewelleryRepositoryOffline (Hive + sync queue)
// Requirement 14.1: custom orders work offline

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomOrderManagementScreen extends StatefulWidget {
  const CustomOrderManagementScreen({super.key});

  @override
  State<CustomOrderManagementScreen> createState() =>
      _CustomOrderManagementScreenState();
}

class _CustomOrderManagementScreenState
    extends State<CustomOrderManagementScreen> {
  // Requirement 14.1: Use offline-first repository (Hive + sync queue)
  late JewelleryRepositoryOffline _repository;
  bool _diReady = false;
  String? _diError;

  List<JewelleryOrder> _orders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _statusFilter;

  // Requirement 16.1/16.2: Explicit pagination — never load the whole Hive box.
  static const int _pageSize = 50;
  int _currentOffset = 0;

  final List<String> _statusOptions = [
    'ALL',
    'PENDING',
    'DESIGN_APPROVAL',
    'IN_PROGRESS',
    'READY',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    // Safe DI — catch failure gracefully
    try {
      _repository = JewelleryRepositoryOffline(sl(), sl<SessionManager>());
      _diReady = true;
    } catch (e) {
      _diError = 'Failed to initialize: $e';
      return;
    }
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      // Requirement 16.1/16.2: Pass explicit limit/offset.
      final response = await _repository.getOrders(
        status: _statusFilter,
        limit: _pageSize,
        offset: 0,
      );

      setState(() {
        _orders = response;
        _currentOffset = response.length;
        _hasMore = response.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  /// Load the next page of orders (Requirement 16.2).
  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreOrders = await _repository.getOrders(
        status: _statusFilter,
        limit: _pageSize,
        offset: _currentOffset,
      );

      setState(() {
        _orders.addAll(moreOrders);
        _currentOffset += moreOrders.length;
        _hasMore = moreOrders.length >= _pageSize;
      });
    } catch (e) {
      // Silently fail on load-more; user can retry by scrolling again
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onDeleteOrder(JewelleryOrder order) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      entityName: 'Custom Order',
      entityIdentifier:
          '${order.id.substring(0, 8)} - ${order.itemDescription}',
      isSoftDelete: true,
    );

    if (!confirmed) return;

    try {
      await _repository.deleteOrder(order.id);

      setState(() {
        _orders.removeWhere((o) => o.id == order.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order ${order.id.substring(0, 8)} moved to recycle bin',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restoreOrder(order),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete order: $e');
    }
  }

  Future<void> _restoreOrder(JewelleryOrder order) async {
    try {
      await _repository.restoreOrder(order.id);
      _loadOrders();
    } catch (e) {
      _showError('Failed to restore order: $e');
    }
  }

  Future<void> _onUpdateStatus(JewelleryOrder order, String newStatus) async {
    try {
      await _repository.updateOrderStatus(order.id, newStatus);
      _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update order: $e');
    }
  }

  // Dialog panels instead of Navigator.push — keeps desktop shell intact
  void _onViewOrder(JewelleryOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CustomOrderDetailScreen(order: order),
      ),
    );
  }

  void _onEditOrder(JewelleryOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CustomOrderEditScreen(order: order),
      ),
    ).then((_) {
      if (mounted) _loadOrders();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.grey;
      case 'DESIGN_APPROVAL':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'READY':
        return Colors.green;
      case 'DELIVERED':
        return Colors.indigo;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getMetalColor(MetalType metalType) {
    switch (metalType) {
      case MetalType.gold24k:
        return const Color(0xFFFFD700);
      case MetalType.gold22k:
        return const Color(0xFFFFE55C);
      case MetalType.gold18k:
        return const Color(0xFFE6C200);
      case MetalType.silver:
        return const Color(0xFFC0C0C0);
      case MetalType.platinum:
        return const Color(0xFFE5E4E2);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            _buildAppBar(isDark),
            _buildFilterBar(isDark),
            Expanded(
              child: _error != null
                  ? _buildErrorWidget()
                  : isDesktop
                  ? _buildDesktopView()
                  : _buildMobileView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewOrder(),
        backgroundColor: const Color(0xFFD4AF37), // Gold color for jewellery
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Order', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.diamond_outlined, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Orders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_orders.length} orders',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusOptions.map((status) {
            final isSelected =
                _statusFilter == status ||
                (status == 'ALL' && _statusFilter == null);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status.replaceAll('_', ' ')),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = status == 'ALL' ? null : status;
                  });
                  _loadOrders();
                },
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                selectedColor: _getStatusColor(status).withValues(alpha: 0.2),
                checkmarkColor: _getStatusColor(status),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopView() {
    if (!_diReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _diError ?? 'Initialization failed',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
    // Horizontal scroll wrapper + RepaintBoundary
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1200,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: DataTable2(
              columnSpacing: 16,
              horizontalMargin: 16,
              minWidth: 1100,
              columns: const [
                DataColumn2(label: Text('Order ID'), size: ColumnSize.S),
                DataColumn2(label: Text('Customer'), size: ColumnSize.M),
                DataColumn2(label: Text('Item'), size: ColumnSize.L),
                DataColumn2(label: Text('Metal'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Est. Wt.'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Est. Total'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(label: Text('Status'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Actions'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
              ],
              rows: _orders.map((order) => _buildOrderRow(order)).toList(),
              empty: _buildEmptyState(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow2 _buildOrderRow(JewelleryOrder order) {
    return DataRow2(
      cells: [
        DataCell(
          Text(
            order.id.substring(0, 8).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.customerName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                order.customerPhone ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            order.itemDescription,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getMetalColor(order.metalType).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              order.metalType.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getMetalColor(order.metalType),
              ),
            ),
          ),
        ),
        DataCell(Text('${order.estimatedWeightGrams.toStringAsFixed(2)} g')),
        DataCell(
          Text(
            '₹${(order.estimatedTotalPaisa / 100).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.status.replaceAll('_', ' '),
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          EntityActionPanel(
            actions: [
              ActionConfig.view,
              ActionConfig.edit,
              const ActionConfig(
                type: EntityAction.custom,
                label: 'Update Status',
                icon: Icons.update,
                iconColor: Color(0xFF6366F1),
                customValue: 'update_status',
              ),
              const ActionConfig(
                type: EntityAction.delete,
                label: 'Delete Order',
                icon: Icons.delete_outline,
                iconColor: Color(0xFFDC2626),
                textColor: Color(0xFFDC2626),
                showDivider: true,
                destructive: true,
              ),
            ],
            onAction: (action, value) {
              if (action == EntityAction.view) {
                _onViewOrder(order);
              } else if (action == EntityAction.edit)
                _onEditOrder(order);
              else if (action == EntityAction.delete)
                _onDeleteOrder(order);
              else if (value == 'update_status')
                _showStatusUpdateDialog(order);
            },
          ),
        ),
      ],
    );
  }

  void _showStatusUpdateDialog(JewelleryOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusOptions
              .where((s) => s != 'ALL' && s != order.status)
              .map(
                (status) => ListTile(
                  title: Text(status.replaceAll('_', ' ')),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(
                      status,
                    ).withValues(alpha: 0.2),
                    child: Icon(
                      Icons.circle,
                      color: _getStatusColor(status),
                      size: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _onUpdateStatus(order, status);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMobileView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200 &&
            !_isLoadingMore &&
            _hasMore) {
          _loadMoreOrders();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _orders.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final order = _orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(JewelleryOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getMetalColor(order.metalType),
                        _getMetalColor(order.metalType).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.diamond, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.itemDescription,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${order.metalType.displayName} • ${order.estimatedWeightGrams.toStringAsFixed(2)}g',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                EntityActionPanel.standard(
                  onView: () => _onViewOrder(order),
                  onEdit: () => _onEditOrder(order),
                  onDelete: () => _onDeleteOrder(order),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Order ID', order.id.substring(0, 8).toUpperCase()),
            _buildInfoRow('Customer', order.customerName),
            _buildInfoRow('Phone', order.customerPhone ?? 'N/A'),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${(order.estimatedTotalPaisa / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diamond_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new custom order',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _createNewOrder() {
    context.push('/jewellery/orders/create').then((_) {
      if (mounted) _loadOrders();
    });
  }
}

// Detail/Edit screens sized for Dialog with close button
class CustomOrderDetailScreen extends StatelessWidget {
  final JewelleryOrder order;
  const CustomOrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order ${order.id.substring(0, 8).toUpperCase()}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderDetailRow(
                'Order ID',
                order.id.substring(0, 8).toUpperCase(),
              ),
              _OrderDetailRow('Customer', order.customerName),
              _OrderDetailRow('Phone', order.customerPhone ?? '—'),
              _OrderDetailRow('Item', order.itemDescription),
              _OrderDetailRow('Metal', order.metalType.displayName),
              _OrderDetailRow(
                'Est. Weight',
                '${order.estimatedWeightGrams.toStringAsFixed(2)} g',
              ),
              _OrderDetailRow(
                'Est. Total',
                '₹${(order.estimatedTotalPaisa / 100).toStringAsFixed(2)}',
              ),
              _OrderDetailRow('Status', order.status.replaceAll('_', ' ')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _OrderDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomOrderEditScreen extends StatelessWidget {
  final JewelleryOrder order;
  const CustomOrderEditScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Order'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Center(
          child: Text(
            'Editing order ${order.id.substring(0, 8).toUpperCase()} — implement fields here',
          ),
        ),
      ),
    );
  }
}
