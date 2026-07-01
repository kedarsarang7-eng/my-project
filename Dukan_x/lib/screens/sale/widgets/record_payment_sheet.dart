import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_state_providers.dart';
import '../../../models/customer.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/repository/revenue_repository.dart';

/// Bottom sheet for recording a payment received from a customer
class RecordPaymentSheet extends ConsumerStatefulWidget {
  final Customer customer;

  const RecordPaymentSheet({super.key, required this.customer});

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMode = 'CASH';
  bool _isLoading = false;

  final List<String> _paymentModes = ['CASH', 'UPI', 'BANK', 'CHEQUE'];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(authStateProvider).userId;

      if (userId == null) {
        throw Exception('User authentication error');
      }

      await sl<RevenueRepository>().addReceipt(
        userId: userId,
        customerId: widget.customer.id,
        amount: amount,
        paymentMode: _paymentMode,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        _showSnack('Payment of ₹$amount recorded successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.payments_rounded,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'From: ${widget.customer.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Current Balance Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Outstanding Balance:',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Text(
                    '₹${widget.customer.totalDues.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.green.shade600,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Mode Selector
            Text(
              'Payment Mode',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _paymentModes.map((mode) {
                final isSelected = _paymentMode == mode;
                return ChoiceChip(
                  label: Text(mode),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _paymentMode = mode),
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.green.shade800 : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Notes Field
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'e.g., Advance payment for next order',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _recordPayment,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(
                  _isLoading ? 'Recording...' : 'Record Payment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
