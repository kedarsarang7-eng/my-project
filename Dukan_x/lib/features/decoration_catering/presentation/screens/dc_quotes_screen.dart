// ============================================================================
// DC Quotation Builder Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcQuotesScreen extends ConsumerStatefulWidget {
  const DcQuotesScreen({super.key});

  @override
  ConsumerState<DcQuotesScreen> createState() => _DcQuotesScreenState();
}

class _DcQuotesScreenState extends ConsumerState<DcQuotesScreen> {
  String? _statusFilter;

  static const Color _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(dcQuotesProvider);

    return Scaffold(
      backgroundColor: DcColors.surface,
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            DcGradientHeader(
              icon: Icons.request_quote_rounded,
              title: 'Quotations',
              subtitle: 'Build and send event quotes before booking',
              color: _purple,
              actions: [
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Quote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _purple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            quotesAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (quotes) => _buildStatsBar(quotes),
            ),
            _buildFilters(),
            Expanded(
              child: quotesAsync.when(
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 4,
                  itemBuilder: (ctx2, i2) => const DcCardSkeleton(),
                ),
                error: (e, _) => DcErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(dcQuotesProvider),
                ),
                data: (quotes) {
                  final filtered = _statusFilter == null
                      ? quotes
                      : quotes
                            .where((q) => q.status.name == _statusFilter)
                            .toList();
                  if (filtered.isEmpty) {
                    return DcEmptyState(
                      icon: Icons.request_quote_outlined,
                      title: _statusFilter == null
                          ? 'No quotations yet'
                          : 'No $_statusFilter quotes',
                      subtitle:
                          'Tap "New Quote" to create your first quotation',
                      color: _purple,
                      actionLabel: 'New Quote',
                      onAction: () => _showCreateDialog(context),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (context2, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _QuoteCard(
                      quote: filtered[i],
                      onStatusChange: _changeStatus,
                      onDelete: _deleteQuote,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(List<DcQuote> quotes) {
    final draft = quotes.where((q) => q.status == QuoteStatus.draft).length;
    final sent = quotes.where((q) => q.status == QuoteStatus.sent).length;
    final accepted = quotes
        .where((q) => q.status == QuoteStatus.accepted)
        .length;
    final total = quotes.fold<double>(0, (s, q) => s + q.total);
    final fmt = NumberFormat('#,##,###');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          DcStatChip(
            label: 'Draft',
            value: '$draft',
            color: Colors.orange,
            icon: Icons.edit_rounded,
          ),
          const SizedBox(width: 10),
          DcStatChip(
            label: 'Sent',
            value: '$sent',
            color: Colors.blue,
            icon: Icons.send_rounded,
          ),
          const SizedBox(width: 10),
          DcStatChip(
            label: 'Accepted',
            value: '$accepted',
            color: DcColors.green,
            icon: Icons.check_circle_rounded,
          ),
          const Spacer(),
          DcStatChip(
            label: 'Pipeline Value',
            value: '₹${fmt.format(total.round())}',
            color: _purple,
            icon: Icons.currency_rupee_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = [null, 'draft', 'sent', 'accepted', 'rejected'];
    final labels = ['All', 'Draft', 'Sent', 'Accepted', 'Rejected'];
    final colors = [
      _purple,
      Colors.orange,
      Colors.blue,
      DcColors.green,
      DcColors.red,
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(statuses.length, (i) {
                final selected = _statusFilter == statuses[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    child: InkWell(
                      onTap: () => setState(() => _statusFilter = statuses[i]),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? colors[i] : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? colors[i] : DcColors.border,
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : DcColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(DcQuote quote, QuoteStatus newStatus) async {
    try {
      await ref
          .read(dcRepositoryProvider)
          .updateQuoteStatus(quote.id, newStatus);
      ref.invalidate(dcQuotesProvider);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _deleteQuote(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Quote?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dcRepositoryProvider).deleteQuote(id);
      ref.invalidate(dcQuotesProvider);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateQuoteDialog(
        onCreated: () {
          ref.invalidate(dcQuotesProvider);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QuoteCard extends StatelessWidget {
  final DcQuote quote;
  final void Function(DcQuote, QuoteStatus) onStatusChange;
  final void Function(String) onDelete;

  const _QuoteCard({
    required this.quote,
    required this.onStatusChange,
    required this.onDelete,
  });

  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    final color = quote.status.statusColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // coloured left accent
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _purple.withValues(alpha: 0.1),
                          child: Text(
                            quote.customerName.isNotEmpty
                                ? quote.customerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _purple,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quote.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: DcColors.ink,
                                ),
                              ),
                              Text(
                                quote.quoteNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DcColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(status: quote.status),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: DcColors.muted,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (v) {
                            if (v == 'delete') {
                              onDelete(quote.id);
                            } else {
                              onStatusChange(
                                quote,
                                QuoteStatus.values.firstWhere(
                                  (s) => s.name == v,
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            if (quote.status == QuoteStatus.draft)
                              const PopupMenuItem(
                                value: 'sent',
                                child: Text('Mark as Sent'),
                              ),
                            if (quote.status == QuoteStatus.sent) ...[
                              const PopupMenuItem(
                                value: 'accepted',
                                child: Text('Mark Accepted'),
                              ),
                              const PopupMenuItem(
                                value: 'rejected',
                                child: Text('Mark Rejected'),
                              ),
                            ],
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _infoChip(
                          Icons.celebration_rounded,
                          quote.eventType.isNotEmpty
                              ? '${quote.eventType[0].toUpperCase()}${quote.eventType.substring(1)}'
                              : '',
                        ),
                        if (quote.eventDate != null)
                          _infoChip(
                            Icons.calendar_today_rounded,
                            quote.eventDate!,
                          ),
                        if (quote.guestCount > 0)
                          _infoChip(
                            Icons.people_rounded,
                            '${quote.guestCount} guests',
                          ),
                        if (quote.venue != null && quote.venue!.isNotEmpty)
                          _infoChip(Icons.location_on_rounded, quote.venue!),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quote Value',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: DcColors.muted,
                                ),
                              ),
                              Text(
                                '₹${fmt.format(quote.total.round())}',
                                style: TextStyle(
                                  fontSize: responsiveValue<double>(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: _purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (quote.validUntil != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: DcColors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: DcColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Valid until ${quote.validUntil}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: DcColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: DcColors.muted),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: DcColors.muted)),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  final QuoteStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.statusColor;
    final label = status.statusLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CreateQuoteDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateQuoteDialog({required this.onCreated});

  @override
  ConsumerState<_CreateQuoteDialog> createState() => _CreateQuoteDialogState();
}

class _CreateQuoteDialogState extends ConsumerState<_CreateQuoteDialog> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _guestCtrl = TextEditingController(text: '100');
  final _discCtrl = TextEditingController(text: '0');
  String _eventType = 'wedding';
  DateTime? _eventDate;
  final List<Map<String, dynamic>> _items = [];
  bool _saving = false;

  final _eventTypes = [
    'wedding',
    'birthday',
    'corporate',
    'engagement',
    'babyShower',
    'anniversary',
    'conference',
    'other',
  ];

  double get _subtotal => _items.fold(
    0,
    (s, i) => s + (((i['qty'] as int?) ?? 1) * ((i['rate'] as double?) ?? 0)),
  );
  double get _gst => _subtotal * 0.18;
  double get _discount => double.tryParse(_discCtrl.text) ?? 0;
  double get _total => _subtotal + _gst - _discount;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    _guestCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitle(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Customer Details'),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _nameCtrl,
                              'Customer Name',
                              required: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _phoneCtrl,
                              'Phone',
                              keyboard: TextInputType.phone,
                              required: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _eventType,
                              decoration: const InputDecoration(
                                labelText: 'Event Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _eventTypes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _eventType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 7),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 2),
                                  ),
                                );
                                if (d != null) setState(() => _eventDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Event Date',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(
                                  _eventDate == null
                                      ? 'Select date'
                                      : DateFormat(
                                          'd MMM yyyy',
                                        ).format(_eventDate!),
                                  style: TextStyle(
                                    color: _eventDate == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _guestCtrl,
                              'Guests',
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(_venueCtrl, 'Venue'),
                      const SizedBox(height: 20),
                      _sectionLabel('Line Items'),
                      ..._items.asMap().entries.map(
                        (e) => _LineItemRow(
                          item: e.value,
                          onRemove: () =>
                              setState(() => _items.removeAt(e.key)),
                          onChange: () => setState(() {}),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _items.add({'desc': '', 'qty': 1, 'rate': 0.0}),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item'),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _discCtrl,
                        'Discount (₹)',
                        keyboard: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTotals(),
                      const SizedBox(height: 12),
                      _field(_notesCtrl, 'Notes (optional)', maxLines: 2),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      color: Color(0xFF7C3AED),
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    child: Row(
      children: [
        const Icon(Icons.request_quote_rounded, color: Colors.white),
        const SizedBox(width: 10),
        const Text(
          'New Quotation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          padding: EdgeInsets.zero,
          tooltip: 'Close dialog',
        ),
      ],
    ),
  );

  Widget _buildTotals() {
    final fmt = NumberFormat('#,##,###');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', '₹${fmt.format(_subtotal.round())}'),
          _totalRow('GST (18%)', '₹${fmt.format(_gst.round())}'),
          _totalRow('Discount', '- ₹${fmt.format(_discount.round())}'),
          const Divider(height: 12),
          _totalRow(
            'Total',
            '₹${fmt.format(_total.round())}',
            bold: true,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF4B5563),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? const Color(0xFF1F2937),
          ),
        ),
      ],
    ),
  );

  Widget _buildActions() => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saving ? null : _save,
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
              : const Text('Create Quote'),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF374151),
      ),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboard,
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final lineItems = _items
          .map(
            (i) => {
              'description': i['desc'] as String? ?? '',
              'quantity': (i['qty'] as int?) ?? 1,
              'unitPricePaisa': (((i['rate'] as double?) ?? 0) * 100).round(),
            },
          )
          .toList();

      final quote = DcQuote(
        id: '',
        quoteNumber: '',
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        eventType: _eventType,
        eventDate: _eventDate?.toIso8601String().substring(0, 10),
        venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        guestCount: int.tryParse(_guestCtrl.text) ?? 0,
        lineItems: lineItems,
        subtotal: _subtotal,
        gstAmount: _gst,
        discount: _discount,
        total: _total,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(dcRepositoryProvider).createQuote(quote);
      widget.onCreated();
      if (mounted) Navigator.pop(context);
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

class _LineItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final VoidCallback onChange;

  const _LineItemRow({
    required this.item,
    required this.onRemove,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: item['desc'] as String? ?? '',
              decoration: const InputDecoration(
                hintText: 'Description',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                item['desc'] = v;
                onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: '${item['qty'] ?? 1}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Qty',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                item['qty'] = int.tryParse(v) ?? 1;
                onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: '${item['rate'] ?? 0}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Rate ₹',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                item['rate'] = double.tryParse(v) ?? 0;
                onChange();
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove line item',
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.red,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
