import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../payment/services/payment_orchestrator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Screen to Collect Payment (Receipt) from Customer
/// Or Make Payment to Vendor
class CollectPaymentScreen extends StatefulWidget {
  final String partyId;
  final String partyName;
  final String partyType; // 'CUSTOMER' or 'VENDOR'
  final double currentBalance;

  const CollectPaymentScreen({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.partyType,
    required this.currentBalance,
  });

  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMode = 'Cash'; // Cash, UPI, Bank
  DateTime _selectedDate = DateTime.now();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    // Amount Validation
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) throw Exception('User not logged in');

      if (widget.partyType == 'CUSTOMER') {
        // RECEIVED PAYMENT
        await sl<PaymentOrchestrator>().recordReceivedPayment(
          userId: userId,
          customerId: widget.partyId,
          customerName: widget.partyName,
          amount: amount,
          paymentMode: _paymentMode.toUpperCase(),
          date: _selectedDate,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
      } else {
        // PAID PAYMENT (Vendor)
        await sl<PaymentOrchestrator>().recordPaidPayment(
          userId: userId,
          vendorId: widget.partyId,
          vendorName: widget.partyName,
          amount: amount,
          paymentMode: _paymentMode.toUpperCase(),
          date: _selectedDate,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Recorded Successfully!')),
        );
        Navigator.pop(context, true); // Return true to refresh previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReceiving = widget.partyType == 'CUSTOMER';
    final actionLabel = isReceiving ? 'Receive Payment' : 'Pay Vendor';
    final balanceLabel = widget.currentBalance > 0
        ? (isReceiving
              ? 'Amount Due: ₹${widget.currentBalance}'
              : 'To Pay: ₹${widget.currentBalance}')
        : (isReceiving
              ? 'Advance: ₹${widget.currentBalance.abs()}'
              : 'Advance: ₹${widget.currentBalance.abs()}');

    final balanceColor = widget.currentBalance > 0
        ? (isReceiving ? Colors.red : Colors.orange)
        : Colors.green;

    return Scaffold(
      appBar: AppBar(title: Text(actionLabel)),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Party Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.partyName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      balanceLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Text(
                    '₹ ',
                    style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24), fontWeight: FontWeight.bold),
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid Number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Mode
              Text(
                'Payment Mode',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildModeChip('Cash', Icons.money),
                  const SizedBox(width: 8),
                  _buildModeChip('UPI', Icons.qr_code),
                  const SizedBox(width: 8),
                  _buildModeChip('Bank', Icons.account_balance),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'CONFIRM ${isReceiving ? "RECEIPT" : "PAYMENT"}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildModeChip(String label, IconData icon) {
    final isSelected = _paymentMode == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMode = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? FuturisticColors.primary : Colors.transparent,
            border: Border.all(
              color: isSelected ? FuturisticColors.primary : Colors.grey,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
