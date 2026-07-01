import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/theme/futuristic_colors.dart';
import '../utils/number_utils.dart';

/// Widget to toggle bill payment status and edit bill items
class BillPaymentToggle extends StatefulWidget {
  final String billId;
  final String customerId;
  final double paidAmount;
  final double totalAmount;
  final String status; // 'Paid', 'Pending', 'Partial'
  final List<Map<String, dynamic>> items;
  final Function(String billId, String newStatus, double paidAmount)?
  onStatusChanged;
  final Function(String billId, List<Map<String, dynamic>> updatedItems)?
  onItemsChanged;
  final bool isOwnerView;

  const BillPaymentToggle({
    required this.billId,
    required this.customerId,
    required this.paidAmount,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.onStatusChanged,
    this.onItemsChanged,
    this.isOwnerView = false,
    super.key,
  });

  @override
  State<BillPaymentToggle> createState() => _BillPaymentToggleState();
}

class _BillPaymentToggleState extends State<BillPaymentToggle> {
  late String _currentStatus;
  late double _currentPaidAmount;
  late List<Map<String, dynamic>> _items;
  final _billsRepository = sl<BillsRepository>();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _currentPaidAmount = widget.paidAmount;
    _items = List.from(widget.items);
  }

  Future<void> _updateBillStatus(String newStatus) async {
    final prevStatus = _currentStatus;
    final prevPaidAmount = _currentPaidAmount;

    final targetPaid = _previewPaidAmountForStatus(
      newStatus,
      widget.totalAmount,
    );

    // Update UI immediately for perceived responsiveness
    setState(() {
      _currentStatus = newStatus;
      _currentPaidAmount = targetPaid;
    });

    try {
      final result = await _billsRepository.getById(widget.billId);
      final bill = result.data;

      if (bill == null) throw Exception('Bill not found');

      final updatedBill = bill.copyWith(
        status: newStatus,
        paidAmount: targetPaid,
      );

      final updateResult = await _billsRepository.updateBill(updatedBill);

      if (updateResult.isSuccess) {
        widget.onStatusChanged?.call(widget.billId, newStatus, targetPaid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill marked as $newStatus'),
              backgroundColor: newStatus == 'Paid'
                  ? FuturisticColors.paid
                  : FuturisticColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(updateResult.errorMessage);
      }
    } catch (e, stack) {
      if (mounted) {
        // Revert UI on error
        setState(() {
          _currentStatus = prevStatus;
          _currentPaidAmount = prevPaidAmount;
        });
        handleOperationError(
          context,
          e,
          stack,
          customMessage: 'Failed to update bill status',
        );
      }
    }
  }

  double _previewPaidAmountForStatus(String status, double total) {
    if (status == 'Paid') {
      return total;
    }
    if (status == 'Pending' || status == 'Unpaid') {
      return 0;
    }
    return _currentPaidAmount;
  }

  void _editBillItems() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bill Items'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['productName'] ??
                                  item['vegName'] ??
                                  'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: FuturisticColors.error,
                            ),
                            onPressed: () {
                              setState(() => _items.removeAt(index));
                              Navigator.pop(context);
                              _editBillItems();
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Price: ₹${item['unitPrice'] ?? item['pricePerKg']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Qty: ${item['quantity'] ?? item['qtyKg']} ${item['unit'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Total: ₹${item['total']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: FuturisticColors.paid,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveBillChanges();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _saveBillChanges() {
    // Immediate UI feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving bill...'),
        duration: Duration(seconds: 1),
      ),
    );

    _performBillSave();
  }

  Future<void> _performBillSave() async {
    try {
      // Recalculate total
      double newTotal = 0;
      for (var item in _items) {
        newTotal += parseDouble(item['total']);
      }

      final result = await _billsRepository.getById(widget.billId);
      final bill = result.data;

      if (bill == null) throw Exception('Bill not found');

      final updatedItems = _items.map((i) => BillItem.fromMap(i)).toList();
      final updatedBill = bill.copyWith(
        items: updatedItems,
        subtotal: newTotal,
        grandTotal: newTotal,
      );

      final updateResult = await _billsRepository.updateBill(updatedBill);

      if (updateResult.isSuccess) {
        widget.onItemsChanged?.call(widget.billId, _items);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill updated successfully'),
              backgroundColor: FuturisticColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(updateResult.errorMessage);
      }
    } catch (e, stack) {
      if (mounted) {
        handleOperationError(
          context,
          e,
          stack,
          customMessage: 'Bill update failed',
        );
      }
    }
  }

  void handleOperationError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace, {
    String? customMessage,
  }) {
    developer.log(
      customMessage ?? 'Operation failed',
      error: error,
      stackTrace: stackTrace,
      name: 'BillPaymentToggle',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customMessage ?? "Error"}: ${error.toString()}'),
        backgroundColor: FuturisticColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAmount = widget.totalAmount - _currentPaidAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill Amount Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '₹${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Pending Due',
                    style: TextStyle(
                      fontSize: 12,
                      color: pendingAmount > 0
                          ? FuturisticColors.unpaid
                          : FuturisticColors.paid,
                    ),
                  ),
                  Text(
                    '₹${pendingAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: pendingAmount > 0
                          ? FuturisticColors.unpaid
                          : FuturisticColors.paid,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pending Due Toggle
          if (pendingAmount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FuturisticColors.unpaidBackground,
                border: Border.all(color: FuturisticColors.warning),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Bill Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: FuturisticColors.warningDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Current: $_currentStatus',
                        style: TextStyle(
                          fontSize: 11,
                          color: FuturisticColors.warning,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _updateBillStatus('Paid'),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FuturisticColors.paid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _updateBillStatus('Pending'),
                        icon: const Icon(Icons.schedule, size: 16),
                        label: const Text('Pending'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Edit Bill Button (for owners)
          if (widget.isOwnerView)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _editBillItems,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Bill Items'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
