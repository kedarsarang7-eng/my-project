import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/book_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ConsignmentSettlementScreen extends ConsumerStatefulWidget {
  const ConsignmentSettlementScreen({super.key});

  @override
  ConsumerState<ConsignmentSettlementScreen> createState() => _ConsignmentSettlementScreenState();
}

class _ConsignmentSettlementScreenState extends ConsumerState<ConsignmentSettlementScreen> {
  List<Consignment> _consignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConsignments();
  }

  Future<void> _fetchConsignments() async {
    setState(() => _isLoading = true);
    final result = await ref.read(bookRepositoryProvider).getConsignments();
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load consignments: ${failure.message}')),
        );
      },
      (items) {
        setState(() {
          _consignments = items;
        });
      },
    );
    setState(() => _isLoading = false);
  }

  void _showSettlementDialog(Consignment item) {
    final controller = TextEditingController(text: item.settlementAmount.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Settle with ${item.publisherName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Books Sold: ${item.totalBooksSold} / ${item.totalBooksReceived}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Settlement Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
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
                final amount = double.tryParse(controller.text) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount')),
                  );
                  return;
                }
                
                Navigator.pop(context); // Close dialog
                final result = await ref.read(bookRepositoryProvider).processSettlement(item.id, amount);
                result.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${l.message}'))),
                  (r) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement processed successfully')));
                    _fetchConsignments(); // Refresh list
                  },
                );
              },
              child: const Text('Confirm Settlement'),
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
        title: const Text('Publisher Consignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConsignments,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _consignments.isEmpty
              ? const Center(child: Text('No active consignments'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _consignments.length,
                  itemBuilder: (context, index) {
                    final item = _consignments[index];
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
                                  item.publisherName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Chip(
                                  label: Text(item.status),
                                  backgroundColor: item.status == 'settled' ? Colors.green.withValues(alpha: 0.1) : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Received', style: TextStyle(color: Colors.grey)),
                                    Text('${item.totalBooksReceived} books', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Sold', style: TextStyle(color: Colors.grey)),
                                    Text('${item.totalBooksSold} books', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Unsold Return', style: TextStyle(color: Colors.grey)),
                                    Text('${item.totalBooksReceived - item.totalBooksSold} books', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Amount Due: ₹${item.settlementAmount.toStringAsFixed(2)}', 
                                     style: Theme.of(context).textTheme.titleMedium),
                                ElevatedButton.icon(
                                  onPressed: item.status == 'settled' ? null : () => _showSettlementDialog(item),
                                  icon: const Icon(Icons.payment),
                                  label: const Text('Settle'),
                                ),
                              ],
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
