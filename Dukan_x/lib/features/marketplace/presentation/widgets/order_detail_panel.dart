import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/business_order_models.dart';
import '../../providers/business_marketplace_providers.dart';

/// Side panel showing details of the currently selected order.
class OrderDetailPanel extends ConsumerWidget {
  const OrderDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedOrderIdProvider);

    if (selectedId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select an order to view details',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final orderAsync = ref.watch(selectedOrderProvider(selectedId));

    return orderAsync.when(
      data: (order) => _buildDetail(context, order),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildDetail(BuildContext context, BusinessOrderDetail order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${order.orderId.substring(0, 8)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildField('Customer', order.customer.name),
          _buildField('Phone', order.customer.phone),
          _buildField('Items', '${order.items.length}'),
          _buildField('Total', '₹${order.total.toStringAsFixed(2)}'),
          _buildField('Status', order.status.name),
          _buildField('Placed', order.createdAt ?? ''),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
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
}
