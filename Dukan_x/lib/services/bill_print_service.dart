import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/bill.dart';
import 'package:intl/intl.dart';

enum BillTheme { standard, modern, minimal }

class BillPrintService {
  static Future<void> generateAndPrintBillPDF(
    Bill bill,
    String customerName,
    String ownerName,
    String ownerPhone,
    String ownerAddress, {
    bool printDirectly = true,
    BillTheme theme = BillTheme.standard,
  }) async {
    try {
      final pdf = pw.Document();

      // Format date and time
      final dateFormat = DateFormat('dd/MM/yyyy');
      final timeFormat = DateFormat('hh:mm a');
      final billDate = dateFormat.format(bill.date);
      final billTime = timeFormat.format(bill.date);

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
          );
          break;
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          build: (pw.Context context) => pageContent,
        ),
      );

      if (printDirectly) {
        await Printing.layoutPdf(
          onLayout: (_) => pdf.save(),
          name: 'Bill_${bill.id}.pdf',
        );
      } else {
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'Bill_${bill.id}.pdf',
        );
      }
    } catch (e) {
      throw Exception('Failed to generate/print bill: $e');
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
    String billTime,
  ) {
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
                'Vegetable Supplier',
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
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF4CAF50),
              ),
              children: [
                _headerCell('Vegetable Name'),
                _headerCell('Price/KG', align: pw.TextAlign.center),
                _headerCell('Qty (KG)', align: pw.TextAlign.center),
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
                    '₹${item.pricePerKg.toStringAsFixed(0)}',
                    align: pw.TextAlign.center,
                  ),
                  _dataCell(
                    item.qtyKg.toStringAsFixed(2),
                    align: pw.TextAlign.center,
                  ),
                  _dataCell(
                    '₹${item.total.toStringAsFixed(2)}',
                    align: pw.TextAlign.right,
                    isBold: true,
                  ),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 12),

        // Summary section
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
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    color: const PdfColor.fromInt(0xFFE8F5E9),
                  ),
                  child: _summaryRow(
                    'TOTAL:',
                    bill.subtotal - bill.discountApplied,
                    isBold: true,
                  ),
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
    String billTime,
  ) {
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
                    'Vegetable Supplier',
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
                      '₹${item.pricePerKg.toStringAsFixed(0)}',
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
                      '₹${item.total.toStringAsFixed(2)}',
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

        // Summary
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
                pw.Divider(),
                _summaryRow(
                  'Total Amount',
                  bill.subtotal - bill.discountApplied,
                  isBold: true,
                ),
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
                  '${item.qtyKg} kg x ₹${item.pricePerKg} = ₹${item.total.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),

        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '₹${(bill.subtotal - bill.discountApplied).toStringAsFixed(2)}',
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
          '₹${amount.abs().toStringAsFixed(2)}',
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
}
