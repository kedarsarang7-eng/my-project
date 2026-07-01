// ============================================================================
// RETURNS PROCESSING BARCODE INTEGRATION
// ============================================================================
// Barcode-powered customer returns processing screen. Scan returned items
// to quickly create credit notes / refunds.
//
// Flow:
// 1. Select or search original invoice
// 2. Scan returned items â†’ auto-match to invoice line items
// 3. Select return reason per item
// 4. Generate credit note
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/repository/revenue_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../providers/app_state_providers.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';

// ============================================================================
// RETURN ITEM MODEL
// ============================================================================

class ScannedReturnItem {
  final String id;
  final String productId;
  final String productName;
  final String? barcode;
  final String unit;
  final double unitPrice;
  final double taxRate;
  int quantity;
  String reason;
  String condition; // 'good', 'damaged', 'defective', 'expired'

  ScannedReturnItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.barcode,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
    this.quantity = 1,
    this.reason = 'CUSTOMER_RETURN',
    this.condition = 'good',
  });

  double get refundAmount => quantity * unitPrice;
  double get taxAmount => refundAmount * taxRate / 100;
  double get totalRefund => refundAmount + taxAmount;
}

// ============================================================================
// RETURN REASONS
// ============================================================================

const List<String> returnReasons = [
  'CUSTOMER_RETURN',
  'DEFECTIVE',
  'WRONG_ITEM',
  'DAMAGED_IN_TRANSIT',
  'SIZE_EXCHANGE',
  'EXPIRED',
  'NOT_AS_DESCRIBED',
  'OTHER',
];

const List<String> itemConditions = [
  'good',
  'damaged',
  'defective',
  'expired',
  'opened',
];

// ============================================================================
// RETURNS BARCODE SCREEN
// ============================================================================

class ReturnsBarcodeScreen extends ConsumerStatefulWidget {
  final String? invoiceNumber;

  const ReturnsBarcodeScreen({super.key, this.invoiceNumber});

  @override
  ConsumerState<ReturnsBarcodeScreen> createState() =>
      _ReturnsBarcodeScreenState();
}

class _ReturnsBarcodeScreenState extends ConsumerState<ReturnsBarcodeScreen>
    with BarcodeScannerMixin<ReturnsBarcodeScreen> {
  final List<ScannedReturnItem> _returnItems = [];
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String _refundMethod = 'CREDIT_NOTE'; // CREDIT_NOTE, CASH, ORIGINAL_PAYMENT

  @override
  BusinessType get barcodeBusinessType =>
      ref.read(businessTypeProvider).type;

  @override
  void initState() {
    super.initState();
    if (widget.invoiceNumber != null) {
      _invoiceController.text = widget.invoiceNumber!;
    }
    initBarcodeMixin();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    disposeBarcodeMixin();
    super.dispose();
  }

  // ==========================================================================
  // BARCODE CALLBACKS
  // ==========================================================================

  @override
  void onBarcodeProductFound(ScannedProduct product) {
    setState(() {
      final existingIdx = _returnItems.indexWhere(
        (i) => i.productId == product.id,
      );

      if (existingIdx >= 0) {
        _returnItems[existingIdx].quantity += 1;
      } else {
        _returnItems.insert(
          0,
          ScannedReturnItem(
            id: const Uuid().v4(),
            productId: product.id,
            productName: product.displayTitle,
            barcode: product.barcode,
            unit: product.unit,
            unitPrice: product.salePrice,
            taxRate: product.gstRate,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Return item: ${product.displayTitle}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void onBarcodeProductNotFound(String barcode) {
    showBarcodeNotFoundDialog(barcode);
  }

  // ==========================================================================
  // COMPUTED
  // ==========================================================================

  double get _totalRefund =>
      _returnItems.fold(0, (s, i) => s + i.totalRefund);
  int get _totalQty =>
      _returnItems.fold(0, (s, i) => s + i.quantity);

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  void _removeItem(int index) {
    setState(() => _returnItems.removeAt(index));
  }

  void _updateReason(int index, String reason) {
    setState(() => _returnItems[index].reason = reason);
  }

  void _updateCondition(int index, String condition) {
    setState(() => _returnItems[index].condition = condition);
  }

  Future<void> _submitReturn() async {
    if (_returnItems.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      if (userId.isEmpty) throw Exception('User not authenticated');

      final revenueRepo = sl<RevenueRepository>();
      final itemsPayload = _returnItems
          .map((i) => {
                'itemId': i.productId,
                'itemName': i.productName,
                'quantity': i.quantity,
                'rate': i.unitPrice,
                'amount': i.totalRefund,
                'reason': i.reason,
                'condition': i.condition,
              })
          .toList();

      final result = await revenueRepo.addReturnInward(
        userId: userId,
        customerId: '',
        items: itemsPayload,
        totalReturnAmount: _totalRefund,
        billNumber: _invoiceController.text.trim().isNotEmpty
            ? _invoiceController.text.trim()
            : null,
        reason: _returnItems.isNotEmpty ? _returnItems.first.reason : 'CUSTOMER_RETURN',
      );

      if (!result.isSuccess) {
        throw Exception(result.errorMessage ?? 'Failed to process return');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return processed: $_totalQty items, refund â‚¹${_totalRefund.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Return (Scan)'),
        actions: [
          buildBarcodeScannerIndicator(),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          buildHiddenBarcodeInput(),

          // Invoice reference
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.withValues(alpha: 0.05),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _invoiceController,
                    decoration: const InputDecoration(
                      labelText: 'Original Invoice # (optional)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _refundMethod,
                    decoration: const InputDecoration(
                      labelText: 'Refund Method',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CREDIT_NOTE',
                        child: Text('Credit Note'),
                      ),
                      DropdownMenuItem(
                        value: 'CASH',
                        child: Text('Cash Refund'),
                      ),
                      DropdownMenuItem(
                        value: 'ORIGINAL_PAYMENT',
                        child: Text('Original Payment'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _refundMethod = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Scan hint
          if (_returnItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Scan returned items to add them',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),

          // Return items list
          Expanded(
            child: _returnItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Scan items being returned',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _returnItems.length,
                    itemBuilder: (context, index) {
                      final item = _returnItems[index];
                      return _buildReturnItemCard(item, index);
                    },
                  ),
          ),

          // Footer
          if (_returnItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_totalQty items being returned',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Refund: â‚¹${_totalRefund.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            hintText: 'Return notes (optional)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed:
                            !_isSubmitting ? _submitReturn : null,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                            _isSubmitting ? 'Processing...' : 'Process Return'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnItemCard(ScannedReturnItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'â‚¹${item.unitPrice.toStringAsFixed(2)} Ã— ${item.quantity} = â‚¹${item.refundAmount.toStringAsFixed(2)}'
                        ' (+â‚¹${item.taxAmount.toStringAsFixed(2)} tax)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quantity
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: item.quantity > 1
                          ? () => setState(() => item.quantity--)
                          : () => _removeItem(index),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => setState(() => item.quantity++),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Reason & condition
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    items: returnReasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _updateReason(index, val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    items: itemConditions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c[0].toUpperCase() + c.substring(1),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _updateCondition(index, val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
