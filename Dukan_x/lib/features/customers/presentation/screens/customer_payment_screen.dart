// ============================================================================
// CUSTOMER PAYMENT SCREEN
// ============================================================================
// Allows customers to record payments made to vendors.
//
// UNS migration (task 14.5, T-CUS-5 + T-PAY-8): the legacy
// `customerNotificationsRepository.createNotification(...)` call site at the
// end of `_submitPayment` has been replaced with a Shared_SDK emit of the
// canonical `payment.customer_collection.recorded` event from the Phase 2
// Notification_Event_Registry §5.5. Recipients (customer, admin,
// accountant) and channels are resolved by the Notification_Service from
// the registry — this site only carries the payload.
//
// Author: DukanX Engineering
// Version: 2.0.0 — UNS migration
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;
import 'package:uuid/uuid.dart';

import '../../../../core/notifications/uns_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import '../../data/customer_dashboard_repository.dart';
import '../../data/customer_ledger_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Path-style identifier used as `source_module` on every UNS emit raised
/// from this screen. Matches Phase 2 §5.5.
const String _kSourceModule =
    'Dukan_x/lib/features/customers/presentation/screens/customer_payment_screen.dart';

enum PaymentMethod { cash, upi, bankTransfer, cheque, card, other }

class CustomerPaymentScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String? vendorId;
  final String? vendorName;
  final double? suggestedAmount;

  const CustomerPaymentScreen({
    super.key,
    required this.customerId,
    this.vendorId,
    this.vendorName,
    this.suggestedAmount,
  });

  @override
  ConsumerState<CustomerPaymentScreen> createState() =>
      _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends ConsumerState<CustomerPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _selectedVendorId;
  String? _selectedVendorName;
  PaymentMethod _paymentMethod = PaymentMethod.upi;
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedVendorId = widget.vendorId;
    _selectedVendorName = widget.vendorName;
    if (widget.suggestedAmount != null) {
      _amountController.text = widget.suggestedAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendorsAsync = ref.watch(connectedVendorsProvider(widget.customerId));

    return DesktopContentContainer(
      title: 'Record Payment',
      subtitle: 'Record payment to vendor',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card - Removed and replaced with Container Header logic if needed,
                  // but here keeping it as a nice visual banner inside the body is fine too,
                  // or we can remove it since DesktopContentContainer has a header.
                  // Decided to remove redundant header card since DesktopContentContainer has title.

                  // Vendor Selection
                  _buildSectionTitle('Select Vendor'),
                  const SizedBox(height: 8),
                  vendorsAsync.when(
                    data: (vendors) => _buildVendorDropdown(vendors),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Failed to load vendors'),
                  ),
                  const SizedBox(height: 20),

                  // Amount
                  _buildSectionTitle('Payment Amount'),
                  const SizedBox(height: 8),
                  _buildAmountField(),
                  const SizedBox(height: 20),

                  // Payment Method
                  _buildSectionTitle('Payment Method'),
                  const SizedBox(height: 8),
                  _buildPaymentMethodGrid(),
                  const SizedBox(height: 20),

                  // Payment Date
                  _buildSectionTitle('Payment Date'),
                  const SizedBox(height: 8),
                  _buildDatePicker(),
                  const SizedBox(height: 20),

                  // Reference Number
                  _buildSectionTitle('Reference Number (Optional)'),
                  const SizedBox(height: 8),
                  _buildReferenceField(),
                  const SizedBox(height: 20),

                  // Notes
                  _buildSectionTitle('Notes (Optional)'),
                  const SizedBox(height: 8),
                  _buildNotesField(),
                  const SizedBox(height: 32),

                  // Submit Button
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildVendorDropdown(List<VendorConnection> vendors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (vendors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No connected vendors. Connect with a vendor first.',
                style: GoogleFonts.poppins(color: Colors.orange.shade700),
              ),
            ),
          ],
        ),
      );
    }

    // Auto-select first if none selected
    if (_selectedVendorId == null && vendors.isNotEmpty) {
      _selectedVendorId = vendors.first.vendorId;
      _selectedVendorName = vendors.first.vendorName;
    }

    return DropdownButtonFormField<String>(
      value: _selectedVendorId,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: vendors.map((v) {
        return DropdownMenuItem(
          value: v.vendorId,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: v.outstandingBalance > 0
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Text(
                  v.vendorName.isNotEmpty ? v.vendorName[0].toUpperCase() : 'V',
                  style: TextStyle(
                    color: v.outstandingBalance > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.vendorName, style: GoogleFonts.poppins()),
                    Text(
                      'Due: ₹${v.outstandingBalance.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        final vendor = vendors.firstWhere((v) => v.vendorId == value);
        setState(() {
          _selectedVendorId = value;
          _selectedVendorName = vendor.vendorName;
        });
      },
      validator: (value) => value == null ? 'Please select a vendor' : null,
    );
  }

  Widget _buildAmountField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.poppins(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24), fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        prefixText: '₹ ',
        prefixStyle: GoogleFonts.poppins(
          fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintText: '0',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }

  Widget _buildPaymentMethodGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PaymentMethod.values.map((method) {
        final isSelected = _paymentMethod == method;
        return _buildPaymentMethodChip(method, isSelected);
      }).toList(),
    );
  }

  Widget _buildPaymentMethodChip(PaymentMethod method, bool isSelected) {
    IconData icon;
    String label;
    switch (method) {
      case PaymentMethod.cash:
        icon = Icons.money;
        label = 'Cash';
        break;
      case PaymentMethod.upi:
        icon = Icons.phone_android;
        label = 'UPI';
        break;
      case PaymentMethod.bankTransfer:
        icon = Icons.account_balance;
        label = 'Bank';
        break;
      case PaymentMethod.cheque:
        icon = Icons.description;
        label = 'Cheque';
        break;
      case PaymentMethod.card:
        icon = Icons.credit_card;
        label = 'Card';
        break;
      case PaymentMethod.other:
        icon = Icons.more_horiz;
        label = 'Other';
        break;
    }

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C5CE7)
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A3E)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMM yyyy').format(_paymentDate),
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Widget _buildReferenceField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: _referenceController,
      decoration: InputDecoration(
        hintText: 'e.g., UPI Transaction ID, Cheque Number',
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add any notes about this payment...',
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B894),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Record Payment',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vendor')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      final ledgerRepo = ref.read(customerLedgerRepositoryProvider);

      // Add credit entry to ledger
      final result = await ledgerRepo.addLedgerEntry(
        customerId: widget.customerId,
        vendorId: _selectedVendorId!,
        entryType: LedgerEntryType.credit,
        amount: amount,
        referenceType: 'PAYMENT',
        referenceId: const Uuid().v4(),
        referenceNumber: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        description:
            'Payment via ${_paymentMethod.name.toUpperCase()}${_noteController.text.isNotEmpty ? ': ${_noteController.text}' : ''}',
        notes: _noteController.text,
        entryDate: _paymentDate,
      );

      if (result.isSuccess) {
        // UNS migration (task 14.5, T-CUS-5): emit the canonical
        // `payment.customer_collection.recorded` event through the
        // Shared_SDK instead of the legacy customer notifications cache.
        // This single emit also retires T-PAY-8 (Phase 1 §9.2 marked it a
        // duplicate of T-PAY-2 / T-CUS-5 — the registry consolidates the
        // recipients and channels onto this one event).
        await _emitCollectionRecorded(
          collectionId: result.data?.id,
          amount: amount,
          paymentMethod: _paymentMethod,
          referenceNumber: _referenceController.text,
          note: _noteController.text,
        );

        if (mounted) {
          _showSuccessDialog(amount);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${result.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ==========================================================================
  // UNS EMIT — payment.customer_collection.recorded (T-CUS-5 / T-PAY-8).
  // --------------------------------------------------------------------------
  // Failures here are logged but do not block the local "Payment Recorded!"
  // success dialog: the ledger row has already been written. The SDK's own
  // outbox handles transient transport failures and replays in `created_at`
  // ASC order on next reconnect (REQ 8.8).
  // ==========================================================================
  Future<void> _emitCollectionRecorded({
    required String? collectionId,
    required double amount,
    required PaymentMethod paymentMethod,
    required String referenceNumber,
    required String note,
  }) async {
    final sdk = ref.read(notificationsSdkProvider).value;
    if (sdk == null) {
      // The provider is async — it may still be loading on a cold first
      // payment. Skipping the emit is acceptable here because the ledger
      // row is the source of truth; the next reconnect-driven sync will
      // surface it via the standard list/unread paths.
      return;
    }

    try {
      final actorId = widget.customerId;
      final vendorId = _selectedVendorId ?? 'unknown_vendor';
      // Phase 2 §5.5 dedup_key = [event_name, customer_id, collection_id].
      final dedupCollectionId = collectionId ?? const Uuid().v4();
      final dedupKey =
          'payment.customer_collection.recorded:$actorId:$dedupCollectionId';

      final payload = <String, dynamic>{
        'collection_id': dedupCollectionId,
        'customer_id': actorId,
        'vendor_id': vendorId,
        'vendor_name': _selectedVendorName,
        'amount': amount,
        'payment_method': paymentMethod.name,
        'payment_date': _paymentDate.toUtc().toIso8601String(),
        if (referenceNumber.isNotEmpty) 'reference_number': referenceNumber,
        if (note.isNotEmpty) 'note': note,
      };

      final event = sdk.buildEvent(
        eventName: 'payment.customer_collection.recorded',
        category: uns.EventCategory.payments,
        subCategory: 'manual_collection',
        priority: uns.EventPriority.high,
        actorId: actorId,
        targetId: vendorId,
        // Recipients intentionally empty — Notification_Service resolves
        // `customer`, `admin`, `accountant` from the registry consumer_roles
        // (Phase 2 §5.5).
        recipients: const <uns.Recipient>[],
        payload: payload,
        // Channels listed for the schema; per-role override happens
        // server-side from the registry channels_per_role field.
        channels: const <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
          uns.NotificationChannel.push,
          uns.NotificationChannel.sms,
          uns.NotificationChannel.email,
        ],
        sourceModule: _kSourceModule,
        sourceApp: uns.SourceApp.dukanxDesktop,
        dedupKey: dedupKey,
        dedupScopeFields: const <String>['customer_id', 'collection_id'],
      );

      await sdk.emit(event);
    } catch (e, stack) {
      // Schema/auth errors propagate from `emit`; transient transport
      // errors are buffered to the outbox by the SDK itself. Log and move
      // on so a single bad envelope does not break the success flow.
      debugPrint(
        '[CustomerPaymentScreen] UNS emit '
        '"payment.customer_collection.recorded" failed: $e\n$stack',
      );
    }
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Recorded!',
              style: GoogleFonts.poppins(
                fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(0)} to ${_selectedVendorName ?? 'vendor'}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ledger has been updated.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: Text(
              'Done',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Reset form for another payment
              _amountController.clear();
              _noteController.clear();
              _referenceController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
            ),
            child: Text(
              'Add Another',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
