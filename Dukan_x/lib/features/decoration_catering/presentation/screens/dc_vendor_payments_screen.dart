// ============================================================================
// DC Vendor Payments Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcVendorPaymentsScreen extends ConsumerStatefulWidget {
  const DcVendorPaymentsScreen({super.key});

  @override
  ConsumerState<DcVendorPaymentsScreen> createState() => _DcVendorPaymentsScreenState();
}

class _DcVendorPaymentsScreenState extends ConsumerState<DcVendorPaymentsScreen> {
  String? _selectedVendorId;
  bool _loadingPayments = false;
  List<DcVendorPayment> _payments = [];

  static const _teal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(dcVendorsProvider);

    return Scaffold(
      backgroundColor: DcColors.tealLight,
      body: BoundedBox(
        maxWidth: 800,
        child: Column(children: [
        DcGradientHeader(
          icon: Icons.store_rounded,
          title: 'Vendor Payments',
          subtitle: 'Track payments made to each vendor',
          color: _teal,
        ),
        Expanded(
          child: vendorsAsync.when(
            loading: () => Row(children: [
              Container(width: 300, color: Colors.white, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: 5, itemBuilder: (context2, idx2) => const DcCardSkeleton())),
              const VerticalDivider(width: 1),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ]),
            error: (e, _) => DcErrorState(error: e, onRetry: () => ref.invalidate(dcVendorsProvider)),
            data: (vendors) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 300, child: _buildVendorList(vendors)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildPaymentPanel(vendors)),
            ]),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _buildVendorList(List<DcVendor> vendors) {
    final fmt = NumberFormat('#,##,###');
    final totalOwed = vendors.fold<double>(0, (s, v) => s + v.totalDue);
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            const Icon(Icons.store_outlined, size: 14, color: DcColors.muted),
            const SizedBox(width: 6),
            Text('${vendors.length} Vendors', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DcColors.ink)),
            const Spacer(),
            if (totalOwed > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: DcColors.redLight, borderRadius: BorderRadius.circular(6)),
              child: Text('₹${fmt.format(totalOwed.round())} owed', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: DcColors.red)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: vendors.length,
            itemBuilder: (_, i) {
              final v = vendors[i];
              final isSelected = v.id == _selectedVendorId;
              return InkWell(
                onTap: () => _selectVendor(v.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  color: isSelected ? _teal.withValues(alpha: 0.06) : null,
                  child: Row(children: [
                    if (isSelected) Container(width: 3, height: 44, color: _teal, margin: const EdgeInsets.only(right: 10)),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _teal.withValues(alpha: 0.12),
                      child: Text(v.name[0].toUpperCase(), style: TextStyle(color: _teal, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSelected ? _teal : const Color(0xFF1F2937))),
                      Text(v.category, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ])),
                    if (v.totalPaid > 0)
                      Text('₹${fmt.format(v.totalPaid.round())}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildPaymentPanel(List<DcVendor> vendors) {
    if (_selectedVendorId == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.store_outlined, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('Select a vendor to view payments', style: TextStyle(color: Color(0xFF9CA3AF))),
        ]),
      );
    }

    final vendor = vendors.firstWhere((v) => v.id == _selectedVendorId, orElse: () => vendors.first);
    final fmt = NumberFormat('#,##,###');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Vendor summary bar
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          CircleAvatar(
            backgroundColor: _teal.withValues(alpha: 0.12),
            child: Text(vendor.name[0], style: TextStyle(color: _teal, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${vendor.category} · ${vendor.phone}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Total Paid: ₹${fmt.format(vendor.totalPaid.round())}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
            if (vendor.totalDue > 0)
              Text('Due: ₹${fmt.format(vendor.totalDue.round())}',
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
          ]),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddPaymentDialog(context, vendor),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Payment'),
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
          ),
        ]),
      ),
      const Divider(height: 1),
      if (_loadingPayments)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_payments.isEmpty)
        const Expanded(child: Center(child: Text('No payments recorded yet', style: TextStyle(color: Color(0xFF9CA3AF)))))
      else
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _payments.length,
            separatorBuilder: (context2, index) => const SizedBox(height: 8),
            itemBuilder: (context2, i) {
              final p = _payments[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.payments_rounded, color: Color(0xFF0D9488), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('₹${fmt.format(p.amount.round())}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669))),
                    Text('${p.paymentMode.toUpperCase()}${p.reference != null ? " · ${p.reference}" : ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(DateFormat('d MMM yyyy').format(p.date), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    if (p.notes != null) Text(p.notes!, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ]),
                ]),
              );
            },
          ),
        ),
    ]);
  }

  Future<void> _selectVendor(String vendorId) async {
    setState(() { _selectedVendorId = vendorId; _loadingPayments = true; _payments = []; });
    try {
      final payments = await ref.read(dcRepositoryProvider).getVendorPayments(vendorId);
      if (mounted) setState(() { _payments = payments; _loadingPayments = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPayments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payments: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddPaymentDialog(BuildContext context, DcVendor vendor) {
    showDialog(
      context: context,
      builder: (_) => _AddVendorPaymentDialog(
        vendor: vendor,
        onAdded: () async {
          if (_selectedVendorId != null) {
            final payments = await ref.read(dcRepositoryProvider).getVendorPayments(_selectedVendorId!);
            if (mounted) setState(() { _payments = payments; });
          }
          ref.invalidate(dcVendorsProvider);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AddVendorPaymentDialog extends ConsumerStatefulWidget {
  final DcVendor vendor;
  final VoidCallback onAdded;
  const _AddVendorPaymentDialog({required this.vendor, required this.onAdded});

  @override
  ConsumerState<_AddVendorPaymentDialog> createState() => _AddVendorPaymentDialogState();
}

class _AddVendorPaymentDialogState extends ConsumerState<_AddVendorPaymentDialog> {
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'cash';
  bool _saving = false;

  @override
  void dispose() { _amtCtrl.dispose(); _refCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Payment to ${widget.vendor.name}'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), isDense: true, prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _mode,
          decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'upi', child: Text('UPI')),
            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
            DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
          ],
          onChanged: (v) { if (v != null) setState(() => _mode = v); },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _refCtrl,
          decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtrl,
          decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(), isDense: true),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Record'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dcRepositoryProvider).recordVendorPayment(
        vendorId: widget.vendor.id,
        amount: amt,
        paymentMode: _mode,
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
