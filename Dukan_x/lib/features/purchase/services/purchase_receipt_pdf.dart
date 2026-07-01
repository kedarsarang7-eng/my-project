// ============================================================================
// Purchase Receipt PDF Generator
// ============================================================================
// Quick Win: Generate printable PDF receipt after submission
// ============================================================================

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/logger_service.dart';
import '../models/scan_bill_models.dart';

class PurchaseReceiptPdf {
  final LoggerService _logger = sl<LoggerService>();

  /// Generate and print purchase receipt
  Future<void> generateAndPrint(PurchaseEntry entry) async {
    try {
      final pdf = await _generatePdf(entry);

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Purchase_${entry.rid}.pdf',
      );

      _logger.info('Purchase receipt printed', {'rid': entry.rid});
    } catch (e, stackTrace) {
      _logger.error('Failed to print receipt', {
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Generate and share PDF file
  Future<File> generateAndSave(PurchaseEntry entry) async {
    try {
      final pdf = await _generatePdf(entry);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/purchase_${entry.rid}.pdf');
      await file.writeAsBytes(await pdf.save());

      _logger.info('Purchase receipt saved', {
        'rid': entry.rid,
        'path': file.path,
      });
      return file;
    } catch (e, stackTrace) {
      _logger.error('Failed to save receipt', {
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  Future<pw.Document> _generatePdf(PurchaseEntry entry) async {
    final pdf = pw.Document();

    // Load font
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final boldFont = pw.Font.ttf(boldFontData);

    final dateFormat = DateFormat('dd MMM yyyy');
    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PURCHASE RECEIPT',
                      style: pw.TextStyle(font: boldFont, fontSize: 24),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'DukanX - ${entry.verticalType.toUpperCase()}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Receipt Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Receipt ID:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.Text(
                        entry.rid,
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.Text(
                        dateTimeFormat.format(DateTime.parse(entry.createdAt)),
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Supplier Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SUPPLIER',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      entry.supplierName ?? 'Unknown Supplier',
                      style: pw.TextStyle(font: boldFont, fontSize: 14),
                    ),
                    if (entry.billNumber != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Bill: ${entry.billNumber}',
                        style: pw.TextStyle(font: font, fontSize: 11),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Bill Date: ${dateFormat.format(DateTime.parse(entry.billDate))}',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Items Table Header
              pw.Text(
                'ITEMS',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 8),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Product
                  1: const pw.FlexColumnWidth(1.5), // Qty
                  2: const pw.FlexColumnWidth(1.5), // Price
                  3: const pw.FlexColumnWidth(1.5), // Total
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Product', boldFont, isHeader: true),
                      _buildTableCell(
                        'Qty',
                        boldFont,
                        isHeader: true,
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        'Price',
                        boldFont,
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        'Total',
                        boldFont,
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  // Data rows
                  ...entry.lineItems.map((item) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                          item['productName'] ?? 'Unknown',
                          font,
                          subtext: item['batchNo'] != null
                              ? 'Batch: ${item['batchNo']}'
                              : null,
                        ),
                        _buildTableCell(
                          '${item['quantity']} ${item['unit']}',
                          font,
                          align: pw.TextAlign.center,
                        ),
                        _buildTableCell(
                          '₹${(item['unitPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          font,
                          align: pw.TextAlign.right,
                        ),
                        _buildTableCell(
                          '₹${(item['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          boldFont,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 24),

              // Totals
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (entry.gstAmount != null) ...[
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'GST Amount: ',
                            style: pw.TextStyle(font: font, fontSize: 11),
                          ),
                          pw.Text(
                            '₹${entry.gstAmount!.toStringAsFixed(2)}',
                            style: pw.TextStyle(font: font, fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Divider(),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'TOTAL: ',
                          style: pw.TextStyle(font: boldFont, fontSize: 14),
                        ),
                        pw.Text(
                          '₹${entry.totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 18,
                            color: PdfColors.blue,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: entry.paymentStatus == 'paid'
                            ? PdfColors.green100
                            : PdfColors.orange100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        entry.paymentStatus.toUpperCase(),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 10,
                          color: entry.paymentStatus == 'paid'
                              ? PdfColors.green800
                              : PdfColors.orange800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for using DukanX!',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'This is a computer generated receipt.',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    String? subtext,
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.center
            ? pw.CrossAxisAlignment.center
            : align == pw.TextAlign.right
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(font: font, fontSize: isHeader ? 10 : 11),
            textAlign: align,
          ),
          if (subtext != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtext,
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey,
              ),
              textAlign: align,
            ),
          ],
        ],
      ),
    );
  }
}
