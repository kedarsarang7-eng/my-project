// ============================================================================
// Purchase Entries List Screen
// ============================================================================
// Quick Win: View and export purchase entries to Excel
// Features:
// - List all purchase entries with filters
// - Export to Excel
// - View entry details
// - Print receipt
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../models/scan_bill_models.dart';
import '../../services/scan_bill_api_client.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PurchaseEntriesListScreen extends ConsumerStatefulWidget {
  final String verticalType;

  const PurchaseEntriesListScreen({super.key, required this.verticalType});

  @override
  ConsumerState<PurchaseEntriesListScreen> createState() =>
      _PurchaseEntriesListScreenState();
}

class _PurchaseEntriesListScreenState
    extends ConsumerState<PurchaseEntriesListScreen> {
  final LoggerService _logger = sl<LoggerService>();
  final ScanBillApiClient _apiClient = sl<ScanBillApiClient>();

  List<PurchaseEntry> _entries = [];
  bool _isLoading = false;
  bool _isExporting = false;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _supplierFilter;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);

    try {
      final result = await _apiClient.listEntries(
        from: _fromDate,
        to: _toDate,
        supplierId: _supplierFilter,
        limit: 100,
      );

      final entries =
          (result['entries'] as List?)
              ?.map((e) => PurchaseEntry.fromJson(e))
              .toList() ??
          [];

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      _logger.error('Failed to load entries', {'error': e.toString()});
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load entries: $e')));
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No entries to export')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Create workbook
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Purchase Entries';

      // Headers
      final headers = [
        'RID',
        'Date',
        'Supplier',
        'Bill Number',
        'Items Count',
        'Total Amount',
        'GST',
        'Payment Status',
        'Created By',
        'Entry Method',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
        sheet.getRangeByIndex(1, i + 1).cellStyle.backColor = '#4472C4';
        sheet.getRangeByIndex(1, i + 1).cellStyle.fontColor = '#FFFFFF';
      }

      // Data rows
      for (int i = 0; i < _entries.length; i++) {
        final entry = _entries[i];
        final row = i + 2;

        sheet.getRangeByIndex(row, 1).setText(entry.rid);
        sheet
            .getRangeByIndex(row, 2)
            .setText(
              DateFormat('dd-MMM-yyyy').format(DateTime.parse(entry.billDate)),
            );
        sheet.getRangeByIndex(row, 3).setText(entry.supplierName ?? 'N/A');
        sheet.getRangeByIndex(row, 4).setText(entry.billNumber ?? 'N/A');
        sheet
            .getRangeByIndex(row, 5)
            .setNumber(entry.lineItems.length.toDouble());
        sheet.getRangeByIndex(row, 6).setNumber(entry.totalAmount);
        sheet.getRangeByIndex(row, 6).numberFormat = '₹#,##0.00';
        sheet.getRangeByIndex(row, 7).setNumber(entry.gstAmount ?? 0);
        sheet.getRangeByIndex(row, 7).numberFormat = '₹#,##0.00';
        sheet.getRangeByIndex(row, 8).setText(entry.paymentStatus);
        sheet.getRangeByIndex(row, 9).setText(entry.createdBy);
        sheet.getRangeByIndex(row, 10).setText(entry.entryMethod);
      }

      // Auto-fit columns
      for (int i = 1; i <= headers.length; i++) {
        sheet.getRangeByIndex(1, i).autoFitColumns();
      }

      // Line items sheet
      final itemsSheet = workbook.worksheets.add();
      itemsSheet.name = 'Line Items';

      final itemHeaders = [
        'Entry RID',
        'Product Name',
        'Quantity',
        'Unit',
        'Unit Price',
        'Total Price',
        'HSN Code',
        'Batch No',
        'Expiry Date',
      ];

      for (int i = 0; i < itemHeaders.length; i++) {
        itemsSheet.getRangeByIndex(1, i + 1).setText(itemHeaders[i]);
        itemsSheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
      }

      int itemRow = 2;
      for (final entry in _entries) {
        for (final item in entry.lineItems) {
          itemsSheet.getRangeByIndex(itemRow, 1).setText(entry.rid);
          itemsSheet
              .getRangeByIndex(itemRow, 2)
              .setText(item['productName'] ?? 'N/A');
          itemsSheet
              .getRangeByIndex(itemRow, 3)
              .setNumber((item['quantity'] as num?)?.toDouble() ?? 0);
          itemsSheet.getRangeByIndex(itemRow, 4).setText(item['unit'] ?? 'pcs');
          itemsSheet
              .getRangeByIndex(itemRow, 5)
              .setNumber((item['unitPrice'] as num?)?.toDouble() ?? 0);
          itemsSheet.getRangeByIndex(itemRow, 5).numberFormat = '₹#,##0.00';
          itemsSheet
              .getRangeByIndex(itemRow, 6)
              .setNumber((item['totalPrice'] as num?)?.toDouble() ?? 0);
          itemsSheet.getRangeByIndex(itemRow, 6).numberFormat = '₹#,##0.00';
          itemsSheet
              .getRangeByIndex(itemRow, 7)
              .setText(item['hsnCode'] ?? 'N/A');
          itemsSheet
              .getRangeByIndex(itemRow, 8)
              .setText(item['batchNo'] ?? 'N/A');
          itemsSheet
              .getRangeByIndex(itemRow, 9)
              .setText(item['expiryDate'] ?? 'N/A');
          itemRow++;
        }
      }

      // Save file
      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'purchase_entries_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Purchase Entries Export',
        text: 'Purchase entries exported from DukanX',
      );

      _logger.info('Excel exported successfully', {'file': fileName});
    } catch (e, stackTrace) {
      _logger.error('Excel export failed', {'error': e.toString()}, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _toDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Entries'),
        actions: [
          // Export button
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              // Summary card
              _buildSummaryCard(colorScheme),

              // Date filter indicator
              if (_fromDate != null && _toDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Chip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      '${DateFormat('dd MMM').format(_fromDate!)} - ${DateFormat('dd MMM yyyy').format(_toDate!)}',
                    ),
                    onDeleted: () {
                      setState(() {
                        _fromDate = null;
                        _toDate = null;
                      });
                      _loadEntries();
                    },
                  ),
                ),

              // Entries list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                    ? _buildEmptyState()
                    : _buildEntriesList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final totalAmount = _entries.fold<double>(
      0,
      (sum, e) => sum + e.totalAmount,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_entries.length} Entries',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total: ₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No purchase entries found',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a bill to create your first entry',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _EntryCard(entry: entry, onTap: () => _showEntryDetails(entry));
      },
    );
  }

  void _showEntryDetails(PurchaseEntry entry) {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: BoundedBox(
            maxWidth: 600,
            child: _EntryDetailSheet(entry: entry, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _EntryDetailSheet(entry: entry, isDialog: false),
      );
    }
  }
}

