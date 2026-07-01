// ============================================================================
// DC Event Detail Screen - Comprehensive event view with notes timeline
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcEventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const DcEventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<DcEventDetailScreen> createState() => _DcEventDetailScreenState();
}

class _DcEventDetailScreenState extends ConsumerState<DcEventDetailScreen> {
  final _noteController = TextEditingController();
  bool _addingNote = false;
  int _selectedTab = 0;

  static const _teal = Color(0xFF0D9488);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(dcBookingProvider(widget.eventId));

    return Scaffold(
      backgroundColor: DcColors.tealLight,
      body: BoundedBox(
        maxWidth: 800,
        child: eventAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => DcErrorState(error: e, onRetry: () => ref.invalidate(dcBookingProvider(widget.eventId))),
          data: (event) {
            if (event == null) {
              return const Center(child: Text('Event not found'));
            }
            return _buildContent(event);
          },
        ),
      ),
    );
  }

  Widget _buildContent(EventBooking event) {
    return Column(children: [
      _buildHeader(event),
      _buildTabBar(),
      Expanded(child: _buildTabContent(event)),
    ]);
  }

  Widget _buildHeader(EventBooking event) {
    final fmt = NumberFormat('#,##,###');
    return DcGradientHeader(
      icon: Icons.event_note,
      title: event.eventTitle.isNotEmpty ? event.eventTitle : event.eventTypeLabel,
      subtitle: '${event.customerName} · ${DateFormat('d MMM yyyy').format(event.eventDate)}',
      color: _teal,
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: event.statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: event.statusColor),
          ),
          child: Text(
            event.statusLabel,
            style: TextStyle(color: event.statusColor, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Overview', 'Timeline', 'Staff', 'Payments', 'Expenses'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final isSelected = e.key == _selectedTab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? _teal : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? _teal : DcColors.muted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(EventBooking event) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(event);
      case 1:
        return _buildTimelineTab(event);
      case 2:
        return _buildStaffTab(event);
      case 3:
        return _buildPaymentsTab(event);
      case 4:
        return _buildExpensesTab(event);
      default:
        return _buildOverviewTab(event);
    }
  }

  Widget _buildOverviewTab(EventBooking event) {
    final fmt = NumberFormat('#,##,###');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInfoCard('Customer Details', [
          _buildInfoRow(Icons.person, 'Name', event.customerName),
          _buildInfoRow(Icons.phone, 'Phone', event.customerPhone),
          if (event.customerEmail.isNotEmpty)
            _buildInfoRow(Icons.email, 'Email', event.customerEmail),
        ]),
        const SizedBox(height: 16),
        _buildInfoCard('Event Details', [
          _buildInfoRow(Icons.celebration, 'Type', event.eventTypeLabel),
          _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('EEEE, d MMMM yyyy').format(event.eventDate)),
          _buildInfoRow(Icons.people, 'Guest Count', '${event.guestCount} guests'),
          if (event.venue.isNotEmpty)
            _buildInfoRow(Icons.location_on, 'Venue', event.venue),
          if (event.venueAddress.isNotEmpty)
            _buildInfoRow(Icons.map, 'Address', event.venueAddress),
        ]),
        const SizedBox(height: 16),
        _buildInfoCard('Financial Summary', [
          _buildInfoRow(Icons.receipt, 'Quoted Amount', '₹${fmt.format(event.quotedAmount.round())}'),
          _buildInfoRow(Icons.payments, 'Advance Paid', '₹${fmt.format(event.advancePaid.round())}', valueColor: Colors.green),
          _buildInfoRow(Icons.account_balance_wallet, 'Balance Due', '₹${fmt.format(event.balanceDue.round())}', 
            valueColor: event.balanceDue > 0 ? Colors.red : Colors.green),
          _buildInfoRow(Icons.payment, 'Payment Status', event.paymentStatus.name, 
            valueColor: event.paymentStatus == PaymentStatus.paid ? Colors.green : Colors.orange),
        ]),
        if (event.notes != null && event.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInfoCard('Notes', [
            Text(event.notes!, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
          ]),
        ],
      ]),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
        const Divider(height: 24),
        ...children,
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: DcColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1F2937))),
      ]),
    );
  }

  Widget _buildTimelineTab(EventBooking event) {
    return Column(children: [
      // Add note input
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Add a note...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          _addingNote
            ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2))
            : ElevatedButton.icon(
                onPressed: () => _addNote(event.id),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
              ),
        ]),
      ),
      const Divider(height: 1),
      // Notes list
      Expanded(
        child: ref.watch(dcEventNotesProvider(widget.eventId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (notes) {
            if (notes.isEmpty) {
              return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notes, size: 64, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 12),
                  Text('No notes yet', style: TextStyle(color: Color(0xFF9CA3AF))),
                  Text('Add a note to track event progress', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (_, i) => _buildNoteCard(notes[i], i == 0),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildNoteCard(DcEventNote note, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isLatest ? _teal : const Color(0xFFD1D5DB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          if (!isLatest)
            Container(width: 2, height: 60, color: const Color(0xFFE5E7EB)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                DateFormat('d MMM yyyy, h:mm a').format(note.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 4),
              Text(note.text, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
              if (note.createdBy.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('By: ${note.createdBy}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStaffTab(EventBooking event) {
    return ref.watch(dcStaffProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allStaff) {
        final assignedStaff = allStaff.where((s) => event.assignedStaffIds.contains(s.id)).toList();
        final availableStaff = allStaff.where((s) => !event.assignedStaffIds.contains(s.id) && s.isAvailable).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (assignedStaff.isNotEmpty) ...[
              Text('Assigned Staff (${assignedStaff.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ...assignedStaff.map((s) => _buildStaffCard(s, true, event)),
              const SizedBox(height: 24),
            ],
            Text('Available Staff (${availableStaff.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (availableStaff.isEmpty)
              const Text('No available staff', style: TextStyle(color: Color(0xFF9CA3AF)))
            else
              ...availableStaff.map((s) => _buildStaffCard(s, false, event)),
          ]),
        );
      },
    );
  }

  Widget _buildStaffCard(DcStaff staff, bool isAssigned, EventBooking event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAssigned ? _teal : const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: staff.roleColor.withValues(alpha: 0.2),
          child: Icon(Icons.person, color: staff.roleColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(staff.roleLabel, style: TextStyle(fontSize: 12, color: staff.roleColor)),
          Text('₹${NumberFormat('#,##,###').format(staff.dailyWage.round())}/day', 
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ])),
        ElevatedButton.icon(
          onPressed: () => _toggleStaffAssignment(staff.id, event, isAssigned),
          icon: Icon(isAssigned ? Icons.remove : Icons.add, size: 16),
          label: Text(isAssigned ? 'Remove' : 'Assign'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isAssigned ? Colors.red : _teal,
            foregroundColor: Colors.white,
          ),
        ),
      ]),
    );
  }

  Widget _buildPaymentsTab(EventBooking event) {
    return ref.watch(dcPaymentsProvider(widget.eventId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (payments) {
        final fmt = NumberFormat('#,##,###');
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildInfoCard('Payment Summary', [
              _buildInfoRow(Icons.receipt, 'Total Amount', '₹${fmt.format(event.quotedAmount.round())}'),
              _buildInfoRow(Icons.payments, 'Total Paid', '₹${fmt.format(event.advancePaid.round())}', valueColor: Colors.green),
              _buildInfoRow(Icons.account_balance_wallet, 'Balance Due', '₹${fmt.format(event.balanceDue.round())}', 
                valueColor: event.balanceDue > 0 ? Colors.red : Colors.green),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                onPressed: () => _showRecordPaymentDialog(event),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Record Payment'),
                style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
              ),
            ]),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Center(child: Text('No payments recorded', style: TextStyle(color: Color(0xFF9CA3AF)))),
            ...payments.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.payments, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('₹${fmt.format(p.amount.round())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(p.method.name.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
                Text(DateFormat('d MMM yyyy').format(p.date), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            )),
          ]),
        );
      },
    );
  }

  Widget _buildExpensesTab(EventBooking event) {
    return ref.watch(dcExpensesProvider(widget.eventId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final fmt = NumberFormat('#,##,###');
        final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildInfoCard('Expense Summary', [
              _buildInfoRow(Icons.account_balance_wallet, 'Total Expenses', '₹${fmt.format(totalExpenses.round())}'),
              _buildInfoRow(Icons.receipt, 'Revenue', '₹${fmt.format(event.quotedAmount.round())}'),
              _buildInfoRow(Icons.trending_up, 'Net Profit', '₹${fmt.format((event.quotedAmount - totalExpenses).round())}', 
                valueColor: event.quotedAmount > totalExpenses ? Colors.green : Colors.red),
            ]),
            const SizedBox(height: 16),
            const Text('Expense Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              const Center(child: Text('No expenses recorded', style: TextStyle(color: Color(0xFF9CA3AF)))),
            ...expenses.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.receipt_long, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(e.category, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
                Text('₹${fmt.format(e.amount.round())}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
              ]),
            )),
          ]),
        );
      },
    );
  }

  Future<void> _addNote(String eventId) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _addingNote = true);
    try {
      await ref.read(dcRepositoryProvider).appendEventNote(eventId, text);
      _noteController.clear();
      ref.invalidate(dcEventNotesProvider(eventId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add note: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _addingNote = false);
    }
  }

  Future<void> _toggleStaffAssignment(String staffId, EventBooking event, bool isAssigned) async {
    try {
      final updatedIds = isAssigned
        ? event.assignedStaffIds.where((id) => id != staffId).toList()
        : [...event.assignedStaffIds, staffId];
      await ref.read(dcRepositoryProvider).assignStaffToEvent(event.id, updatedIds);
      ref.invalidate(dcBookingProvider(event.id));
      ref.invalidate(dcStaffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAssigned ? 'Staff removed' : 'Staff assigned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update staff: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRecordPaymentDialog(EventBooking event) {
    showDialog(
      context: context,
      builder: (_) => _RecordPaymentDialog(
        event: event,
        onRecorded: () {
          ref.invalidate(dcPaymentsProvider(event.id));
          ref.invalidate(dcBookingProvider(event.id));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final EventBooking event;
  final VoidCallback onRecorded;
  const _RecordPaymentDialog({required this.event, required this.onRecorded});

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _amtCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Event: ${widget.event.customerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amtCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), isDense: true, prefixText: '₹ '),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _method,
          decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'upi', child: Text('UPI')),
            DropdownMenuItem(value: 'card', child: Text('Card')),
            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
            DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
          ],
          onChanged: (v) { if (v != null) setState(() => _method = v); },
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
      await ref.read(dcRepositoryProvider).recordPayment(DcPayment(
        id: '',
        eventId: widget.event.id,
        customerName: widget.event.customerName,
        amount: amt,
        method: PaymentMethod.values.firstWhere((m) => m.name == _method, orElse: () => PaymentMethod.cash),
        date: DateTime.now(),
      ));
      widget.onRecorded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers

final dcBookingProvider = FutureProvider.family.autoDispose<EventBooking?, String>((ref, id) async {
  return ref.read(dcRepositoryProvider).getBookingById(id);
});

final dcEventNotesProvider = FutureProvider.family.autoDispose<List<DcEventNote>, String>((ref, eventId) async {
  // Notes are fetched as part of event details in the backend
  final event = await ref.read(dcRepositoryProvider).getBookingById(eventId);
  return event?.notesList ?? [];
});

final dcPaymentsProvider = FutureProvider.family.autoDispose<List<DcPayment>, String?>((ref, eventId) async {
  return ref.read(dcRepositoryProvider).getPayments(eventId: eventId);
});

final dcExpensesProvider = FutureProvider.family.autoDispose<List<DcExpense>, String>((ref, eventId) async {
  return ref.read(dcRepositoryProvider).getExpenses(eventId: eventId);
});
