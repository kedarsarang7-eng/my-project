import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Inventory & Assets Management Screen
class AcInventoryScreen extends ConsumerStatefulWidget {
  const AcInventoryScreen({super.key});

  @override
  ConsumerState<AcInventoryScreen> createState() => _AcInventoryScreenState();
}

class _AcInventoryScreenState extends ConsumerState<AcInventoryScreen> {
  String _selectedTab = 'items';

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Inventory & Assets',
      actions: [
        FilledButton.icon(
          onPressed: () => _showAddItemDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
      ],
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'items', label: Text('Items')),
              ButtonSegment(value: 'vendors', label: Text('Vendors')),
              ButtonSegment(value: 'movements', label: Text('Movements')),
              ButtonSegment(value: 'purchase_orders', label: Text('POs')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) =>
                setState(() => _selectedTab = set.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedTab == 'items'
                ? _buildItemsView()
                : _selectedTab == 'vendors'
                ? _buildVendorsView()
                : _selectedTab == 'movements'
                ? _buildMovementsView()
                : _buildPOView(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsView() {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        final lowStock = index % 5 == 0;
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.inventory_2,
              color: lowStock ? Colors.red : Colors.blue,
            ),
            title: Text('Item ${index + 1}'),
            subtitle: Text(
              'SKU: ITEM-${1000 + index} • Qty: ${lowStock ? 2 : 50}',
            ),
            trailing: lowStock
                ? const Chip(
                    label: Text('LOW STOCK'),
                    backgroundColor: Colors.red,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                  )
                : const Chip(label: Text('In Stock')),
          ),
        );
      },
    );
  }

  Widget _buildVendorsView() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business)),
            title: Text('Vendor ${index + 1}'),
            subtitle: const Text('Contact: vendor@email.com'),
            trailing: const Chip(label: Text('Active')),
          ),
        );
      },
    );
  }

  Widget _buildMovementsView() {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) {
        final isIn = index % 2 == 0;
        return Card(
          child: ListTile(
            leading: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? Colors.green : Colors.orange,
            ),
            title: Text(
              '${isIn ? 'Stock In' : 'Stock Out'} - Item ${index + 1}',
            ),
            subtitle: Text(
              'Qty: ${(index + 1) * 5} • ${DateTime.now().subtract(Duration(days: index)).toString().split(' ').first}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildPOView() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        final statuses = ['draft', 'sent', 'partial', 'received'];
        final status = statuses[index % statuses.length];
        final colors = {
          'draft': Colors.grey,
          'sent': Colors.blue,
          'partial': Colors.orange,
          'received': Colors.green,
        };

        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text('PO-${2024000 + index}'),
            subtitle: Text('Vendor: Supplier ${index + 1}'),
            trailing: Chip(
              label: Text(status.toUpperCase()),
              backgroundColor: colors[status]?.withOpacity(0.2),
            ),
          ),
        );
      },
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Inventory Item'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Item Name')),
              TextField(decoration: InputDecoration(labelText: 'SKU')),
              TextField(decoration: InputDecoration(labelText: 'Category')),
              TextField(
                decoration: InputDecoration(labelText: 'Initial Stock'),
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Min Stock Level'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
