// ============================================================================
// REFUND SCREEN — Process Full or Partial Refunds
// ============================================================================
// Allows authorized staff (Admin/Manager) to refund paid bills via Razorpay.
// Supports both full refunds and partial refunds with reason tracking.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../models/bill.dart';
import '../../../core/services/payment_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RefundScreen extends StatefulWidget {
  final Bill bill;
  final double? maxRefundableAmount;

  const RefundScreen({super.key, required this.bill, this.maxRefundableAmount});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  bool _isFullRefund = true;
  double? _alreadyRefunded;
  double get _maxRefundable =>
      widget.maxRefundableAmount ?? widget.bill.grandTotal;
  double get _remainingRefundable => _maxRefundable - (_alreadyRefunded ?? 0);

  @override
  void initState() {
    super.initState();
    _loadRefundHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRefundHistory() async {
    try {
      final refunds = await sl<PaymentService>().getRefundHistory(
        widget.bill.id,
      );
      final totalRefunded = refunds.fold<double>(
        0.0,
        (sum, refund) => sum + ((refund['amount'] ?? 0.0) as double),
      );

      if (mounted) {
        setState(() {
          _alreadyRefunded = totalRefunded;
          _amountController.text = (_maxRefundable - totalRefunded)
              .toStringAsFixed(2);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alreadyRefunded = 0.0;
          _amountController.text = _remainingRefundable.toStringAsFixed(2);
        });
      }
    }
  }

  Future<void> _processRefund() async {
    if (!_formKey.currentState!.validate()) return;

    final refundAmount = _isFullRefund
        ? _remainingRefundable
        : double.tryParse(_amountController.text) ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Text(
          'Process a refund of ₹${refundAmount.toStringAsFixed(2)} for '
          '${widget.bill.customerName ?? 'Walk-in'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (refundAmount <= 0 || refundAmount > _remainingRefundable) {
        setState(() {
          _errorMessage =
              'Invalid refund amount. Maximum refundable: ₹${_remainingRefundable.toStringAsFixed(2)}';
          _isProcessing = false;
        });
        return;
      }

      final result = await sl<PaymentService>().processRefund(
        billId: widget.bill.id,
        businessId: widget.bill.businessId ?? '',
        amount: _isFullRefund ? null : refundAmount, // null = full refund
        reason: _reasonController.text.isNotEmpty
            ? _reasonController.text
            : 'Customer request',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (result['success'] == true) {
        if (mounted) {
          _showSuccessDialog(
            refundId: result['refundId'] ?? '',
            amount: result['amount'] ?? refundAmount,
            isFullyRefunded: result['isFullyRefunded'] ?? false,
          );
        }
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Refund failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing refund: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog({
    required String refundId,
    required double amount,
    required bool isFullyRefunded,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Refund Processed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refund ID: $refundId'),
            const SizedBox(height: 8),
            Text('Amount: ₹${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            if (isFullyRefunded)
              const Text(
                'Bill is now fully refunded.',
                style: TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 16),
            const Text(
              'The refund will be processed within 5-7 business days.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(
                context,
                true,
              ); // Return to previous screen with success
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process Refund')),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bill Summary Card
              _buildBillSummaryCard(),
              const SizedBox(height: 24),

              // Refund Status
              if (_alreadyRefunded != null && _alreadyRefunded! > 0)
                _buildRefundStatusCard(),

              const SizedBox(height: 24),

              // Full/Partial Toggle
              _buildRefundTypeToggle(),
              const SizedBox(height: 16),

              // Amount Field (only for partial)
              if (!_isFullRefund)
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Refund Amount (₹)',
                    hintText:
                        'Enter amount up to ₹${_remainingRefundable.toStringAsFixed(2)}',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter refund amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    if (amount > _remainingRefundable) {
                      return 'Cannot exceed ₹${_remainingRefundable.toStringAsFixed(2)}';
                    }
                    return null;
                  },
                ),

              if (!_isFullRefund) const SizedBox(height: 16),

              // Reason Dropdown
              DropdownButtonFormField<String>(
                value: _reasonController.text.isEmpty
                    ? null
                    : _reasonController.text,
                decoration: const InputDecoration(
                  labelText: 'Refund Reason',
                  prefixIcon: Icon(Icons.help_outline),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Customer request',
                    child: Text('Customer request'),
                  ),
                  DropdownMenuItem(
                    value: 'Order cancelled',
                    child: Text('Order cancelled'),
                  ),
                  DropdownMenuItem(
                    value: 'Wrong item',
                    child: Text('Wrong item delivered'),
                  ),
                  DropdownMenuItem(
                    value: 'Quality issue',
                    child: Text('Quality issue'),
                  ),
                  DropdownMenuItem(
                    value: 'Duplicate payment',
                    child: Text('Duplicate payment'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _reasonController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Notes Field
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Add any additional details about this refund...',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Process Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processRefund,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.undo),
                  label: Text(
                    _isProcessing
                        ? 'Processing...'
                        : _isFullRefund
                        ? 'Process Full Refund (₹${_remainingRefundable.toStringAsFixed(2)})'
                        : 'Process Partial Refund',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBillSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bill Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Chip(
                  label: Text(
                    widget.bill.status,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: widget.bill.status == 'Paid'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              'Bill Number',
              widget.bill.invoiceNumber ?? widget.bill.id.substring(0, 8),
            ),
            _buildInfoRow('Customer', widget.bill.customerName ?? 'Walk-in'),
            _buildInfoRow('Date', _formatDate(widget.bill.date)),
            const Divider(),
            _buildInfoRow(
              'Bill Total',
              '₹${widget.bill.grandTotal.toStringAsFixed(2)}',
              isBold: true,
            ),
            _buildInfoRow(
              'Amount Paid',
              '₹${widget.bill.paidAmount.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundStatusCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Refund Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Already Refunded',
              '₹${_alreadyRefunded!.toStringAsFixed(2)}',
            ),
            _buildInfoRow(
              'Remaining',
              '₹${_remainingRefundable.toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundTypeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Full Refund'),
          icon: Icon(Icons.undo),
        ),
        ButtonSegment(
          value: false,
          label: Text('Partial Refund'),
          icon: Icon(Icons.percent),
        ),
      ],
      selected: {_isFullRefund},
      onSelectionChanged: (set) {
        setState(() {
          _isFullRefund = set.first;
          if (_isFullRefund) {
            _amountController.text = _remainingRefundable.toStringAsFixed(2);
          }
        });
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
