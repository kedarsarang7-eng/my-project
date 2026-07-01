import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/book_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class SchoolOrderScreen extends ConsumerStatefulWidget {
  const SchoolOrderScreen({super.key});

  @override
  ConsumerState<SchoolOrderScreen> createState() => _SchoolOrderScreenState();
}

class _SchoolOrderScreenState extends ConsumerState<SchoolOrderScreen> {
  List<SchoolOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    final result = await ref.read(bookRepositoryProvider).getSchoolOrders();
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: ${failure.message}')),
        );
      },
      (orders) {
        setState(() {
          _orders = orders;
        });
      },
    );
    setState(() => _isLoading = false);
  }

  void _showFulfillDialog(SchoolOrder order) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Fulfill Order: ${order.schoolName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Grade: ${order.grade}'),
              Text('Pending Sets: ${order.totalSets - order.fulfilledSets}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sets to fulfill',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final sets = int.tryParse(controller.text) ?? 0;
                if (sets <= 0 || sets > (order.totalSets - order.fulfilledSets)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid number of sets')),
                  );
                  return;
                }
                
                Navigator.pop(context); // Close dialog
                final result = await ref.read(bookRepositoryProvider).fulfillSchoolOrder(order.id, sets);
                result.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${l.message}'))),
                  (r) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order fulfilled successfully')));
                    _fetchOrders(); // Refresh list
                  },
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Bulk Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No active school orders'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final progress = order.fulfilledSets / order.totalSets;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.schoolName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Chip(label: Text(order.status)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Grade: ${order.grade}', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Progress: ${order.fulfilledSets} / ${order.totalSets} sets'),
                                Text('${(progress * 100).toStringAsFixed(1)}%'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: order.status == 'completed' ? null : () => _showFulfillDialog(order),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Fulfill Sets'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
