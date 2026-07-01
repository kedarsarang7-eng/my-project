import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/bill.dart';
import 'package:intl/intl.dart';

enum BillTheme { standard, modern, minimal }

/// M1 FIX: Thermal paper page format (80mm Ã— continuous roll)
/// Common thermal printer widths: 80mm (standard POS), 58mm (mini POS)
const _thermal80mm = PdfPageFormat(
  80 * PdfPageFormat.mm, // width
  double.infinity, // height (continuous roll)
  marginAll: 4 * PdfPageFormat.mm,
);

const _thermal58mm = PdfPageFormat(
  58 * PdfPageFormat.mm,
  double.infinity,
  marginAll: 3 * PdfPageFormat.mm,
);

class BillPrintService {
  static Future<void> generateAndPrintBillPDF(
    Bill bill,
    String customerName,
    String ownerName,
    String ownerPhone,
    String ownerAddress, {
    bool printDirectly = true,
    BillTheme theme = BillTheme.standard,

    /// Business type label for bill header (e.g. 'Hardware Store', 'Pharmacy')
    String businessTypeLabel = 'Retail Store',

    /// M1 FIX: Set to true for thermal printers (80mm paper).
    /// Set to '58mm' string for mini thermal printers.
    bool isThermal = false,
    String thermalWidth = '80mm', // '80mm' or '58mm'
    /// Max print retry attempts before falling back to PDF share
    int maxPrintRetries = 3,
  }) async {
    final pdf = pw.Document();

    // Format date and time
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final billDate = dateFormat.format(bill.date);
    final billTime = timeFormat.format(bill.date);

    // M1 FIX: Select page format based on printer type
    final PdfPageFormat pageFormat;
    final pw.EdgeInsets margin;
    if (isThermal) {
      pageFormat = thermalWidth == '58mm' ? _thermal58mm : _thermal80mm;
      margin = const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8);
    } else {
      pageFormat = PdfPageFormat.a4;
      margin = const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20);
    }

    pw.Widget pageContent;
    switch (theme) {
      case BillTheme.modern:
        pageContent = _buildModernPage(
          bill,
          customerName,
          ownerName,
          ownerPhone,
          ownerAddress,
          billDate,
          billTime,
          businessTypeLabel: businessTypeLabel,
        );
        break;
      case BillTheme.minimal:
        pageContent = _buildMinimalPage(
          bill,
          customerName,
          ownerName,
          ownerPhone,
          ownerAddress,
          billDate,
          billTime,
        );
        break;
      case BillTheme.standard:
        pageContent = _buildStandardPage(
          bill,
          customerName,
          ownerName,
          ownerPhone,
          ownerAddress,
          billDate,
          billTime,
          businessTypeLabel: businessTypeLabel,
        );
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: margin,
        build: (pw.Context context) => pageContent,
      ),
    );

    if (printDirectly) {
      // Retry loop for print failures (Bluetooth disconnect, etc.)
      Exception? lastError;
      for (int attempt = 1; attempt <= maxPrintRetries; attempt++) {
        try {
          await Printing.layoutPdf(
            onLayout: (_) => pdf.save(),
            name: 'Bill_${bill.id}.pdf',
          );
          return; // Success â€” exit
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (attempt < maxPrintRetries) {
            // Wait before retry (exponential backoff)
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      // All retries failed â€” fall back to PDF share
      try {
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'Bill_${bill.id}.pdf',
        );
      } catch (_) {
        // If share also fails, rethrow the original print error
        throw lastError ?? Exception('Print and share both failed');
      }
    } else {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Bill_${bill.id}.pdf',
      );
    }
  }

  // --- Standard Theme ---
  static pw.Widget _buildStandardPage(
    Bill bill,
    String customerName,
    String ownerName,
    String ownerPhone,
    String ownerAddress,
    String billDate,
    String billTime, {
    String businessTypeLabel = 'Retail Store',
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header with shop details
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                ownerName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                businessTypeLabel,
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 2),
              pw.Text(ownerAddress, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                'Mobile: $ownerPhone',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),
        pw.Divider(height: 1),
        pw.SizedBox(height: 10),

        // Bill details row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL TO:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Customer: $customerName',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Bill Date: $billDate',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Bill Time: $billTime',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        // Items table
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(4), // Item name
            1: const pw.FlexColumnWidth(1.5), // Price
            2: const pw.FlexColumnWidth(1.5), // Qty
            3: const pw.FlexColumnWidth(2), // Total
          },
          children: [
            // Header row â€” dynamic columns by business type
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF4CAF50),
              ),
              children: [
                _headerCell(_colLabel(businessTypeLabel, 'name')),
                _headerCell(
                  _colLabel(businessTypeLabel, 'price'),
                  align: pw.TextAlign.center,
                ),
                _headerCell(
                  _colLabel(businessTypeLabel, 'qty'),
                  align: pw.TextAlign.center,
                ),
                _headerCell('Total (Rs.)', align: pw.TextAlign.right),
              ],
            ),
            // Item rows
            ...bill.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isEven = index % 2 == 0;
              final bgColor = isEven
                  ? const PdfColor.fromInt(0xFFF5F5F5)
                  : PdfColors.white;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bgColor),
                children: [
                  _dataCell(item.vegName),
                  _dataCell(
                    '?${item.pricePerKg.toStringAsFixed(2)}',
                    align: pw.TextAlign.center,
                  ),
                  _dataCell(
                    item.qtyKg.toStringAsFixed(2),
                    align: pw.TextAlign.center,
                  ),
                  _dataCell(
                    '?${item.total.toStringAsFixed(2)}',
                    align: pw.TextAlign.right,
                    isBold: true,
                  ),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 12),

        // Summary section â€” GST-compliant (PRT-03 fix)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _summaryRow('Subtotal:', bill.subtotal),
                if (bill.discountApplied > 0)
                  _summaryRow(
                    'Discount:',
                    -bill.discountApplied,
                    isNegative: true,
                  ),
                // GST Breakdown â€” required by GST Rule 46
                if (bill.totalTax > 0) ...[
                  pw.SizedBox(height: 4),
                  if (!bill.isInterState) ...[
                    _summaryRow(
                      'CGST:',
                      bill.items.fold(0.0, (s, i) => s + i.cgst),
                    ),
                    _summaryRow(
                      'SGST:',
                      bill.items.fold(0.0, (s, i) => s + i.sgst),
                    ),
                  ],
                  if (bill.isInterState)
                    _summaryRow(
                      'IGST:',
                      bill.items.fold(0.0, (s, i) => s + i.igst),
                    ),
                  _summaryRow('Tax Total:', bill.totalTax),
                ],
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    color: const PdfColor.fromInt(0xFFE8F5E9),
                  ),
                  child: _summaryRow('TOTAL:', bill.grandTotal, isBold: true),
                ),
              ],
            ),
          ),
        ),

        pw.SizedBox(height: 12),
        _buildStatusAndSignature(bill),
      ],
    );
  }

  // --- Modern Theme ---
  static pw.Widget _buildModernPage(
    Bill bill,
    String customerName,
    String ownerName,
    String ownerPhone,
    String ownerAddress,
    String billDate,
    String billTime, {
    String businessTypeLabel = 'Retail Store',
  }) {
    const primaryColor = PdfColor.fromInt(0xFF1976D2); // Blue
    const accentColor = PdfColor.fromInt(0xFFBBDEFB); // Light Blue

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Modern Header
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ownerName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    businessTypeLabel,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    ownerPhone,
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                  pw.Text(
                    ownerAddress,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // Customer & Bill Info
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INVOICE TO',
                  style: const pw.TextStyle(color: PdfColors.grey),
                ),
                pw.Text(
                  customerName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE NO: ${bill.id.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Date: $billDate $billTime'),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // Modern Table
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.vertical(
                  top: pw.Radius.circular(4),
                ),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Item',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Price',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Qty',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Total',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...bill.items.map((item) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(item.vegName),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '?${item.pricePerKg.toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      item.qtyKg.toStringAsFixed(2),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '?${item.total.toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),

        pw.Divider(),
        pw.SizedBox(height: 10),

        // Summary â€” GST-compliant (PRT-03 fix)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 200,
            child: pw.Column(
              children: [
                _summaryRow('Subtotal', bill.subtotal),
                if (bill.discountApplied > 0)
                  _summaryRow(
                    'Discount',
                    -bill.discountApplied,
                    isNegative: true,
                  ),
                // GST Breakdown â€” required by GST Rule 46
                if (bill.totalTax > 0) ...[
                  if (!bill.isInterState) ...[
                    _summaryRow(
                      'CGST',
                      bill.items.fold(0.0, (s, i) => s + i.cgst),
                    ),
                    _summaryRow(
                      'SGST',
                      bill.items.fold(0.0, (s, i) => s + i.sgst),
                    ),
                  ],
                  if (bill.isInterState)
                    _summaryRow(
                      'IGST',
                      bill.items.fold(0.0, (s, i) => s + i.igst),
                    ),
                ],
                pw.Divider(),
                _summaryRow('Total Amount', bill.grandTotal, isBold: true),
              ],
            ),
          ),
        ),

        pw.Spacer(),
        _buildStatusAndSignature(bill),
      ],
    );
  }

  // --- Minimal Theme ---
  static pw.Widget _buildMinimalPage(
    Bill bill,
    String customerName,
    String ownerName,
    String ownerPhone,
    String ownerAddress,
    String billDate,
    String billTime,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Minimal Header
        pw.Text(
          ownerName.toUpperCase(),
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(ownerAddress),
        pw.Text('Phone: $ownerPhone'),

        pw.SizedBox(height: 30),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('To: $customerName', style: pw.TextStyle(fontSize: 16)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: $billDate'),
                pw.Text('Time: $billTime'),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),
        pw.Divider(thickness: 2),

        // Simple List
        ...bill.items.map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text(item.vegName)),
                pw.Text(
                  '${item.qtyKg} kg x ?${item.pricePerKg} = ?${item.total.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),

        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),

        // GST Breakdown â€” required by GST Rule 46
        if (bill.totalTax > 0) ...[
          if (!bill.isInterState) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CGST'),
                pw.Text(
                  '?${bill.items.fold(0.0, (s, i) => s + i.cgst).toStringAsFixed(2)}',
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SGST'),
                pw.Text(
                  '?${bill.items.fold(0.0, (s, i) => s + i.sgst).toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
          if (bill.isInterState)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('IGST'),
                pw.Text(
                  '?${bill.items.fold(0.0, (s, i) => s + i.igst).toStringAsFixed(2)}',
                ),
              ],
            ),
          pw.SizedBox(height: 4),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '?${bill.grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),

        pw.SizedBox(height: 40),
        pw.Center(child: pw.Text('Thank You')),
      ],
    );
  }

  static pw.Widget _buildStatusAndSignature(Bill bill) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              width: 2,
              color: bill.status == 'Paid'
                  ? const PdfColor.fromInt(0xFF4CAF50)
                  : const PdfColor.fromInt(0xFFF44336),
            ),
            color: bill.status == 'Paid'
                ? const PdfColor.fromInt(0xFFC8E6C9)
                : const PdfColor.fromInt(0xFFFFCDD2),
          ),
          child: pw.Text(
            'Status: ${bill.status}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: bill.status == 'Paid'
                  ? const PdfColor.fromInt(0xFF1B5E20)
                  : const PdfColor.fromInt(0xFFC62828),
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBox('Seller Signature'),
            _signatureBox('Customer Signature'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Thank you for your business!',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _headerCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isNegative = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '?${amount.abs().toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBox(String label) {
    return pw.SizedBox(
      width: 100,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            height: 30,
            width: 80,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  /// Business-type-aware column labels for bill table headers.
  /// Petrol pump: Fuel Type, Rate/Ltr, Litres
  /// Default: Item Name, Price, Qty
  static String _colLabel(String businessType, String col) {
    final bt = businessType.toLowerCase();
    if (bt.contains('petrol') || bt.contains('fuel') || bt.contains('pump')) {
      switch (col) {
        case 'name':
          return 'Fuel Type';
        case 'price':
          return 'Rate/Ltr';
        case 'qty':
          return 'Litres';
        default:
          return col;
      }
    }
    if (bt.contains('pharmacy') || bt.contains('medical')) {
      switch (col) {
        case 'name':
          return 'Medicine';
        case 'price':
          return 'MRP';
        case 'qty':
          return 'Qty';
        default:
          return col;
      }
    }
    if (bt.contains('hardware')) {
      switch (col) {
        case 'name':
          return 'Item';
        case 'price':
          return 'Price';
        case 'qty':
          return 'Qty';
        default:
          return col;
      }
    }
    // Default (vegetable/retail)
    switch (col) {
      case 'name':
        return 'Item Name';
      case 'price':
        return 'Price/KG';
      case 'qty':
        return 'Qty (KG)';
      default:
        return col;
    }
  }
}
