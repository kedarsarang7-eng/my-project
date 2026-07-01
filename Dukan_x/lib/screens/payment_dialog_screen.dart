import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/theme/futuristic_colors.dart';
import '../models/bill.dart';
import '../services/payment_service.dart';

class PaymentDialogScreen extends StatefulWidget {
  final Bill bill;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const PaymentDialogScreen({
    super.key,
    required this.bill,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
  });

  @override
  State<PaymentDialogScreen> createState() => _PaymentDialogScreenState();
}

class _PaymentDialogScreenState extends State<PaymentDialogScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  String _selectedPaymentMethod = 'Cash'; // Cash or Online
  final TextEditingController _amountController = TextEditingController();
  String _message = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.bill.subtotal - widget.bill.paidAmount;
    _amountController.text = remaining.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) {
      _showMessage('Please enter valid amount', false);
      return;
    }

    final remaining = widget.bill.subtotal - widget.bill.paidAmount;
    if (amount > remaining + 0.01) {
      _showMessage('Amount exceeds remaining balance', false);
      return;
    }

    setState(() => _isLoading = true);

    if (_selectedPaymentMethod == 'Online') {
      // Initiate Razorpay payment
      _paymentService.initiateOnlinePayment(
        bill: widget.bill,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
        customerEmail: widget.customerEmail,
        amount: amount,
        onResult: (success, message) {
          setState(() {
            _isSuccess = success;
            _message = message;
            _isLoading = false;
          });

          if (success) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pop(context, true); // Return true to refresh bill
              }
            });
          }
        },
      );
    } else {
      // Record offline cash payment
      _paymentService.recordOfflinePayment(
        bill: widget.bill,
        amountPaid: amount,
        onResult: (success, message) {
          setState(() {
            _isSuccess = success;
            _message = message;
            _isLoading = false;
          });

          if (success) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pop(context, true); // Return true to refresh bill
              }
            });
          }
        },
      );
    }
  }

  void _showMessage(String message, bool success) {
    setState(() {
      _message = message;
      _isSuccess = success;
    });

    if (success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.bill.subtotal - widget.bill.paidAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ResponsiveContainer(
        child: Container(
          padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                'Payment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Bill Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bill Total:'),
                        Text(
                          '₹${widget.bill.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Already Paid:'),
                        Text(
                          '₹${widget.bill.paidAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: FuturisticColors.paid,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${remaining.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: FuturisticColors.unpaid,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Method Selection
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'Cash'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 'Cash'
                              ? Colors.blue.shade50
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedPaymentMethod == 'Cash'
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payments,
                              color: _selectedPaymentMethod == 'Cash'
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            const Text('Cash', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'Online'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedPaymentMethod == 'Online'
                              ? FuturisticColors.paidBackground
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedPaymentMethod == 'Online'
                                ? FuturisticColors.paid
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: _selectedPaymentMethod == 'Online'
                                  ? FuturisticColors.paid
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Online',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount Input
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount to Pay',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixText: 'Max: ₹${remaining.toStringAsFixed(2)}',
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Message Display
              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? FuturisticColors.paidBackground
                        : FuturisticColors.unpaidBackground,
                    border: Border.all(
                      color: _isSuccess
                          ? FuturisticColors.paid
                          : FuturisticColors.unpaid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error,
                        color: _isSuccess
                            ? FuturisticColors.paid
                            : FuturisticColors.unpaid,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _isSuccess
                                ? FuturisticColors.successDark
                                : FuturisticColors.errorDark,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_message.isNotEmpty) const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPaymentMethod == 'Cash'
                            ? Colors.blue
                            : FuturisticColors.paid,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Pay Now'),
                    ),
                  ),
                ],
              ),

              // Payment Methods Info
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ℹ️ Payment Methods Available:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '💵 Cash: Pay directly to shop owner',
                      style: TextStyle(fontSize: 11),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '💳 Online: UPI, Credit Card, Debit Card, Wallet',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
