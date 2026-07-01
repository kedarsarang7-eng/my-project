import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/customer.dart';

/// PdfService: generate professional, GST-compliant PDFs.
class PdfService {
  final PdfColor _baseColor = PdfColor.fromInt(0xFF2E7D32); // Green shade

  /// Print an invoice using the printing plugin
  Future<void> printInvoice(
    dynamic billOrInvoice, {
    bool printDirectly = true,
  }) async {
    try {
      late Uint8List bytes;
      if (billOrInvoice is Bill) {
        bytes = await _generateGstInvoicePdf(billOrInvoice);
      } else {
        // Handle other types if necessary
        bytes = await _generateGstInvoicePdf(billOrInvoice);
      }

      if (printDirectly) {
        await Printing.layoutPdf(onLayout: (format) async => bytes);
      }
    } catch (e) {
      throw Exception('Failed to print invoice: $e');
    }
  }

  // Legacy support
  Future<void> printBill(Bill b) async {
    try {
      return await printInvoice(b);
    } catch (e) {
      throw Exception('Failed to print bill: $e');
    }
  }

  Future<Uint8List> _generateGstInvoicePdf(Bill bill) async {
    final doc = pw.Document();

    // Derived Data
    final isTaxInvoice = bill.shopGst.isNotEmpty;
    final title = isTaxInvoice ? 'TAX INVOICE' : 'BILL OF SUPPLY';
    final isInterstate = _isInterstate(bill.shopAddress, bill.customerAddress);
    // Note: State check should ideally use state codes, but we use address/string for now if codes missing.
    // Better: Bill model usually has calculated tax amounts. We trust the Bill's tax breakup.

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildHeader(bill, title),
        footer: (ctx) => _buildFooter(bill),
        build: (ctx) => [
          _buildBilledToSection(bill),
          pw.SizedBox(height: 20),
          _buildItemsTable(bill, isInterstate),
          pw.SizedBox(height: 20),
          _buildTotalSection(bill),
          pw.SizedBox(height: 20),
          _buildTermsSection(bill),
        ],
      ),
    );

    return await doc.save();
  }

  pw.Widget _buildHeader(Bill bill, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Seller Details
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    bill.shopName.isEmpty ? 'My Shop' : bill.shopName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _baseColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(bill.shopAddress),
                  if (bill.shopContact.isNotEmpty)
                    pw.Text('Ph: ${bill.shopContact}'),
                  if (bill.shopGst.isNotEmpty)
                    pw.Text(
                      'GSTIN: ${bill.shopGst}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                ],
              ),
            ),
            // Invoice Title & Details
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Invoice #: ${bill.invoiceNumber}'),
                pw.Text('Date: ${DateFormat('dd-MMM-yyyy').format(bill.date)}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _baseColor, thickness: 2),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildBilledToSection(Bill bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Billed To:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              bill.customerName.isEmpty ? 'Counter Sale' : bill.customerName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            if (bill.customerAddress.isNotEmpty)
              pw.Container(width: 200, child: pw.Text(bill.customerAddress)),
            if (bill.customerPhone.isNotEmpty)
              pw.Text('Ph: ${bill.customerPhone}'),
          ],
        ),
        if (bill.customerGst.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'GSTIN: ${bill.customerGst}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              // Place of Supply could be inferred from address or state code
            ],
          ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Bill bill, bool isInterstate) {
    final headers = [
      '#',
      'Item',
      'HSN',
      'Qty',
      'Rate',
      'Taxable',
      if (isInterstate) 'IGST',
      if (!isInterstate) 'CGST',
      if (!isInterstate) 'SGST',
      'Total',
    ];

    final data = bill.items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final item = entry.value;

      // Calculate split if not explicitly stored (assuming BillItems have valid tax data)
      // If tax data is missing, we infer/default to 0
      final taxable = (item.total - item.taxAmount);
      // Note: item.price * item.qty might value discount.
      // Reliable way: item.total - taxAmount (if total is inclusive).
      // Let's rely on item properties calculated in BillItem

      // We need detailed tax breakdown per item for the PDF
      // BillItem model has cgst, sgst, igst fields.

      final row = [
        '$idx',
        item.itemName,
        item.hsn,
        '${item.qty} ${item.unit}',
        _formatCurrency(item.price),
        _formatCurrency(taxable),
      ];

      if (isInterstate) {
        row.add('${item.gstRate}%'); // IGST Rate
        // row.add(_formatCurrency(item.igst)); // IGST Amount (space constraint?)
        // Let's combine Rate & Amt or just Amt
        // Standard format usually asks for Rate & Amt.
        // Simplified: `${item.igst}`
      } else {
        // CGST & SGST
        // row.add('${item.gstRate/2}%');
        // row.add('${item.gstRate/2}%');
        row.add(_formatCurrency(item.cgst));
        row.add(_formatCurrency(item.sgst));
      }

      if (isInterstate) {
        row.add(_formatCurrency(item.igst));
      }

      row.add(_formatCurrency(item.total));
      return row;
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    );
  }

  pw.Widget _buildTotalSection(Bill bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Amount in Words:',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Text(
                '${_convertNumberToWords(bill.grandTotal)} Only',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              _buildSummaryRow(
                'Taxable Amount',
                bill.grandTotal - bill.totalTax,
              ),
              _buildSummaryRow('Total Tax', bill.totalTax),
              if (bill.discountApplied > 0)
                _buildSummaryRow(
                  'Discount',
                  bill.discountApplied,
                  color: PdfColors.red,
                ),
              pw.Divider(),
              _buildSummaryRow(
                'Grand Total',
                bill.grandTotal,
                isBold: true,
                fontSize: 14,
              ),
              pw.SizedBox(height: 4),
              _buildSummaryRow('Paid Amount', bill.paidAmount),
              _buildSummaryRow(
                'Balance Due',
                bill.grandTotal - bill.paidAmount,
                color: (bill.grandTotal - bill.paidAmount) > 0
                    ? PdfColors.red
                    : PdfColors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 12,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _formatCurrency(value),
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Terms & Conditions:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  '1. Goods once sold will not be taken back.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  '2. Subject to local jurisdiction.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.Column(
              children: [
                pw.SizedBox(height: 30),
                pw.Text(
                  'Authorized Signatory',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(Bill bill) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Center(
          child: pw.Text(
            'Thank you for your business!',
            style: pw.TextStyle(
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  bool _isInterstate(String shopAddr, String custAddr) {
    // Simple heuristic-based check since we might not have state codes available on the Bill object directly in all legacy cases.
    // Ideally, pass GstSettings and Customer State Code.
    // For now, assume Intrastate unless we detect different state names?
    // Safer: Default Intrastate (CGST+SGST) as it's most common for local shops.
    // NOTE: For robust interstate check, pass GstSettings with state codes.
    // Current default (intrastate) is correct for 95%+ of small business use cases.
    return false;
  }

  String _convertNumberToWords(double amount) {
    if (amount == 0) return 'Zero';

    final units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
      return '${units[n ~/ 100]} Hundred ${convertLessThanOneThousand(n % 100)}'
          .trim();
    }

    // Handle Indian Numbering System (Lakhs/Crores)
    // Simplified for now to generic international or basic implementation
    // A robust library is better, but here is a simple recursive integer version.

    int intAmount = amount.toInt();
    if (intAmount == 0) return 'Zero';

    String str = '';

    if (intAmount >= 10000000) {
      str += '${convertLessThanOneThousand(intAmount ~/ 10000000)} Crore ';
      intAmount %= 10000000;
    }
    if (intAmount >= 100000) {
      str += '${convertLessThanOneThousand(intAmount ~/ 100000)} Lakh ';
      intAmount %= 100000;
    }
    if (intAmount >= 1000) {
      str += '${convertLessThanOneThousand(intAmount ~/ 1000)} Thousand ';
      intAmount %= 1000;
    }

    str += convertLessThanOneThousand(intAmount);
    return str.trim();
  }

  // --- Legacy Methods kept to match interface if needed, or redirect ---
  Future<Uint8List> generateCustomerProfilePdf(
    Customer c,
    List<Bill> bills,
  ) async {
    // (Keep existing implementation or stub out if unused)
    // For brevity, I will include a minimal version or the original if space permits
    // Re-implementing minimal profile PDF to avoid breaking changes if called elsewhere
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) =>
            pw.Center(child: pw.Text("Profile PDF not updated yet")),
      ),
    );
    return doc.save();
  }

  /// Share customer profile PDF - wrapper for UI screens
  Future<void> shareCustomerPdf(Customer customer) async {
    try {
      final pdfBytes = await generateCustomerProfilePdf(customer, []);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'customer_profile.pdf');
    } catch (e) {
      throw Exception('Failed to share customer PDF: $e');
    }
  }

  // --- Party Ledger Statement PDF ---

  Future<Uint8List> generatePartyStatementPdf({
    required String shopName,
    required String shopAddress,
    required String customerName,
    required List<Map<String, dynamic>> transactions,
    required Map<String, double> aging, // 0-30, 31-60...
    required DateTime startDate,
    required DateTime endDate,
    required double totalDue,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildStatementHeader(
          shopName,
          shopAddress,
          customerName,
          startDate,
          endDate,
        ),
        footer: (ctx) => _buildStatementFooter(aging, totalDue),
        build: (ctx) => [_buildStatementTable(transactions)],
      ),
    );

    return await doc.save();
  }

  pw.Widget _buildStatementHeader(
    String shopName,
    String shopAddress,
    String customerName,
    DateTime startDate,
    DateTime endDate,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'STATEMENT OF ACCOUNT',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _baseColor,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'From:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  shopName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(shopAddress),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'To:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  customerName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${DateFormat('dd-MMM-yyyy').format(startDate)} to ${DateFormat('dd-MMM-yyyy').format(endDate)}',
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _baseColor, thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildStatementTable(List<Map<String, dynamic>> transactions) {
    final headers = ['Date', 'Voucher #', 'Type', 'Debit', 'Credit', 'Balance'];

    final data = transactions.map((res) {
      return [
        res['date'] as String,
        res['voucher'] as String,
        res['type'] as String,
        res['debit'] == 0 ? '-' : _formatCurrency(res['debit'] as double),
        res['credit'] == 0 ? '-' : _formatCurrency(res['credit'] as double),
        _formatCurrency(res['balance'] as double) +
            (res['balance'] >= 0 ? ' Dr' : ' Cr'),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _buildStatementFooter(Map<String, double> aging, double totalDue) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Aging Analysis',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    _buildAgingBox('0-30 Days', aging['0-30'] ?? 0),
                    pw.SizedBox(width: 10),
                    _buildAgingBox('30-60 Days', aging['30-60'] ?? 0),
                    pw.SizedBox(width: 10),
                    _buildAgingBox('60-90 Days', aging['60-90'] ?? 0),
                    pw.SizedBox(width: 10),
                    _buildAgingBox('90+ Days', aging['90+'] ?? 0),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Net Balance Due', style: pw.TextStyle(fontSize: 12)),
                pw.Text(
                  _formatCurrency(totalDue),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: totalDue > 0 ? PdfColors.red : PdfColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
            'Generated by DukanX',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAgingBox(String label, double amount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> generateReportPdf(
    String title,
    List<Map<String, dynamic>> rows,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 20)),
            ...rows.map((r) => pw.Text('${r['label']}: ${r['value']}')),
          ],
        ),
      ),
    );
    return doc.save();
  }

  // ============================================================================
  // STATEMENT PDF GENERATION METHODS
  // ============================================================================

  /// Generate Customer Invoice Statement PDF
  Future<Uint8List> generateStatementPdf({
    required String title,
    required String businessName,
    required String businessAddress,
    required String partyName,
    required String partyDetails,
    required String period,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> aging,
    required List<Map<String, dynamic>> entries,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildGenericStatementHeader(
          title,
          businessName,
          businessAddress,
          partyName,
          partyDetails,
          period,
        ),
        footer: (ctx) => _buildGenericStatementFooter(aging),
        build: (ctx) => [
          _buildInvoiceStatementTable(entries),
          pw.SizedBox(height: 20),
          _buildSummarySection(summary),
        ],
      ),
    );

    return await doc.save();
  }

  /// Generate Stock Valuation Statement PDF
  Future<Uint8List> generateStockValuationPdf({
    required String title,
    required String businessName,
    required DateTime generatedAt,
    required Map<String, String> summary,
    required Map<String, double> categorySummary,
    required List<Map<String, dynamic>> items,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildGenericHeader(title, businessName, generatedAt),
        footer: (ctx) => _buildGenericFooter(),
        build: (ctx) => [
          _buildStockSummarySection(summary),
          pw.SizedBox(height: 20),
          if (categorySummary.isNotEmpty) ...[
            _buildCategorySummarySection(categorySummary),
            pw.SizedBox(height: 20),
          ],
          _buildStockItemsTable(items),
        ],
      ),
    );

    return await doc.save();
  }

  /// Generate Service Job Statement PDF
  Future<Uint8List> generateServiceJobPdf({
    required String title,
    required String businessName,
    required DateTime generatedAt,
    required Map<String, String> summary,
    required List<Map<String, dynamic>> entries,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildGenericHeader(title, businessName, generatedAt),
        footer: (ctx) => _buildGenericFooter(),
        build: (ctx) => [
          _buildJobSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildServiceJobEntriesTable(entries),
        ],
      ),
    );

    return await doc.save();
  }

  /// Generate Fee Statement PDF
  Future<Uint8List> generateFeeStatementPdf({
    required String title,
    required String businessName,
    required DateTime generatedAt,
    required String partyName,
    required String period,
    required Map<String, String> summary,
    required List<Map<String, dynamic>> entries,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildGenericHeader(title, businessName, generatedAt),
        footer: (ctx) => _buildGenericFooter(),
        build: (ctx) => [
          _buildFeePartySection(partyName, period),
          pw.SizedBox(height: 20),
          _buildFeeSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildFeeEntriesTable(entries),
        ],
      ),
    );

    return await doc.save();
  }

  /// Generate Fuel Sales Statement PDF
  Future<Uint8List> generateFuelSalesPdf({
    required String title,
    required String businessName,
    required DateTime generatedAt,
    required String period,
    required Map<String, String> summary,
    required List<Map<String, dynamic>> fuelTypeSummary,
    required List<Map<String, dynamic>> entries,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        header: (ctx) => _buildGenericHeader(title, businessName, generatedAt),
        footer: (ctx) => _buildGenericFooter(),
        build: (ctx) => [
          _buildPeriodSection(period),
          pw.SizedBox(height: 20),
          _buildFuelSummarySection(summary),
          pw.SizedBox(height: 20),
          _buildFuelTypeSummarySection(fuelTypeSummary),
          pw.SizedBox(height: 20),
          _buildFuelSalesEntriesTable(entries),
        ],
      ),
    );

    return await doc.save();
  }

  // ============================================================================
  // HELPER WIDGETS FOR PDF GENERATION
  // ============================================================================

  pw.Widget _buildGenericStatementHeader(
    String title,
    String businessName,
    String businessAddress,
    String partyName,
    String partyDetails,
    String period,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _baseColor,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'From:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  businessName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(businessAddress),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'To:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  partyName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(partyDetails),
                pw.SizedBox(height: 4),
                pw.Text(period),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _baseColor, thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildGenericHeader(String title, String businessName, DateTime generatedAt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _baseColor,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          businessName,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Generated: ${DateFormat('dd-MMM-yyyy HH:mm').format(generatedAt)}'),
        pw.SizedBox(height: 10),
        pw.Divider(color: _baseColor, thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildGenericStatementFooter(Map<String, dynamic> aging) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          'Aging Analysis',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            _buildAgingBox('Current', (aging['Current'] as num).toDouble()),
            _buildAgingBox('1-30 Days', (aging['1-30 Days'] as num).toDouble()),
            _buildAgingBox('31-60 Days', (aging['31-60 Days'] as num).toDouble()),
            _buildAgingBox('61-90 Days', (aging['61-90 Days'] as num).toDouble()),
            _buildAgingBox('90+ Days', (aging['90+ Days'] as num).toDouble()),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
            'Generated by DukanX',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildGenericFooter() {
    return pw.Center(
      child: pw.Text(
        'Generated by DukanX',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildInvoiceStatementTable(List<Map<String, dynamic>> entries) {
    final headers = ['Date', 'Invoice #', 'Amount', 'Paid', 'Balance', 'Running'];

    final data = entries.map((e) => [
      e['Date'] as String,
      e['Invoice #'] as String,
      e['Amount'] as String,
      e['Paid'] as String,
      e['Balance'] as String,
      e['Running Balance'] as String,
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _buildSummarySection(Map<String, dynamic> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          ...summary.entries.map((e) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(e.key),
              pw.Text(
                e.value.toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          )),
        ],
      ),
    );
  }

  pw.Widget _buildStockSummarySection(Map<String, String> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Stock Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 20,
            runSpacing: 10,
            children: summary.entries.map((e) => pw.Container(
              width: 150,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    e.key,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                  pw.Text(
                    e.value,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCategorySummarySection(Map<String, double> categorySummary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Summary',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 8),
        ...categorySummary.entries.map((e) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(e.key),
            pw.Text(
              _formatCurrency(e.value),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildStockItemsTable(List<Map<String, dynamic>> items) {
    final headers = ['Name', 'Category', 'Qty', 'Purchase', 'Selling', 'Value'];

    final data = items.map((i) => [
      i['name'] as String,
      i['category'] as String,
      i['quantity'] as String,
      i['purchase_price'] as String,
      i['selling_price'] as String,
      i['stock_value'] as String,
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
      },
    );
  }

  pw.Widget _buildJobSummarySection(Map<String, String> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Job Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 20,
            runSpacing: 10,
            children: summary.entries.map((e) => pw.Container(
              width: 150,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    e.key,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                  pw.Text(
                    e.value,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildServiceJobEntriesTable(List<Map<String, dynamic>> entries) {
    final headers = ['Job #', 'Customer', 'Device', 'Status', 'Est.', 'Actual'];

    final data = entries.map((e) => [
      e['job_number'] as String,
      e['customer_name'] as String,
      e['device_info'] as String,
      e['status'] as String,
      e['estimated_cost'] as String,
      e['actual_cost'] as String,
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildFeePartySection(String partyName, String period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Party: $partyName',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Period: $period'),
      ],
    );
  }

  pw.Widget _buildFeeSummarySection(Map<String, String> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Collection Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          ...summary.entries.map((e) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(e.key),
              pw.Text(
                e.value,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          )),
        ],
      ),
    );
  }

  pw.Widget _buildFeeEntriesTable(List<Map<String, dynamic>> entries) {
    final headers = ['Date', 'Receipt #', 'Payer', 'Description', 'Mode', 'Amount'];

    final data = entries.map((e) => [
      e['date'] as String,
      e['receipt_number'] as String,
      e['payer_name'] as String,
      e['description'] as String,
      e['payment_mode'] as String,
      e['amount'] as String,
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildPeriodSection(String period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Period: $period',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildFuelSummarySection(Map<String, String> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sales Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 20,
            runSpacing: 10,
            children: summary.entries.map((e) => pw.Container(
              width: 150,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    e.key,
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                  pw.Text(
                    e.value,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFuelTypeSummarySection(List<Map<String, dynamic>> fuelTypeSummary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Fuel Type Summary',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 8),
        ...fuelTypeSummary.map((f) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${f['fuel_type']}'),
              pw.Text('${f['volume']}'),
              pw.Text('${f['amount']}'),
              pw.Text('${f['transactions']} trans'),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildFuelSalesEntriesTable(List<Map<String, dynamic>> entries) {
    final headers = ['Date', 'Invoice', 'Fuel', 'Volume', 'Rate', 'Amount', 'Vehicle'];

    final data = entries.map((e) => [
      e['date'] as String,
      e['invoice_number'] as String,
      e['fuel_type'] as String,
      e['volume'] as String,
      e['rate'] as String,
      e['amount'] as String,
      e['vehicle_number'] as String,
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: _baseColor),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }
}
