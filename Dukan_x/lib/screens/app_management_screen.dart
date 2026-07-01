import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../core/repository/reports_repository.dart';
import '../core/sync/sync_manager.dart';
import '../core/session/session_manager.dart';
import '../features/backup/services/offline_backup_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AppManagementScreen extends StatefulWidget {
  const AppManagementScreen({super.key});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  bool _loading = false;

  void _showLoading(bool busy) {
    setState(() => _loading = busy);
  }

  Future<void> _backupData() async {
    _showLoading(true);
    try {
      final result = await OfflineBackupService().createBackup(
        trigger: BackupScheduleFrequency.manual,
      );
      _showLoading(false);
      if (mounted) {
        if (result.success) {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Local Backup Created'),
                content: Text(
                  'Backup created successfully!\n\nPath: ${result.entry?.path}\nSize: ${result.entry?.formattedSize}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        } else {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Backup Failed'),
                content: Text('Failed to create local backup: ${result.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e')),
        );
      }
    }
  }

  Future<void> _restoreCloud() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    _showLoading(true);
    try {
      await sl<SyncManager>().restoreFullData(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloud Restore Completed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Restore Error: $e")));
      }
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _exportSalesReport() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    _showLoading(true);
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));

      final reportsRepo = sl<ReportsRepository>();

      // Fetch Data
      final dataRes = await reportsRepo.getSalesReport(
        userId: userId,
        start: start,
        end: end,
      );
      final summaryRes = await reportsRepo.getProfitLossSummary(
        userId: userId,
        start: start,
        end: end,
      );

      if (!dataRes.success || !summaryRes.success) {
        throw Exception("Failed to fetch report data");
      }

      final data = dataRes.data!;
      final summary = summaryRes.data!;

      // Format for PDF
      final headers = ['Date', 'Bill #', 'Customer', 'Amount', 'Status'];
      final rows = data
          .map(
            (d) => [
              d['bill_date'].toString().split(' ')[0],
              d['bill_number'].toString(),
              d['customer_name'].toString(),
              d['total_amount'].toString(),
              d['status'].toString(),
            ],
          )
          .toList();

      await _exportReportToPdf(
        title: 'Monthly Sales Report',
        headers: headers,
        data: rows,
        summary: summary,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      _showLoading(false);
    }
  }

  // Reuse logic for PDF Export (Self-contained or move to helper)
  Future<File> _exportReportToPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    required Map<String, double> summary,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildPdfHeader(title),
          pw.SizedBox(height: 20),
          _buildPdfSummary(summary),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'report_${title}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    return file;
  }

  pw.Widget _buildPdfHeader(String title) {
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Generated: $dateStr',
          style: const pw.TextStyle(color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSummary(Map<String, double> summary) {
    if (summary.isEmpty) return pw.Container();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: summary.entries.map((e) {
          return pw.Column(
            children: [
              pw.Text(
                e.key.replaceAll('_', ' ').toUpperCase(),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                '₹${e.value.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Toolkit'),
        backgroundColor: Colors.indigo,
      ),
      body: ResponsiveContainer(
        child: Stack(
          children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Data Safety'),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.blue),
                title: const Text('Restore from Cloud'),
                subtitle: const Text('Download customers, bills, and stock'),
                onTap: _restoreCloud,
              ),
              ListTile(
                leading: const Icon(Icons.archive, color: Colors.orange),
                title: const Text('Backup Data (Zip)'),
                subtitle: const Text('Export local database to file'),
                onTap: _backupData,
              ),
              const Divider(),
              _buildSectionHeader('Reports'),
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.green),
                title: const Text('Monthly Sales Report'),
                subtitle: const Text('Generate PDF with P&L'),
                onTap: _exportSalesReport,
              ),
              ListTile(
                leading: const Icon(Icons.inventory, color: Colors.teal),
                title: const Text('Stock Valuation'),
                subtitle: const Text('PDF of current inventory value'),
                onTap: () async {
                  // Implement call to reportsRepo.getStockValuationReport
                },
              ),
              const Divider(),
              _buildSectionHeader('System'),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: const Text('Activity Logs'),
                subtitle: const Text('View staff actions & audits'),
                onTap: () {
                  // Navigate to AuditLogScreen (to be built)
                },
              ),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ));
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }
}
