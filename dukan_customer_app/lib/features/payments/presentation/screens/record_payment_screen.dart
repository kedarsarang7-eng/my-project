import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../data/payment_repository.dart';
import '../../../shops/data/shops_repository.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? vendorId;
  const RecordPaymentScreen({super.key, this.vendorId});

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _referenceController = TextEditingController();

  PaymentMethod _selectedMethod = PaymentMethod.cash;
  String? _selectedVendorId;
  bool _isSubmitting = false;

  static const _methods = [
    (PaymentMethod.cash, Icons.payments_rounded, 'Cash'),
    (PaymentMethod.upi, Icons.qr_code_rounded, 'UPI'),
    (PaymentMethod.bankTransfer, Icons.account_balance_rounded, 'Bank Transfer'),
    (PaymentMethod.cheque, Icons.description_rounded, 'Cheque'),
    (PaymentMethod.card, Icons.credit_card_rounded, 'Card'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedVendorId = widget.vendorId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shop')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(paymentRepositoryProvider).recordPayment(
            vendorId: _selectedVendorId!,
            amount: double.parse(_amountController.text.trim()),
            method: _selectedMethod,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            referenceNumber: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.vendorId == null) _VendorSelector(
              selectedVendorId: _selectedVendorId,
              onSelected: (id) => setState(() => _selectedVendorId = id),
            ),
            const SizedBox(height: 16),
            Text('Amount', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                prefixText: '₹  ',
                hintText: '0.00',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                final d = double.tryParse(v);
                if (d == null || d <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Payment Method', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _methods
                  .map((m) => ChoiceChip(
                        avatar: Icon(m.$2, size: 16),
                        label: Text(m.$3),
                        selected: _selectedMethod == m.$1,
                        onSelected: (_) =>
                            setState(() => _selectedMethod = m.$1),
                      ))
                  .toList(),
            ),
            if (_selectedMethod == PaymentMethod.upi ||
                _selectedMethod == PaymentMethod.bankTransfer ||
                _selectedMethod == PaymentMethod.cheque) ...[
              const SizedBox(height: 16),
              Text('Reference / Transaction ID',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  hintText: 'UPI ref / cheque no.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Notes (optional)',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Add a note…'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorSelector extends ConsumerWidget {
  final String? selectedVendorId;
  final ValueChanged<String?> onSelected;

  const _VendorSelector({
    required this.selectedVendorId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(linkedShopsProvider);

    return shops.when(
      data: (list) => DropdownButtonFormField<String>(
        value: selectedVendorId,
        decoration: const InputDecoration(labelText: 'Select Shop'),
        items: list
            .map((s) => DropdownMenuItem(
                  value: s.vendorId,
                  child:
                      Text(s.vendorBusinessName ?? s.vendorName),
                ))
            .toList(),
        onChanged: onSelected,
        validator: (v) => v == null ? 'Select a shop' : null,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Could not load shops'),
    );
  }
}
