// ============================================================================
// CUSTOMER LEDGER PDF SERVICE
// ============================================================================
// Generates PDF statements for customer ledger
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/customer_ledger_repository.dart';
import '../data/customer_dashboard_repository.dart';
import '../../../core/accounting/money_math.dart';

class CustomerLedgerPdfService {
  static final CustomerLedgerPdfService _instance =
      CustomerLedgerPdfService._internal();
  factory CustomerLedgerPdfService() => _instance;
  CustomerLedgerPdfService._internal();

  /// Generate ledger statement PDF
  Future<Uint8List> generateLedgerPdf({
    required String customerName,
    required VendorConnection vendor,
    required List<LedgerEntry> entries,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    // Calculate summary using MoneyMath
    final totalDebit = MoneyMath.sum(
      entries.where((entry) => entry.isDebit).map((entry) => entry.amount),
    );
    final totalCredit = MoneyMath.sum(
      entries.where((entry) => !entry.isDebit).map((entry) => entry.amount),
    );
    final closingBalance = entries.isNotEmpty
        ? entries.first.runningBalance
        : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          _buildHeader(customerName, vendor, fromDate, toDate, dateFormat, now),
          pw.SizedBox(height: 20),

          // Summary Card
          _buildSummaryCard(totalDebit, totalCredit, closingBalance),
          pw.SizedBox(height: 20),

          // Ledger Table
          _buildLedgerTable(entries, dateFormat),
          pw.SizedBox(height: 30),

          // Footer
          _buildFooter(now),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(
    String customerName,
    VendorConnection vendor,
    DateTime? fromDate,
    DateTime? toDate,
    DateFormat dateFormat,
    DateTime now,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#6C5CE7'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LEDGER STATEMENT',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated: ${dateFormat.format(now)}',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#FFFFFFB3'),
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      customerName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Vendor',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#FFFFFFB3'),
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      vendor.vendorName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fromDate != null || toDate != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Period: ${fromDate != null ? dateFormat.format(fromDate) : 'Start'} - ${toDate != null ? dateFormat.format(toDate) : 'Today'}',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#FFFFFFB3'),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildSummaryCard(
    double totalDebit,
    double totalCredit,
    double closingBalance,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Debit', totalDebit, PdfColors.red),
          _buildSummaryItem('Total Credit', totalCredit, PdfColors.green),
          _buildSummaryItem(
            'Balance',
            closingBalance,
            closingBalance > 0 ? PdfColors.red : PdfColors.green,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, double amount, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(color: PdfColors.grey, fontSize: 10),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '₹${amount.abs().toStringAsFixed(0)}',
          style: pw.TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLedgerTable(
    List<LedgerEntry> entries,
    DateFormat dateFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('Date'),
            _buildTableHeader('Description'),
            _buildTableHeader('Debit'),
            _buildTableHeader('Credit'),
            _buildTableHeader('Balance'),
          ],
        ),
        // Data Rows
        ...entries.reversed.map(
          (entry) => pw.TableRow(
            children: [
              _buildTableCell(dateFormat.format(entry.entryDate)),
              _buildTableCell(
                entry.description ??
                    entry.referenceNumber ??
                    entry.entryTypeString,
              ),
              _buildTableCell(
                entry.isDebit ? '₹${entry.amount.toStringAsFixed(0)}' : '-',
                color: entry.isDebit ? PdfColors.red : null,
              ),
              _buildTableCell(
                entry.isCredit ? '₹${entry.amount.toStringAsFixed(0)}' : '-',
                color: entry.isCredit ? PdfColors.green : null,
              ),
              _buildTableCell('₹${entry.runningBalance.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildFooter(DateTime now) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a computer-generated statement.',
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 8),
            ),
            pw.Text(
              'Generated by DukanX',
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }

  /// Save PDF to file and get path
  Future<String> savePdf(Uint8List bytes, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Share PDF
  Future<void> sharePdf(Uint8List bytes, String fileName) async {
    try {
      final path = await savePdf(bytes, fileName);
      await Share.shareXFiles([XFile(path)], subject: 'Ledger Statement');
    } catch (e) {
      throw Exception('Failed to share PDF: $e');
    }
  }
}
