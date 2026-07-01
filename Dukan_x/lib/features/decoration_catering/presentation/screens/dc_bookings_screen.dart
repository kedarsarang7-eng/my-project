// ============================================================================
// DECORATION & CATERING — EVENT BOOKINGS SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_booking_form.dart';
import '../widgets/dc_status_badge.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcBookingsScreen extends ConsumerStatefulWidget {
  const DcBookingsScreen({super.key});

  @override
  ConsumerState<DcBookingsScreen> createState() => _DcBookingsScreenState();
}

class _DcBookingsScreenState extends ConsumerState<DcBookingsScreen> {
  EventStatus? _statusFilter;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(dcBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildFilters(),
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (all) {
                  var filtered = all;
                  if (_statusFilter != null) {
                    filtered = filtered
                        .where((b) => b.status == _statusFilter)
                        .toList();
                  }
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    filtered = filtered
                        .where(
                          (b) =>
                              b.customerName.toLowerCase().contains(q) ||
                              b.eventTitle.toLowerCase().contains(q) ||
                              b.venue.toLowerCase().contains(q),
                        )
                        .toList();
                  }
                  if (filtered.isEmpty) {
                    return _buildEmpty();
                  }
                  return _buildList(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Bookings',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage all event bookings and workflows',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _openBookingForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = [null, ...EventStatus.values];
    final labels = {
      null: 'All',
      EventStatus.inquiry: 'Inquiry',
      EventStatus.confirmed: 'Confirmed',
      EventStatus.ongoing: 'Ongoing',
      EventStatus.completed: 'Completed',
      EventStatus.cancelled: 'Cancelled',
    };
    final colors = {
      null: const Color(0xFF6B7280),
      EventStatus.inquiry: Colors.orange,
      EventStatus.confirmed: Colors.blue,
      EventStatus.ongoing: Colors.purple,
      EventStatus.completed: Colors.green,
      EventStatus.cancelled: Colors.red,
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search bookings...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((s) {
                  final selected = _statusFilter == s;
                  final color = colors[s]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(labels[s]!),
                      selected: selected,
                      onSelected: (_) => setState(() => _statusFilter = s),
                      selectedColor: color.withValues(alpha: 0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: selected ? color : const Color(0xFF6B7280),
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? color : const Color(0xFFE5E7EB),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<EventBooking> bookings) {
    return ListView.builder(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) => _buildBookingCard(ctx, bookings[i]),
    );
  }

  Widget _buildBookingCard(BuildContext context, EventBooking b) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );
    final daysLeft = b.eventDate.difference(DateTime.now()).inDays;
    final isUrgent =
        daysLeft >= 0 &&
        daysLeft <= 3 &&
        b.status != EventStatus.completed &&
        b.status != EventStatus.cancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isUrgent
            ? Border.all(color: Colors.orange.shade300, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openBookingDetail(context, b),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Event icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: b.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _eventIcon(b.eventType),
                      color: b.statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.eventTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                            DcStatusBadge(status: b.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              b.customerName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              b.customerPhone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _infoChip(
                      Icons.calendar_today_rounded,
                      DateFormat('d MMM yyyy').format(b.eventDate),
                      daysLeft >= 0 && daysLeft <= 3
                          ? Colors.orange
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 16),
                    _infoChip(
                      Icons.location_on_outlined,
                      b.venue,
                      const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 16),
                    _infoChip(
                      Icons.group_outlined,
                      '${b.guestCount} guests',
                      const Color(0xFF6B7280),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(b.quotedAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Row(
                          children: [
                            _paymentBadge(b.paymentStatus),
                            const SizedBox(width: 6),
                            Text(
                              'Bal: ${fmt.format(b.balanceDue)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (b.includesDecoration || b.includesCatering) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (b.includesDecoration)
                      _serviceTag(
                        Icons.celebration_rounded,
                        'Decoration',
                        const Color(0xFF7C3AED),
                      ),
                    if (b.includesDecoration && b.includesCatering)
                      const SizedBox(width: 8),
                    if (b.includesCatering)
                      _serviceTag(
                        Icons.restaurant_rounded,
                        'Catering',
                        const Color(0xFFD97706),
                      ),
                    const Spacer(),
                    _actionBtn(
                      'Status',
                      Icons.swap_horiz_rounded,
                      () => _changeStatus(context, b),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      'Payment',
                      Icons.payment_rounded,
                      () => _recordPayment(context, b),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      'Notes',
                      Icons.notes_rounded,
                      () => _openNotesDialog(context, b),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      'Edit',
                      Icons.edit_rounded,
                      () => _openBookingForm(context, booking: b),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _serviceTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        foregroundColor: const Color(0xFF374151),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _paymentBadge(PaymentStatus status) {
    Color color;
    String label;
    switch (status) {
      case PaymentStatus.paid:
        color = Colors.green;
        label = 'Paid';
        break;
      case PaymentStatus.partial:
        color = Colors.blue;
        label = 'Partial';
        break;
      case PaymentStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case PaymentStatus.overdue:
        color = Colors.red;
        label = 'Overdue';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 16),
          const Text(
            'No bookings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first event booking',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openBookingForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(EventType type) {
    switch (type) {
      case EventType.wedding:
        return Icons.favorite_rounded;
      case EventType.birthday:
        return Icons.cake_rounded;
      case EventType.corporate:
        return Icons.business_rounded;
      case EventType.engagement:
        return Icons.diamond_rounded;
      case EventType.babyShower:
        return Icons.child_care_rounded;
      case EventType.anniversary:
        return Icons.celebration_rounded;
      case EventType.conference:
        return Icons.groups_rounded;
      case EventType.other:
        return Icons.event_rounded;
    }
  }

  void _openBookingForm(BuildContext context, {EventBooking? booking}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DcBookingForm(
        existing: booking,
        onSaved: (b) {
          ref.invalidate(dcBookingsProvider);
          ref.invalidate(dcStatsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                booking == null ? 'Booking created!' : 'Booking updated!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _openBookingDetail(BuildContext context, EventBooking b) {
    _openBookingForm(context, booking: b);
  }

  void _changeStatus(BuildContext context, EventBooking booking) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EventStatus.values
              .map(
                (s) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: booking.statusColor.withValues(alpha: 0.2),
                    child: Icon(Icons.circle, color: _statusColor(s), size: 12),
                  ),
                  title: Text(_statusLabel(s)),
                  selected: booking.status == s,
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(dcRepositoryProvider)
                        .updateBookingStatus(booking.id, s);
                    ref.invalidate(dcBookingsProvider);
                    ref.invalidate(dcStatsProvider);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _recordPayment(BuildContext context, EventBooking booking) {
    final amtCtrl = TextEditingController();
    PaymentMethod method = PaymentMethod.cash;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Record Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance Due: ₹${NumberFormat('#,##,###').format(booking.balanceDue)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                value: method,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(_paymentMethodLabel(m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setS(() => method = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                if (amt <= 0) return;
                await ref
                    .read(dcRepositoryProvider)
                    .recordPayment(
                      DcPayment(
                        id: 'PAY${DateTime.now().millisecondsSinceEpoch}',
                        eventId: booking.id,
                        customerName: booking.customerName,
                        amount: amt,
                        method: method,
                        date: DateTime.now(),
                      ),
                    );
                ref.invalidate(dcBookingsProvider);
                ref.invalidate(dcStatsProvider);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment recorded!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(EventStatus s) {
    switch (s) {
      case EventStatus.inquiry:
        return Colors.orange;
      case EventStatus.confirmed:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.purple;
      case EventStatus.completed:
        return Colors.green;
      case EventStatus.cancelled:
        return Colors.red;
    }
  }

  String _statusLabel(EventStatus s) {
    switch (s) {
      case EventStatus.inquiry:
        return 'Inquiry';
      case EventStatus.confirmed:
        return 'Confirmed';
      case EventStatus.ongoing:
        return 'Ongoing';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _paymentMethodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  void _openNotesDialog(BuildContext context, EventBooking booking) {
    showDialog(
      context: context,
      builder: (_) => _EventNotesDialog(booking: booking),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EventNotesDialog extends ConsumerStatefulWidget {
  final EventBooking booking;
  const _EventNotesDialog({required this.booking});

  @override
  ConsumerState<_EventNotesDialog> createState() => _EventNotesDialogState();
}

class _EventNotesDialogState extends ConsumerState<_EventNotesDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _loadNotes() {
    // Parse existing notes from booking if embedded; start empty otherwise
    setState(() => _notes = []);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 480,
        height: 480,
        child: Column(
          children: [
            _buildTitle(),
            Expanded(
              child: _notes.isEmpty
                  ? const Center(
                      child: Text(
                        'No notes yet. Add the first one!',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notes.length,
                      separatorBuilder: (context2, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context2, i) {
                        final n = _notes[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['text'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n['createdAt'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Add a note...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _addNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      color: Color(0xFF7C3AED),
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    child: Row(
      children: [
        const Icon(Icons.notes_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(
          'Notes — ${widget.booking.customerName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
          tooltip: 'Close notes',
        ),
      ],
    ),
  );

  Future<void> _addNote() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(dcRepositoryProvider)
          .appendEventNote(widget.booking.id, text);
      _ctrl.clear();
      if (mounted) {
        setState(() {
          _notes = updated
              .map(
                (n) => {
                  'text': n.text,
                  'createdAt': n.createdAt.toLocal().toString().substring(
                    0,
                    16,
                  ),
                },
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
