// ============================================================================
// DECORATION & CATERING — BILLING & INVOICING SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../../services/dc_pdf_service.dart';
import '../../utils/dc_money_math.dart';
import '../../utils/decoration_catering_business_rules.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcBillingScreen extends ConsumerStatefulWidget {
  const DcBillingScreen({super.key});

  @override
  ConsumerState<DcBillingScreen> createState() => _DcBillingScreenState();
}

class _DcBillingScreenState extends ConsumerState<DcBillingScreen> {
  EventBooking? _selectedBooking;
  final List<_BillItem> _items = [];
  double _discount = 0;
  double _gstPct = 18;
  bool _showInvoice = false;
  bool _isSaving = false;
  bool _generatingPdf = false;
  String? _savedInvoiceNo;
  Map<String, dynamic>? _savedInvoiceData;
  String? _discountError;

  final _discCtrl = TextEditingController(text: '0');
  final _gstCtrl = TextEditingController(text: '18');
  final _invoiceSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _invoiceHistory = [];
  bool _loadingHistory = false;
  String _invoiceSearch = '';

  @override
  void initState() {
    super.initState();
    _loadInvoiceHistory();
  }

  Future<void> _loadInvoiceHistory({String search = ''}) async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final results = await ref
          .read(dcRepositoryProvider)
          .getInvoices(search: search.isNotEmpty ? search : null, limit: 30);
      if (mounted) setState(() => _invoiceHistory = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _gstCtrl.dispose();
    _invoiceSearchCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, i) => s + (i.qty * i.rate));

  // ─── Unified percentage-based discount/tax model (Requirement 10) ───
  // Uses DcMoneyMath.round2 for integer-paise arithmetic, identical to
  // DecorationCateringBusinessRules.computeQuoteTotalPct, so grand totals
  // match to the paise (zero variance) between both call sites.
  int get _subtotalPaise => DcMoneyMath.rupeesToPaise(_subtotal);

  ({int discountAmount, int postDiscount, int gstAmount, int grandTotal})
  get _totals => DecorationCateringBusinessRules.computeQuoteTotalPct(
    subtotalPaise: _subtotalPaise,
    discountPct: _discount,
    gstPct: _gstPct,
  );

  double get _discountAmt => DcMoneyMath.paiseToRupees(_totals.discountAmount);
  double get _taxableAmt => DcMoneyMath.paiseToRupees(_totals.postDiscount);
  double get _gstAmt => DcMoneyMath.paiseToRupees(_totals.gstAmount);
  double get _total => DcMoneyMath.paiseToRupees(_totals.grandTotal);

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(dcBookingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (bookings) => _showInvoice
                    ? _buildInvoicePreview(context)
                    : _buildBillingForm(context, bookings),
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
          Row(
            children: [
              if (_showInvoice) ...[
                IconButton(
                  onPressed: () => setState(() => _showInvoice = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to billing',
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing & Invoicing',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop:
                            22, // PRESERVED: Desktop uses exactly 22 as before
                      ),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate invoices for events',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 12,
                        tablet: 12,
                        desktop:
                            13, // PRESERVED: Desktop uses exactly 13 as before
                      ),
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_showInvoice)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _generatingPdf ? null : _previewPdf,
                  icon: const Icon(Icons.preview_rounded, size: 16),
                  label: const Text('Preview PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _generatingPdf ? null : _printPdf,
                  icon: _generatingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Print / Save PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBillingForm(BuildContext context, List<EventBooking> bookings) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          // PRESERVED: Desktop uses Row with side-by-side layout exactly as before
          // ADDED: Mobile/Tablet uses Column with stacked layout for better responsiveness
          responsiveValue<Widget>(
            context,
            mobile: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventSelector(bookings),
                const SizedBox(height: 16),
                _buildLineItems(context),
                const SizedBox(height: 16),
                _buildSummaryPanel(context),
              ],
            ),
            tablet: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventSelector(bookings),
                const SizedBox(height: 16),
                _buildLineItems(context),
                const SizedBox(height: 16),
                _buildSummaryPanel(context),
              ],
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildEventSelector(bookings),
                      const SizedBox(height: 16),
                      _buildLineItems(context),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width:
                      300, // PRESERVED: Desktop uses exactly 300px width as before
                  child: _buildSummaryPanel(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildInvoiceHistory(),
        ],
      ),
    );
  }

  Widget _buildInvoiceHistory() {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Invoice History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 280,
                height: 36,
                child: TextField(
                  controller: _invoiceSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by customer, phone, invoice no.',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    isDense: true,
                    suffixIcon: _invoiceSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _invoiceSearchCtrl.clear();
                              setState(() => _invoiceSearch = '');
                              _loadInvoiceHistory();
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    setState(() => _invoiceSearch = v);
                    _loadInvoiceHistory(search: v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _loadInvoiceHistory(search: _invoiceSearch),
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_invoiceHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No invoices found.',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                  children:
                      ['Invoice No.', 'Customer', 'Total', 'Status', 'Date']
                          .map(
                            (h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                ..._invoiceHistory.map((inv) {
                  final status = inv['status'] as String? ?? 'partial';
                  final statusColor = status == 'paid'
                      ? Colors.green
                      : status == 'partial'
                      ? Colors.blue
                      : Colors.orange;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          inv['invoiceNumber'] as String? ?? '—',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv['customerName'] as String? ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if ((inv['customerPhone'] as String?) != null)
                              Text(
                                inv['customerPhone'] as String,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          fmt.format(((inv['totalPaisa'] as num?) ?? 0) / 100),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          (inv['createdAt'] as String?)?.substring(0, 10) ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEventSelector(List<EventBooking> bookings) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Event',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedBooking?.id,
            decoration: const InputDecoration(
              labelText: 'Event Booking',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Select a booking...'),
              ),
              ...bookings
                  .where((b) => b.status != EventStatus.cancelled)
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        '${b.eventTitle} — ${b.customerName} (${DateFormat('d MMM').format(b.eventDate)})',
                      ),
                    ),
                  ),
            ],
            onChanged: (id) {
              if (id == null) return;
              final booking = bookings.firstWhere((b) => b.id == id);
              setState(() {
                _selectedBooking = booking;
                _savedInvoiceNo = null;
                _items.clear();
              });
              _addDefaultItems(booking);
            },
          ),
          if (_selectedBooking != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedBooking!.guestCount} guests • ${_selectedBooking!.venue} • Advance paid: ₹${NumberFormat('#,##,###').format(_selectedBooking!.advancePaid)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addDefaultItems(EventBooking booking) async {
    final repo = ref.read(dcRepositoryProvider);

    if (booking.includesDecoration) {
      double themePrice = 0;
      String themeDesc = 'Decoration Services';
      if (booking.decorationThemeId != null) {
        try {
          final themes = await repo.getThemes();
          final theme = themes
              .where((t) => t.id == booking.decorationThemeId)
              .firstOrNull;
          if (theme != null) {
            themePrice = theme.basePrice;
            themeDesc = 'Decoration — ${theme.name}';
          }
        } catch (_) {}
      }
      _items.add(_BillItem(description: themeDesc, qty: 1, rate: themePrice));
    }

    if (booking.includesCatering) {
      double plateRate = 0;
      String pkgDesc = 'Catering Services (${booking.guestCount} plates)';
      if (booking.cateringPackageId != null) {
        try {
          final pkgs = await repo.getPackages();
          final pkg = pkgs
              .where((p) => p.id == booking.cateringPackageId)
              .firstOrNull;
          if (pkg != null) {
            plateRate = pkg.pricePerPlate;
            pkgDesc = '${pkg.name} (${booking.guestCount} plates)';
          }
        } catch (_) {}
      }
      _items.add(
        _BillItem(
          description: pkgDesc,
          qty: booking.guestCount,
          rate: plateRate,
        ),
      );
    }

    _items.add(_BillItem(description: 'Staff Charges', qty: 1, rate: 0));
    _items.add(
      _BillItem(description: 'Transportation & Logistics', qty: 1, rate: 0),
    );
    if (mounted) setState(() {});
  }

  Widget _buildLineItems(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Line Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Header
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Rate (₹)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Amount (₹)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(width: 40),
            ],
          ),
          const Divider(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No items added. Select an event or add manually.',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: item.descCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: item.qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            enabledBorder: item.qtyError != null
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                            focusedBorder: item.qtyError != null
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                          onChanged: (v) => _onQtyChanged(item, v),
                        ),
                        if (item.qtyError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.qtyError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: item.rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            enabledBorder: item.rateError != null
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                            focusedBorder: item.rateError != null
                                ? const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => _onRateChanged(item, v),
                        ),
                        if (item.rateError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.rateError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Text(
                      NumberFormat('#,##,###').format(item.qty * item.rate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () => setState(() => _items.removeAt(i)),
                    tooltip: 'Remove line item',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _addItem() {
    setState(() => _items.add(_BillItem(description: '', qty: 1, rate: 0)));
  }

  /// Validates and clamps the discount percentage input (Requirements 10.5, 12.1).
  ///
  /// Numeric values are clamped to [0, 100]: e.g. 150 → 100, -5 → 0.
  /// The clamped value is applied and the text field is updated to reflect it.
  void _onDiscountChanged(String v) {
    final parsed = double.tryParse(v);
    if (parsed == null) {
      // Non-numeric input — retain previous value, no error (field is empty/partial)
      setState(() => _discountError = null);
      return;
    }
    // Clamp to [0, 100] (Requirement 12.1)
    final clamped = parsed.clamp(0.0, 100.0);
    setState(() {
      _discount = clamped;
      _discountError = null;
    });
    // If the value was clamped, update the text field to show the clamped value
    if (clamped != parsed) {
      final text = clamped == clamped.roundToDouble()
          ? clamped.toInt().toString()
          : clamped.toStringAsFixed(2);
      _discCtrl.text = text;
      _discCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    }
  }

  /// Validates and clamps the GST percentage input (Requirement 12.2).
  ///
  /// Numeric values are clamped to [0, 28]: e.g. 30 → 28, -1 → 0.
  /// The clamped value is applied and the text field is updated to reflect it.
  void _onGstChanged(String v) {
    final parsed = double.tryParse(v);
    if (parsed == null) {
      // Non-numeric input — retain previous value (field is empty/partial)
      return;
    }
    // Clamp to [0, 28] (Requirement 12.2)
    final clamped = parsed.clamp(0.0, 28.0);
    setState(() {
      _gstPct = clamped;
    });
    // If the value was clamped, update the text field to show the clamped value
    if (clamped != parsed) {
      final text = clamped == clamped.roundToDouble()
          ? clamped.toInt().toString()
          : clamped.toStringAsFixed(2);
      _gstCtrl.text = text;
      _gstCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    }
  }

  /// Validates line-item quantity input (Requirement 12.3).
  ///
  /// Quantity must be a positive integer (> 0). Empty, non-numeric, or <= 0
  /// values are rejected: the previous valid quantity is retained and an error
  /// indication is presented.
  void _onQtyChanged(_BillItem item, String v) {
    if (v.isEmpty) {
      setState(() {
        item.qtyError = 'Required';
      });
      // Restore previous valid value in the text field
      item.qtyCtrl.text = item.qty.toString();
      item.qtyCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.qtyCtrl.text.length),
      );
      return;
    }
    final parsed = int.tryParse(v);
    if (parsed == null) {
      setState(() {
        item.qtyError = 'Must be a number';
      });
      // Restore previous valid value
      item.qtyCtrl.text = item.qty.toString();
      item.qtyCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.qtyCtrl.text.length),
      );
      return;
    }
    if (parsed <= 0) {
      setState(() {
        item.qtyError = 'Must be > 0';
      });
      // Restore previous valid value
      item.qtyCtrl.text = item.qty.toString();
      item.qtyCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.qtyCtrl.text.length),
      );
      return;
    }
    // Valid — update quantity and clear error
    setState(() {
      item.qty = parsed;
      item.qtyError = null;
    });
  }

  /// Validates line-item rate input (Requirement 12.4).
  ///
  /// Rate must be a non-negative number (>= 0). Empty, non-numeric, or < 0
  /// values are rejected: the previous valid rate is retained and an error
  /// indication is presented.
  void _onRateChanged(_BillItem item, String v) {
    if (v.isEmpty) {
      setState(() {
        item.rateError = 'Required';
      });
      // Restore previous valid value
      item.rateCtrl.text = item.rate.toStringAsFixed(
        item.rate == item.rate.roundToDouble() ? 0 : 2,
      );
      item.rateCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.rateCtrl.text.length),
      );
      return;
    }
    final parsed = double.tryParse(v);
    if (parsed == null) {
      setState(() {
        item.rateError = 'Must be a number';
      });
      // Restore previous valid value
      item.rateCtrl.text = item.rate.toStringAsFixed(
        item.rate == item.rate.roundToDouble() ? 0 : 2,
      );
      item.rateCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.rateCtrl.text.length),
      );
      return;
    }
    if (parsed < 0) {
      setState(() {
        item.rateError = 'Cannot be negative';
      });
      // Restore previous valid value
      item.rateCtrl.text = item.rate.toStringAsFixed(
        item.rate == item.rate.roundToDouble() ? 0 : 2,
      );
      item.rateCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: item.rateCtrl.text.length),
      );
      return;
    }
    // Valid — update rate and clear error
    setState(() {
      item.rate = parsed;
      item.rateError = null;
    });
  }

  Widget _buildSummaryPanel(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    return Column(
      children: [
        Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invoice Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _summaryRow('Subtotal', '₹${fmt.format(_subtotal)}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Discount',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 30,
                    child: TextField(
                      controller: _discCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffix: const Text('%'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        errorText: _discountError,
                        errorStyle: const TextStyle(fontSize: 9),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: _onDiscountChanged,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '- ₹${fmt.format(_discountAmt)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'GST',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 30,
                    child: TextField(
                      controller: _gstCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffix: Text('%'),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: _onGstChanged,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '+ ₹${fmt.format(_gstAmt)}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  Text(
                    '₹${fmt.format(_total)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              if (_selectedBooking != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Advance Paid',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                    const Spacer(),
                    Text(
                      '- ₹${fmt.format(_selectedBooking!.advancePaid)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      'Balance Due',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${fmt.format((_total - _selectedBooking!.advancePaid).clamp(0, double.infinity))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_selectedBooking == null || _items.isEmpty || _isSaving)
                      ? null
                      : _generateAndSaveInvoice,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Generate Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _generateAndSaveInvoice() async {
    setState(() => _isSaving = true);
    try {
      final booking = _selectedBooking;
      final lineItems = _items
          .map(
            (i) => {
              'description': i.description,
              'qty': i.qty,
              'rateRupees': i.rate,
              'amountRupees': i.qty * i.rate,
            },
          )
          .toList();

      final result = await ref
          .read(dcRepositoryProvider)
          .createInvoice(
            eventId: booking?.id ?? '',
            customerName: booking?.customerName ?? '',
            customerPhone: booking?.customerPhone ?? '',
            lineItems: lineItems,
            subtotal: _subtotal,
            discountPct: _discount,
            gstPct: _gstPct,
            total: _total,
            advancePaid: booking?.advancePaid ?? 0,
          );

      final invoiceNo =
          result['invoiceNumber'] as String? ??
          result['id'] as String? ??
          'DC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      setState(() {
        _savedInvoiceNo = invoiceNo;
        _savedInvoiceData = result;
        _isSaving = false;
        _showInvoice = true;
      });
      _loadInvoiceHistory();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildInvoicePayload() {
    final base = _savedInvoiceData ?? {};
    return {
      ...base,
      'invoiceNumber': _savedInvoiceNo ?? base['invoiceNumber'] ?? 'DRAFT',
      'customerName':
          _selectedBooking?.customerName ?? base['customerName'] ?? '',
      'customerPhone':
          _selectedBooking?.customerPhone ?? base['customerPhone'] ?? '',
      'eventId': _selectedBooking?.id ?? base['eventId'] ?? '',
      'notes': _selectedBooking?.notes ?? base['notes'] ?? '',
      'lineItems': _items
          .map((i) => {'desc': i.description, 'qty': i.qty, 'rate': i.rate})
          .toList(),
      'subtotalPaisa': (_subtotal * 100).round(),
      'gstPercent': _gstPct,
      'gstAmountPaisa': (_gstAmt * 100).round(),
      'discountPaisa': (_discountAmt * 100).round(),
      'totalPaisa': (_total * 100).round(),
      'advancePaidPaisa': (((_selectedBooking?.advancePaid ?? 0)) * 100)
          .round(),
      'balancePaisa':
          ((_total - (_selectedBooking?.advancePaid ?? 0)).clamp(
                    0,
                    double.infinity,
                  ) *
                  100)
              .round(),
      'status': _savedInvoiceData?['status'] ?? 'partial',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _previewPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await DcPdfService.generateInvoice(_buildInvoicePayload());
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _savedInvoiceNo ?? 'invoice',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _printPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await DcPdfService.generateInvoice(_buildInvoicePayload());
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_savedInvoiceNo ?? 'invoice'}.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Widget _buildInvoicePreview(BuildContext context) {
    final fmt = NumberFormat('#,##,###');
    final invoiceNo =
        _savedInvoiceNo ??
        'DC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Container(
          width: 680,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice header
              Container(
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎊 Decoration & Catering',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: responsiveValue<double>(
                              context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Event Services Invoice',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'INVOICE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          invoiceNo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Date: ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(
                  responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 20,
                    desktop: 24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedBooking != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bill To:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedBooking!.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(_selectedBooking!.customerPhone),
                                if (_selectedBooking!.customerEmail.isNotEmpty)
                                  Text(_selectedBooking!.customerEmail),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Event Details:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedBooking!.eventTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Type: ${_selectedBooking!.eventTypeLabel}',
                                ),
                                Text(
                                  'Date: ${DateFormat('d MMMM yyyy').format(_selectedBooking!.eventDate)}',
                                ),
                                Text('Venue: ${_selectedBooking!.venue}'),
                                Text('Guests: ${_selectedBooking!.guestCount}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Items table
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(4),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9FAFB),
                          ),
                          children:
                              ['Description', 'Qty', 'Rate (₹)', 'Amount (₹)']
                                  .map(
                                    (h) => Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                        h,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        ..._items.map(
                          (item) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  '${item.qty}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  fmt.format(item.rate),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  fmt.format(item.qty * item.rate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 240,
                        child: Column(
                          children: [
                            _invoiceRow(
                              'Subtotal',
                              '₹${fmt.format(_subtotal)}',
                            ),
                            _invoiceRow(
                              'Discount (${_discount.toStringAsFixed(0)}%)',
                              '- ₹${fmt.format(_discountAmt)}',
                              color: Colors.red,
                            ),
                            _invoiceRow(
                              'GST (${_gstPct.toStringAsFixed(0)}%)',
                              '+ ₹${fmt.format(_gstAmt)}',
                            ),
                            const Divider(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${fmt.format(_total)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: responsiveValue<double>(
                                      context,
                                      mobile: 16,
                                      tablet: 18,
                                      desktop: 20,
                                    ),
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedBooking != null) ...[
                              const SizedBox(height: 4),
                              _invoiceRow(
                                'Advance Paid',
                                '- ₹${fmt.format(_selectedBooking!.advancePaid)}',
                                color: Colors.green,
                              ),
                              Row(
                                children: [
                                  const Text(
                                    'Balance Due',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹${fmt.format((_total - _selectedBooking!.advancePaid).clamp(0, double.infinity))}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Thank you for choosing our services! We look forward to making your event memorable.\nFor queries: contact@yourbusiness.com',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _BillItem {
  late TextEditingController descCtrl;
  late TextEditingController qtyCtrl;
  late TextEditingController rateCtrl;
  int qty;
  double rate;
  String? qtyError;
  String? rateError;
  String get description => descCtrl.text;

  _BillItem({
    required String description,
    required this.qty,
    required this.rate,
  }) {
    descCtrl = TextEditingController(text: description);
    qtyCtrl = TextEditingController(text: qty.toString());
    rateCtrl = TextEditingController(text: rate.toStringAsFixed(0));
  }
}
