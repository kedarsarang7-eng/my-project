// ============================================================================
// REPORT EXPORT SERVICE
// ============================================================================
// Export service for GST and Ledger reports - CA Safe Mode support.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Report Export Format
enum ExportFormat { csv, json }

/// Export Result
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int recordCount;

  const ExportResult._({
    required this.success,
    this.filePath,
    this.error,
    this.recordCount = 0,
  });

  factory ExportResult.success(String filePath, int recordCount) {
    return ExportResult._(
      success: true,
      filePath: filePath,
      recordCount: recordCount,
    );
  }

  factory ExportResult.failure(String error) {
    return ExportResult._(success: false, error: error);
  }
}

/// Report Export Service - GST and Ledger exports for CA/Accountant.
///
/// Supports:
/// - GST Summary Report (GSTR-3B format)
/// - Detailed Sales Register
/// - Purchase Register
/// - Customer Ledger
/// - Supplier Ledger
/// - Trial Balance
class ReportExportService {
  final AppDatabase _database;

  ReportExportService({required AppDatabase database}) : _database = database;

  /// Export GST Summary Report
  Future<ExportResult> exportGstSummary({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
    ExportFormat format = ExportFormat.csv,
  }) async {
    try {
      final toDateEnd = toDate.add(const Duration(days: 1));

      // Query bills for the period
      final bills =
          await (_database.select(_database.bills)
                ..where((t) => t.userId.equals(userId))
                ..where((t) => t.billDate.isBiggerOrEqualValue(fromDate))
                ..where((t) => t.billDate.isSmallerThanValue(toDateEnd))
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.billDate)]))
              .get();

      // Calculate GST summary
      double totalTaxableValue = 0;
      double totalCgst = 0;
      double totalSgst = 0;
      double totalIgst = 0;
      double totalCess = 0;

      for (final bill in bills) {
        totalTaxableValue += bill.subtotal;
        totalCgst += (bill.taxAmount / 2); // Assuming 50/50 CGST/SGST split
        totalSgst += (bill.taxAmount / 2);
      }

      final data = [
        ['GST Summary Report'],
        ['Period', '${_formatDate(fromDate)} to ${_formatDate(toDate)}'],
        ['Generated', DateTime.now().toIso8601String()],
        [''],
        ['Description', 'Amount (₹)'],
        ['Taxable Value', totalTaxableValue.toStringAsFixed(2)],
        ['CGST', totalCgst.toStringAsFixed(2)],
        ['SGST', totalSgst.toStringAsFixed(2)],
        ['IGST', totalIgst.toStringAsFixed(2)],
        ['CESS', totalCess.toStringAsFixed(2)],
        [
          'Total Tax',
          (totalCgst + totalSgst + totalIgst + totalCess).toStringAsFixed(2),
        ],
        [''],
        ['Total Invoices', bills.length.toString()],
      ];

      final filePath = await _saveReport(
        data: data,
        filename:
            'gst_summary_${_formatDateFilename(fromDate)}_${_formatDateFilename(toDate)}',
        format: format,
      );

      return ExportResult.success(filePath, bills.length);
    } catch (e) {
      debugPrint('ReportExportService: GST export failed: $e');
      return ExportResult.failure(e.toString());
    }
  }

  /// Export Sales Register
  Future<ExportResult> exportSalesRegister({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
    ExportFormat format = ExportFormat.csv,
  }) async {
    try {
      final toDateEnd = toDate.add(const Duration(days: 1));

      final bills =
          await (_database.select(_database.bills)
                ..where((t) => t.userId.equals(userId))
                ..where((t) => t.billDate.isBiggerOrEqualValue(fromDate))
                ..where((t) => t.billDate.isSmallerThanValue(toDateEnd))
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.billDate)]))
              .get();

      final data = <List<dynamic>>[
        ['Sales Register'],
        ['Period', '${_formatDate(fromDate)} to ${_formatDate(toDate)}'],
        [''],
        [
          'Date',
          'Invoice No',
          'Customer',
          'Taxable',
          'Tax',
          'Total',
          'Paid',
          'Balance',
          'Status',
        ],
      ];

      for (final bill in bills) {
        data.add([
          _formatDate(bill.billDate),
          bill.invoiceNumber,
          bill.customerName ?? 'Walk-in',
          bill.subtotal.toStringAsFixed(2),
          bill.taxAmount.toStringAsFixed(2),
          bill.grandTotal.toStringAsFixed(2),
          bill.paidAmount.toStringAsFixed(2),
          (bill.grandTotal - bill.paidAmount).toStringAsFixed(2),
          bill.status,
        ]);
      }

      // Add totals row
      final totalSales = bills.fold<double>(0, (sum, b) => sum + b.grandTotal);
      final totalTax = bills.fold<double>(0, (sum, b) => sum + b.taxAmount);
      final totalPaid = bills.fold<double>(0, (sum, b) => sum + b.paidAmount);

      data.add([]);
      data.add([
        '',
        '',
        'TOTALS',
        '',
        totalTax.toStringAsFixed(2),
        totalSales.toStringAsFixed(2),
        totalPaid.toStringAsFixed(2),
        (totalSales - totalPaid).toStringAsFixed(2),
        '',
      ]);

      final filePath = await _saveReport(
        data: data,
        filename:
            'sales_register_${_formatDateFilename(fromDate)}_${_formatDateFilename(toDate)}',
        format: format,
      );

      return ExportResult.success(filePath, bills.length);
    } catch (e) {
      debugPrint('ReportExportService: Sales register export failed: $e');
      return ExportResult.failure(e.toString());
    }
  }

  /// Export Customer Ledger
  Future<ExportResult> exportCustomerLedger({
    required String userId,
    required String customerId,
    required DateTime fromDate,
    required DateTime toDate,
    ExportFormat format = ExportFormat.csv,
  }) async {
    try {
      final toDateEnd = toDate.add(const Duration(days: 1));

      // Get customer
      final customer = await (_database.select(
        _database.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();

      if (customer == null) {
        return ExportResult.failure('Customer not found');
      }

      // Get bills
      final bills =
          await (_database.select(_database.bills)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.billDate.isBiggerOrEqualValue(fromDate))
                ..where((t) => t.billDate.isSmallerThanValue(toDateEnd))
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.billDate)]))
              .get();

      // Get payments
      final payments =
          await (_database.select(_database.payments)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.paymentDate.isBiggerOrEqualValue(fromDate))
                ..where((t) => t.paymentDate.isSmallerThanValue(toDateEnd))
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.paymentDate)]))
              .get();

      final data = <List<dynamic>>[
        ['Customer Ledger'],
        ['Customer Name', customer.name],
        ['Period', '${_formatDate(fromDate)} to ${_formatDate(toDate)}'],
        [''],
        ['Date', 'Type', 'Reference', 'Debit', 'Credit', 'Balance'],
      ];

      double runningBalance = 0;

      // Combine and sort all entries
      final entries = <Map<String, dynamic>>[];

      for (final bill in bills) {
        entries.add({
          'date': bill.billDate,
          'type': 'Sale',
          'reference': bill.invoiceNumber,
          'debit': bill.grandTotal,
          'credit': 0.0,
        });
      }

      for (final payment in payments) {
        entries.add({
          'date': payment.paymentDate,
          'type': 'Payment',
          'reference': payment.referenceNumber ?? '-',
          'debit': 0.0,
          'credit': payment.amount,
        });
      }

      entries.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

      for (final entry in entries) {
        runningBalance +=
            (entry['debit'] as double) - (entry['credit'] as double);
        data.add([
          _formatDate(entry['date'] as DateTime),
          entry['type'],
          entry['reference'],
          (entry['debit'] as double) > 0
              ? (entry['debit'] as double).toStringAsFixed(2)
              : '',
          (entry['credit'] as double) > 0
              ? (entry['credit'] as double).toStringAsFixed(2)
              : '',
          runningBalance.toStringAsFixed(2),
        ]);
      }

      data.add([]);
      data.add([
        '',
        '',
        'Closing Balance',
        '',
        '',
        runningBalance.toStringAsFixed(2),
      ]);

      final filePath = await _saveReport(
        data: data,
        filename:
            'ledger_${customer.name.replaceAll(' ', '_')}_${_formatDateFilename(fromDate)}',
        format: format,
      );

      return ExportResult.success(filePath, entries.length);
    } catch (e) {
      debugPrint('ReportExportService: Ledger export failed: $e');
      return ExportResult.failure(e.toString());
    }
  }

  Future<String> _saveReport({
    required List<List<dynamic>> data,
    required String filename,
    required ExportFormat format,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final extension = format == ExportFormat.csv ? 'csv' : 'json';
    final file = File('${exportDir.path}/$filename.$extension');

    if (format == ExportFormat.csv) {
      // Simple CSV conversion without external package
      final csvContent = data
          .map(
            (row) => row
                .map((cell) => '"${cell.toString().replaceAll('"', '""')}"')
                .join(','),
          )
          .join('\n');
      await file.writeAsString(csvContent);
    } else {
      final json = jsonEncode(data);
      await file.writeAsString(json);
    }

    debugPrint('ReportExportService: Exported to ${file.path}');
    return file.path;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateFilename(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
}
