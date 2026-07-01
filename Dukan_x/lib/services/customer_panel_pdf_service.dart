import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Service to generate and download customer panel PDFs
class CustomerPanelPdfService {
  static Future<void> generateAndDownloadBillPDF({
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double total,
    required double pendingDues,
    required String reminders,
  }) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'DAILY VEGETABLE BILL',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'à¤®à¥‹ à¤¨à¤µà¤¦à¥ à¤°à¥ à¤—à¤¾ à¤¸à¤¬à¥ à¤œà¥€ à¤­à¤£à¥ à¤¡à¤¾à¤°',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Date: ${dateFormat.format(now)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(height: 1),
              pw.SizedBox(height: 12),

              // Customer Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Customer: $customerName',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Status: ${pendingDues > 0 ? 'PENDING' : 'PAID'}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: pendingDues > 0
                          ? PdfColors.red
                          : const PdfColor.fromInt(0xFF2E7D32),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF4CAF50),
                    ),
                    children: [
                      _pdfHeaderCell('Vegetable'),
                      _pdfHeaderCell('Price/KG', align: pw.TextAlign.center),
                      _pdfHeaderCell('Qty (KG)', align: pw.TextAlign.center),
                      _pdfHeaderCell('Total (Rs.)', align: pw.TextAlign.right),
                    ],
                  ),
                  // Data rows
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final bgColor = index % 2 == 0
                        ? const PdfColor.fromInt(0xFFF5F5F5)
                        : PdfColors.white;

                    final vegName = item['vegName'] ?? 'N/A';
                    final price = item['pricePerKg'] ?? 0;
                    final qty = item['quantity'] ?? 0;
                    final itemTotal = (price as num) * (qty as num);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgColor),
                      children: [
                        _pdfDataCell(vegName),
                        _pdfDataCell(
                          'â‚¹${price.toStringAsFixed(0)}',
                          align: pw.TextAlign.center,
                        ),
                        _pdfDataCell(
                          qty.toStringAsFixed(2),
                          align: pw.TextAlign.center,
                        ),
                        _pdfDataCell(
                          'â‚¹${itemTotal.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Summary
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _pdfSummaryRow('Total Amount:', total),
                      pw.SizedBox(height: 4),
                      _pdfSummaryRow('Pending Due:', pendingDues, isRed: true),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 1),
                          color: const PdfColor.fromInt(0xFFE8F5E9),
                        ),
                        child: _pdfSummaryRow(
                          'Amount Paid:',
                          total - pendingDues,
                          isBold: true,
                          isGreen: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              // Reminders
              if (reminders.isNotEmpty) ...[
                pw.Divider(height: 1),
                pw.SizedBox(height: 8),
                pw.Text(
                  'REMINDERS:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      width: 1,
                      color: const PdfColor.fromInt(0xFFFF9800),
                    ),
                    color: const PdfColor.fromInt(0xFFFFF3E0),
                  ),
                  child: pw.Text(
                    reminders,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Bill_${customerName}_${DateFormat('ddMMyyyy').format(now)}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to generate/share bill PDF: $e');
    }
  }

  static pw.Widget _pdfHeaderCell(
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

  static pw.Widget _pdfDataCell(
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

  static pw.Widget _pdfSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
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
          'â‚¹${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isRed
                ? PdfColors.red
                : isGreen
                ? const PdfColor.fromInt(0xFF2E7D32)
                : PdfColors.black,
          ),
        ),
      ],
    );
  }
}