// ============================================================================
// Entry Card Widget
// ============================================================================

class _EntryCard extends StatelessWidget {
  final PurchaseEntry entry;
  final VoidCallback onTap;

  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor;
    IconData statusIcon;

    switch (entry.paymentStatus) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.supplierName ?? 'Unknown Supplier',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${entry.totalAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Bill: ${entry.billNumber ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${entry.lineItems.length} items',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(DateTime.parse(entry.billDate)),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Entry Detail Sheet
// ============================================================================

class _EntryDetailSheet extends StatelessWidget {
  final PurchaseEntry entry;
  final bool isDialog;

  const _EntryDetailSheet({required this.entry, this.isDialog = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isDialog) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            _buildHeader(context, theme),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _buildDetailsList(context, theme),
              ),
            ),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              _buildHeader(context, theme),

              const Divider(),

              // Details
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _buildDetailsList(context, theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.supplierName ?? 'Purchase Entry',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'RID: ${entry.rid}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReceipt(context),
            tooltip: 'Print Receipt',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailsList(BuildContext context, ThemeData theme) {
    return [
      _buildDetailRow('Bill Number', entry.billNumber ?? 'N/A'),
      _buildDetailRow(
        'Bill Date',
        DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.parse(entry.billDate)),
      ),
      _buildDetailRow(
        'Payment Status',
        entry.paymentStatus.toUpperCase(),
      ),
      _buildDetailRow(
        'Entry Method',
        entry.entryMethod.toUpperCase(),
      ),
      _buildDetailRow('Created By', entry.createdBy),
      _buildDetailRow(
        'Created At',
        DateFormat(
          'dd MMM yyyy HH:mm',
        ).format(DateTime.parse(entry.createdAt)),
      ),

      const Divider(),

      // Totals
      _buildTotalRow(context, 'Total Amount', entry.totalAmount),
      if (entry.gstAmount != null)
        _buildTotalRow(context, 'GST Amount', entry.gstAmount!),

      const Divider(),

      // Line items
      Text(
        'Line Items (${entry.lineItems.length})',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),

      ...entry.lineItems.map((item) => _buildLineItem(item)),
    ];
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['productName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${item['quantity']} ${item['unit']}'),
                const SizedBox(width: 16),
                Text('× ₹${item['unitPrice']}'),
                const Spacer(),
                Text(
                  '= ₹${item['totalPrice']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (item['batchNo'] != null || item['expiryDate'] != null)
              Text(
                'Batch: ${item['batchNo'] ?? 'N/A'} | Exp: ${item['expiryDate'] ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  void _printReceipt(BuildContext context) {
    // Print functionality implementation hook
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print functionality coming soon')),
    );
  }
}
