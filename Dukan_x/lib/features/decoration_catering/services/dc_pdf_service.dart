// ============================================================================
// DECORATION & CATERING — PDF INVOICE GENERATOR
// ============================================================================

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/errors/io_guard.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';

class DcPdfService {
  static final _fmt = NumberFormat('#,##,###');
  static final _fmtR = NumberFormat.currency(
    locale: 'en_IN',
    symbol: sl<CurrencyService>().symbol,
    decimalDigits: 0,
  );

  static PdfColor get _purple => const PdfColor.fromInt(0xFF7C3AED);
  static PdfColor get _dark => const PdfColor.fromInt(0xFF1A1A2E);
  static PdfColor get _grey => const PdfColor.fromInt(0xFF6B7280);
  static PdfColor get _light => const PdfColor.fromInt(0xFFF5F3FF);
  static PdfColor get _border => const PdfColor.fromInt(0xFFE5E7EB);
  static PdfColor get _white => PdfColors.white;
  static PdfColor get _green => const PdfColor.fromInt(0xFF059669);

  // ── Public entry point ───────────────────────────────────────────────────

  // ── Report PDF ───────────────────────────────────────────────────────────

  static Future<Uint8List> generateReport({
    required String dateFrom,
    required String dateTo,
    required List<Map<String, dynamic>> bookings,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> staff,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMedium = await PdfGoogleFonts.interMedium();
    final fmtR = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );

    // ── KPI aggregates
    final totalQuoted = bookings.fold<double>(
      0,
      (s, b) => s + ((b['totalAmountPaisa'] as num? ?? 0) / 100),
    );
    final totalCollected = bookings.fold<double>(
      0,
      (s, b) => s + ((b['advanceAmountPaisa'] as num? ?? 0) / 100),
    );
    final totalPending = totalQuoted - totalCollected;
    final totalExpenses = expenses.fold<double>(
      0,
      (s, e) => s + ((e['amountPaisa'] as num? ?? 0) / 100),
    );
    final netProfit = totalCollected - totalExpenses;

    final byCat = <String, double>{};
    for (final e in expenses) {
      final cat = e['category'] as String? ?? 'Other';
      byCat[cat] = (byCat[cat] ?? 0) + ((e['amountPaisa'] as num? ?? 0) / 100);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          // Title header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _purple,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DC REPORTS & ANALYTICS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: _white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: $dateFrom  →  $dateTo',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: const PdfColor(1, 1, 1, 0.7),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: const PdfColor(1, 1, 1, 0.6),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // KPI grid
          pw.Text(
            'Revenue Summary',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: _dark),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _kpiBox('Total Quoted', fmtR.format(totalQuoted), font, fontBold),
              pw.SizedBox(width: 10),
              _kpiBox('Collected', fmtR.format(totalCollected), font, fontBold),
              pw.SizedBox(width: 10),
              _kpiBox(
                'Pending Dues',
                fmtR.format(totalPending),
                font,
                fontBold,
              ),
              pw.SizedBox(width: 10),
              _kpiBox('Net Profit', fmtR.format(netProfit), font, fontBold),
            ],
          ),
          pw.SizedBox(height: 20),

