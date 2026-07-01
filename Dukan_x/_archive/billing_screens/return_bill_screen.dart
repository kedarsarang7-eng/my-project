import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';

import '../../../../core/session/session_manager.dart';
import '../../domain/services/return_exchange_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ReturnBillScreen extends StatefulWidget {
  const ReturnBillScreen({super.key});

  @override
  State<ReturnBillScreen> createState() => _ReturnBillScreenState();
}

class _ReturnBillScreenState extends State<ReturnBillScreen> {
  final _searchCtrl = TextEditingController();
  final _returnService = ReturnExchangeService(
    billsRepository: sl<BillsRepository>(),
    productsRepository: sl(), // Assuming registered
    sessionManager: sl(),
  );

  Bill? _selectedBill;
  bool _isLoading = false;

  // Return State
  final Set<String> _selectedItemIds =
      {}; // BillItem.productId (or generated ID if available)
  final Map<String, double> _returnQty = {}; // productId -> qty
  String _reason = 'Size Mismatch';
  bool _restock = true;

  Future<void> _searchBill() async {
    final invoice = _searchCtrl.text.trim();
    if (invoice.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Basic search logic - ideally Repository should support getByInvoiceNumber
      // For now, we might need to search or assume we fetch all and filter (inefficient)
      // or implement a specific method.
      // Let's assume we can fetch by index or similar.
      // Since existing repo might not have it, let's try to fetch recent bills or assume getById works if input is ID.

      // FALLBACK: User might scan QR which has ID. Or type INV-...
      // Implementation Plan assumes we can search.
      // Let's try searching recent bills for match.

      final userId = sl<SessionManager>().ownerId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not logged in')));
        }
        return;
      }
      final result = await sl<BillsRepository>().getAll(
        userId: userId,
      ); // Get all for now (no limit param)
      final bills = result.data ?? [];

      final bill =
          bills.where((b) => b.invoiceNumber == invoice).firstOrNull ??
          bills.where((b) => b.id == invoice).firstOrNull;

      if (bill != null) {
        setState(() {
          _selectedBill = bill;
          _selectedItemIds.clear();
          _returnQty.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill not found in recent records')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleItem(BillItem item) {
    setState(() {
      if (_selectedItemIds.contains(item.productId)) {
        _selectedItemIds.remove(item.productId);
        _returnQty.remove(item.productId);
      } else {
        _selectedItemIds.add(item.productId);
        _returnQty[item.productId] = 1; // Default 1
      }
    });
  }

  void _updateQty(BillItem item, double qty) {
    if (qty <= 0 || qty > item.qty) return;
    setState(() {
      _returnQty[item.productId] = qty;
    });
  }

  double get _totalRefund {
    double total = 0;
    if (_selectedBill == null) return 0;

    for (var item in _selectedBill!.items) {
      if (_selectedItemIds.contains(item.productId)) {
        final qty = _returnQty[item.productId] ?? 1;
        // Pro-rated refund: (Item Total / Item Qty) * Return Qty
        // This handles tax/discount proportionally
        final unitRate = item.totalAmount / item.qty;
        total += unitRate * qty;
      }
    }
    return total;
  }

  Future<void> _processReturn() async {
    if (_selectedBill == null || _selectedItemIds.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final itemsToReturn = _selectedBill!.items
          .where((i) => _selectedItemIds.contains(i.productId))
          .map((i) {
            final returnQ = _returnQty[i.productId] ?? 1;
            // Create a copy with returned quantity
            // We need to recalculate tax/amounts for the returned chunk
            // Simple way: copy and set qty, assuming logic handles it?
            // BillItem constructor calculates total.
            return BillItem(
              productId: i.productId,
              productName: i.productName,
              qty: returnQ,
              price: i.price,
              unit: i.unit,
              gstRate: i.gstRate,
              cgst: i.cgst / i.qty * returnQ, // Pro-rated
              sgst: i.sgst / i.qty * returnQ,
              igst: i.igst / i.qty * returnQ,
              size: i.size,
              color: i.color,
            );
          })
          .toList();

      await _returnService.processReturn(
        originalBill: _selectedBill!,
        returnedItems: itemsToReturn,
        reason: _reason,
        restockItems: _restock,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return processed successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return Items')),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _searchBill,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(50, 56),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            if (_selectedBill != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer: ${_selectedBill!.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Date: ${_selectedBill!.date.toLocal().toString().split(' ')[0]}',
                        ),
                      ],
                    ),
                    Text(
                      'Total: ₹${_selectedBill!.grandTotal}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedBill!.items.length,
                  itemBuilder: (context, index) {
                    final item = _selectedBill!.items[index];
                    final isSelected = _selectedItemIds.contains(item.productId);
                    final returnQ = _returnQty[item.productId] ?? 1;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withOpacity(0.03) : Colors.white,
                        border: Border.all(
                          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) => _toggleItem(item),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      if (item.size != null || item.color != null)
                                        Text(
                                          'Size: ${item.size ?? '-'} | Color: ${item.color ?? '-'}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      Text(
                                        'Original Qty: ${item.qty}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Return Qty:', style: TextStyle(fontSize: 13)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => _updateQty(item, returnQ - 1),
                                      ),
                                      Text(
                                        '$returnQ',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _updateQty(item, returnQ + 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Restock Items:'),
                        const SizedBox(width: 8),
                        Switch(
                          value: _restock,
                          onChanged: (val) => setState(() => _restock = val),
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _reason,
                          items:
                              ['Size Mismatch', 'Defect', 'Wrong Item', 'Other']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) => setState(() => _reason = val!),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Refund Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${_totalRefund.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selectedItemIds.isEmpty || _isLoading
                            ? null
                            : _processReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'CONFIRM RETURN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('Enter Invoice Number to Search')),
              ),
          ],
        ),
      ),
    );
  }
}