          // Bookings table
          pw.Text(
            'Booking Revenue Breakdown (${bookings.length} events)',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: _dark),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
              5: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _purple),
                children:
                    [
                          'Event / Customer',
                          'Date',
                          'Quoted',
                          'Collected',
                          'Balance',
                          'Status',
                        ]
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 8,
                                color: _white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              ...bookings.asMap().entries.map((entry) {
                final b = entry.value;
                final isEven = entry.key.isEven;
                final quoted = (b['totalAmountPaisa'] as num? ?? 0) / 100;
                final collected = (b['advanceAmountPaisa'] as num? ?? 0) / 100;
                final balance = quoted - collected;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isEven ? _white : _light),
                  children: [
                    _cell(
                      '${b['customerName'] ?? ''}\n${b['eventType'] ?? ''}',
                      font,
                    ),
                    _cell(b['eventDate'] as String? ?? '', font),
                    _cell(fmtR.format(quoted), font),
                    _cell(fmtR.format(collected), font),
                    _cell(fmtR.format(balance), fontMedium),
                    _cell((b['status'] as String? ?? '').toUpperCase(), font),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // Expenses section
          pw.Text(
            'Expense Breakdown (Total: ${fmtR.format(totalExpenses)})',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: _dark),
          ),
          pw.SizedBox(height: 8),
          if (byCat.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _purple),
                  children: ['Category', 'Amount']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: _white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...byCat.entries.toList().asMap().entries.map((entry) {
                  final e = entry.value;
                  final isEven = entry.key.isEven;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? _white : _light,
                    ),
                    children: [
                      _cell(e.key, font),
                      _cell(fmtR.format(e.value), fontMedium),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 20),

          // Staff summary
          pw.Text(
            'Staff Summary (${staff.length} members)',
            style: pw.TextStyle(font: fontBold, fontSize: 13, color: _dark),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Active: ${staff.where((s) => s['isActive'] == true).length}   '
            'Daily Wage Budget: ${fmtR.format(staff.fold<double>(0, (s, m) => s + ((m['dailyRatePaisa'] as num? ?? 0) / 100)))}',
            style: pw.TextStyle(font: font, fontSize: 10, color: _grey),
          ),

          pw.SizedBox(height: 24),
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _border)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Decoration & Catering — Internal Report',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: _purple,
                  ),
                ),
                pw.Text(
                  'Generated ${DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return IoGuard.run<Uint8List>(
      label: 'dc_pdf.report',
      userMessage: 'Could not render the report PDF. Please try again.',
      op: () => pdf.save(),
    );
  }

  static pw.Widget _kpiBox(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _light,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(font: fontBold, fontSize: 13, color: _purple),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List> generateInvoice(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontMedium = await PdfGoogleFonts.interMedium();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          _buildHeader(invoice, font, fontBold),
          pw.SizedBox(height: 24),
          _buildParties(invoice, font, fontBold),
          pw.SizedBox(height: 20),
          _buildEventDetails(invoice, font, fontBold, fontMedium),
          pw.SizedBox(height: 20),
          _buildLineItems(invoice, font, fontBold, fontMedium),
          pw.SizedBox(height: 16),
          _buildTotals(invoice, font, fontBold, fontMedium),
          pw.SizedBox(height: 20),
          _buildPaymentStatus(invoice, font, fontBold, fontMedium),
          pw.SizedBox(height: 24),
          _buildFooter(invoice, font, fontBold),
        ],
      ),
    );

    return IoGuard.run<Uint8List>(
      label: 'dc_pdf.invoice',
      userMessage: 'Could not render the invoice PDF. Please try again.',
      op: () => pdf.save(),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final invNum = inv['invoiceNumber'] as String? ?? '—';
    final createdAt = inv['createdAt'] as String? ?? '';
    final date = createdAt.isNotEmpty ? createdAt.substring(0, 10) : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _purple,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: _white,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'DECORATION & CATERING',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: _white,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Professional Event Services',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: const PdfColor(1, 1, 1, 0.6),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 22,
                  color: _white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                invNum,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 13,
                  color: const PdfColor(1, 1, 1, 0.7),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                date.isNotEmpty
                    ? DateFormat('d MMM yyyy').format(DateTime.parse(date))
                    : '',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: const PdfColor(1, 1, 1, 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Parties ──────────────────────────────────────────────────────────────

  static pw.Widget _buildParties(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoBox(
            'Bill To',
            [
              inv['customerName'] as String? ?? '',
              inv['customerPhone'] as String? ?? '',
            ],
            font,
            fontBold,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _infoBox(
            'Event',
            [
              inv['eventId'] != null
                  ? 'Event #${inv['eventId']}'.substring(0, 16)
                  : '',
              inv['notes'] as String? ?? '',
            ],
            font,
            fontBold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoBox(
    String title,
    List<String> lines,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _light,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 9, color: _purple),
          ),
          pw.SizedBox(height: 6),
          ...lines
              .where((l) => l.isNotEmpty)
              .map(
                (l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    l,
                    style: pw.TextStyle(font: font, fontSize: 11, color: _dark),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── Event Details ─────────────────────────────────────────────────────────

  static pw.Widget _buildEventDetails(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final gst = (inv['gstPercent'] as num?)?.toDouble() ?? 18;
    final status = inv['status'] as String? ?? 'partial';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _detailChip('GST', '${gst.round()}%', font, fontBold),
          _detailChip('Status', status.toUpperCase(), font, fontBold),
          _detailChip('Currency', 'INR ₹', font, fontBold),
        ],
      ),
    );
  }

  static pw.Widget _detailChip(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 9, color: _grey),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: _dark),
        ),
      ],
    );
  }

  // ── Line Items ────────────────────────────────────────────────────────────

  static pw.Widget _buildLineItems(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final rawItems = inv['lineItems'] as List<dynamic>? ?? [];
    final items = rawItems.cast<Map<String, dynamic>>();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Line Items',
          style: pw.TextStyle(font: fontBold, fontSize: 12, color: _dark),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _purple),
              children: ['Description', 'Qty', 'Rate', 'Amount']
                  .map(
                    (h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 9,
                          color: _white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            // Data rows
            ...items.asMap().entries.map((e) {
              final item = e.value;
              final qty = (item['qty'] as num?)?.toInt() ?? 1;
              final rate =
                  (item['ratePaisa'] as num? ?? item['rate'] as num? ?? 0)
                      .toDouble();
              final rateFmt = item['ratePaisa'] != null ? rate / 100 : rate;
              final amount = qty * rateFmt;
              final isEven = e.key.isEven;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: isEven ? _white : _light),
                children: [
                  _cell(
                    item['desc'] as String? ??
                        item['description'] as String? ??
                        '',
                    font,
                  ),
                  _cell('$qty', font, center: true),
                  _cell('₹${_fmt.format(rateFmt)}', font),
                  _cell('₹${_fmt.format(amount)}', fontMedium),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 10, color: _dark),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  // ── Totals ────────────────────────────────────────────────────────────────

  static pw.Widget _buildTotals(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final subtotal = (inv['subtotalPaisa'] as num? ?? 0).toDouble() / 100;
    final gstAmt = (inv['gstAmountPaisa'] as num? ?? 0).toDouble() / 100;
    final discount = (inv['discountPaisa'] as num? ?? 0).toDouble() / 100;
    final total = (inv['totalPaisa'] as num? ?? 0).toDouble() / 100;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            children: [
              _totalRow('Subtotal', _fmtR.format(subtotal), font, fontMedium),
              pw.Divider(height: 1, color: _border),
              _totalRow(
                'GST (${(inv['gstPercent'] as num?)?.toInt() ?? 18}%)',
                _fmtR.format(gstAmt),
                font,
                fontMedium,
              ),
              if (discount > 0) ...[
                pw.Divider(height: 1, color: _border),
                _totalRow(
                  'Discount',
                  '- ${_fmtR.format(discount)}',
                  font,
                  fontMedium,
                  color: _green,
                ),
              ],
              pw.Divider(height: 1, color: _purple),
              pw.Container(
                color: _light,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 13,
                        color: _purple,
                      ),
                    ),
                    pw.Text(
                      _fmtR.format(total),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 13,
                        color: _purple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontMedium, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 10, color: _grey),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontMedium,
              fontSize: 10,
              color: color ?? _dark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Status ────────────────────────────────────────────────────────

  static pw.Widget _buildPaymentStatus(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontMedium,
  ) {
    final advance = (inv['advancePaidPaisa'] as num? ?? 0).toDouble() / 100;
    final balance = (inv['balancePaisa'] as num? ?? 0).toDouble() / 100;
    final isPaid = balance <= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: isPaid
            ? const PdfColor.fromInt(0xFFF0FDF4)
            : const PdfColor.fromInt(0xFFFFF7ED),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(
          color: isPaid
              ? const PdfColor.fromInt(0xFF86EFAC)
              : const PdfColor.fromInt(0xFFFBBF24),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isPaid ? '✓ PAYMENT COMPLETE' : 'PAYMENT SUMMARY',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: isPaid ? _green : const PdfColor.fromInt(0xFFD97706),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Advance Received: ${_fmtR.format(advance)}',
                style: pw.TextStyle(font: font, fontSize: 10, color: _grey),
              ),
            ],
          ),
          if (!isPaid)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Balance Due',
                  style: pw.TextStyle(font: font, fontSize: 10, color: _grey),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  _fmtR.format(balance),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 15,
                    color: const PdfColor.fromInt(0xFFDC2626),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(
    Map<String, dynamic> inv,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Thank you for choosing our services!',
            style: pw.TextStyle(font: fontBold, fontSize: 10, color: _purple),
          ),
          pw.Text(
            'Generated on ${DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 9, color: _grey),
          ),
        ],
      ),
    );
  }
}
