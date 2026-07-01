import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/products_repository.dart';
import '../../barcode/widgets/desktop_usb_scanner.dart';
import '../../barcode/services/barcode_lookup_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ============================================================================
// NARCOTIC / SCHEDULE X REGISTER SCREEN
// ============================================================================
// Pharmacy P0 feature: tracks dispensing of Schedule X (narcotic) and
// Schedule H1 (antibiotic) controlled drugs.
//
// Each dispensing entry records:
//   - Barcode scan of the drug
//   - Doctor name + registration number
//   - Patient name + Aadhaar (last 4 digits)
//   - Quantity dispensed
//   - Timestamp + pharmacist ID
//
// Data is persisted locally and synced to backend for regulatory compliance.
// ============================================================================

enum DrugRegisterType { scheduleX, scheduleH1 }

extension DrugRegisterTypeLabel on DrugRegisterType {
  String get label => this == DrugRegisterType.scheduleX
      ? 'Schedule X (Narcotic)'
      : 'Schedule H1 (Antibiotic)';
  Color get color => this == DrugRegisterType.scheduleX
      ? Colors.red.shade700
      : Colors.orange.shade700;
  IconData get icon => this == DrugRegisterType.scheduleX
      ? Icons.warning_rounded
      : Icons.medical_services_rounded;
}

class NarcoticRegisterEntry {
  final String id;
  final String drugName;
  final String barcode;
  final DrugRegisterType type;
  final double quantity;
  final String unit;
  final String doctorName;
  final String doctorRegNo;
  final String patientName;
  final String patientAadhaarLast4;
  final String pharmacistId;
  final DateTime dispensedAt;
  // Compliance fields merged from the prescriptions register copy so the
  // canonical screen preserves every user-facing field (R18.2). Optional
  // because manual/scan entries may not always carry them.
  final String patientAddress;
  final String batchNumber;
  final String billNumber;

  NarcoticRegisterEntry({
    required this.id,
    required this.drugName,
    required this.barcode,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.doctorName,
    required this.doctorRegNo,
    required this.patientName,
    required this.patientAadhaarLast4,
    required this.pharmacistId,
    required this.dispensedAt,
    this.patientAddress = '',
    this.batchNumber = '',
    this.billNumber = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'drugName': drugName,
    'barcode': barcode,
    'type': type.name,
    'quantity': quantity,
    'unit': unit,
    'doctorName': doctorName,
    'doctorRegNo': doctorRegNo,
    'patientName': patientName,
    'patientAadhaarLast4': patientAadhaarLast4,
    'pharmacistId': pharmacistId,
    'dispensedAt': dispensedAt.toIso8601String(),
    'patientAddress': patientAddress,
    'batchNumber': batchNumber,
    'billNumber': billNumber,
  };
}

class NarcoticRegisterScreen extends StatefulWidget {
  const NarcoticRegisterScreen({super.key});

  @override
  State<NarcoticRegisterScreen> createState() => _NarcoticRegisterScreenState();
}

class _NarcoticRegisterScreenState extends State<NarcoticRegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _session = sl<SessionManager>();
  final _fmt = DateFormat('dd MMM yyyy, hh:mm a');
  DrugRegisterType _activeType = DrugRegisterType.scheduleX;

  // Hive-persisted entries
  static const _hiveBox = 'narcotic_register';
  Box<String>? _box;
  final List<NarcoticRegisterEntry> _entries = [];

  String _searchQuery = '';
  DateTimeRange? _dateRange;

  // Load lifecycle states (preserved from the prescriptions register copy so
  // the canonical screen retains loading/error-with-retry screen states, R18.2).
  bool _isLoading = true;
  String? _loadError;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadFromHive();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _activeType = _tabs.index == 0
              ? DrugRegisterType.scheduleX
              : DrugRegisterType.scheduleH1;
        });
      }
    });
  }

  Future<void> _loadFromHive() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      _box = await Hive.openBox<String>(_hiveBox);
      final loaded = _box!.values
          .map((json) {
            try {
              final m = jsonDecode(json) as Map<String, dynamic>;
              return NarcoticRegisterEntry(
                id: m['id'] as String,
                drugName: m['drugName'] as String,
                barcode: m['barcode'] as String,
                type: m['type'] == 'scheduleH1'
                    ? DrugRegisterType.scheduleH1
                    : DrugRegisterType.scheduleX,
                quantity: (m['quantity'] as num).toDouble(),
                unit: m['unit'] as String,
                doctorName: m['doctorName'] as String,
                doctorRegNo: m['doctorRegNo'] as String,
                patientName: m['patientName'] as String,
                patientAadhaarLast4: m['patientAadhaarLast4'] as String,
                pharmacistId: m['pharmacistId'] as String,
                dispensedAt: DateTime.parse(m['dispensedAt'] as String),
                patientAddress: (m['patientAddress'] as String?) ?? '',
                batchNumber: (m['batchNumber'] as String?) ?? '',
                billNumber: (m['billNumber'] as String?) ?? '',
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<NarcoticRegisterEntry>()
          .toList();
      if (mounted) {
        setState(() {
          _entries
            ..clear()
            ..addAll(loaded);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load register: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveEntryToHive(NarcoticRegisterEntry entry) async {
    _box ??= await Hive.openBox<String>(_hiveBox);
    await _box!.put(entry.id, jsonEncode(entry.toMap()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<NarcoticRegisterEntry> get _filteredEntries {
    return _entries.where((e) {
      if (e.type != _activeType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!e.drugName.toLowerCase().contains(q) &&
            !e.patientName.toLowerCase().contains(q) &&
            !e.doctorName.toLowerCase().contains(q) &&
            !e.barcode.contains(q)) {
          return false;
        }
      }
      if (_dateRange != null) {
        if (e.dispensedAt.isBefore(_dateRange!.start) ||
            e.dispensedAt.isAfter(
              _dateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.dispensedAt.compareTo(a.dispensedAt));
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF12121F) : const Color(0xFFF5F5FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.assignment_outlined, size: 22, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.isMobile
                    ? 'Narcotic Register'
                    : 'Narcotic / Controlled Drug Register',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan & Dispense Drug',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanAndDispenseDialog,
          ),
          if (context.isMobile)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'filter') _pickDateRange();
                if (val == 'clear') setState(() => _dateRange = null);
                if (val == 'export') _exportCsv();
                if (val == 'pdf') _exportPdf();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'filter',
                  child: Row(
                    children: [
                      Icon(Icons.date_range_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Filter by date'),
                    ],
                  ),
                ),
                if (_dateRange != null)
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.clear, size: 20),
                        SizedBox(width: 8),
                        Text('Clear filter'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Export CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Print / Export PDF'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'Filter by date range',
              icon: const Icon(Icons.date_range_outlined),
              onPressed: _pickDateRange,
            ),
            if (_dateRange != null)
              TextButton(
                onPressed: () => setState(() => _dateRange = null),
                child: const Text('Clear'),
              ),
            IconButton(
              tooltip: 'Export as CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: _exportCsv,
            ),
            IconButton(
              tooltip: 'Print / Export as PDF',
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              onPressed: _isExporting ? null : _exportPdf,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.red,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          tabs: DrugRegisterType.values
              .map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label))
              .toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('Loading narcotic register...'),
                ],
              ),
            )
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loadError!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadFromHive,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search drug, patient, doctor, barcode...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                if (_dateRange != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_list,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Date: ${DateFormat('dd MMM').format(_dateRange!.start)} — ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Stats row
                _buildStatsRow(isDark),
                // Table
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildRegisterTable(isDark, surfaceColor),
                      _buildRegisterTable(isDark, surfaceColor),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        onPressed: () => _openDispenseDialog(),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final filtered = _filteredEntries;
    final totalQty = filtered.fold<double>(0, (s, e) => s + e.quantity);
    final todayEntries = filtered
        .where(
          (e) =>
              e.dispensedAt.day == DateTime.now().day &&
              e.dispensedAt.month == DateTime.now().month,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statChip(
                  Icons.list_alt,
                  '${filtered.length} entries',
                  Colors.blue,
                ),
                _statChip(Icons.today, '$todayEntries today', Colors.green),
                _statChip(
                  Icons.scale,
                  '${totalQty.toStringAsFixed(1)} units dispensed',
                  Colors.orange,
                ),
              ],
            ),
          ),
          if (!context.isMobile)
            Text(
              'Drug Inspector Compliance Register',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  Widget _buildRegisterTable(bool isDark, Color surfaceColor) {
    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_activeType.label} entries',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openScanAndDispenseDialog,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan & Dispense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(
            isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
          ),
          columns: [
            const DataColumn(
              label: Text(
                'Date/Time',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Drug Name',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Barcode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const DataColumn(
              label: Text(
                'Doctor',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Reg No',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Patient',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Aadhaar (last 4)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Batch',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Address',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Bill #',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(
              label: Text(
                'Pharmacist',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const DataColumn(label: Text('')),
          ],
          rows: entries
              .map(
                (e) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        _fmt.format(e.dispensedAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        e.drugName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        e.barcode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    DataCell(Text('${e.quantity} ${e.unit}')),
                    DataCell(Text(e.doctorName)),
                    DataCell(
                      Text(e.doctorRegNo, style: const TextStyle(fontSize: 11)),
                    ),
                    DataCell(Text(e.patientName)),
                    DataCell(Text('XXXX-XXXX-${e.patientAadhaarLast4}')),
                    DataCell(
                      Text(
                        e.batchNumber.isEmpty ? '-' : e.batchNumber,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(e.patientAddress.isEmpty ? '-' : e.patientAddress),
                    ),
                    DataCell(
                      Text(
                        e.billNumber.isEmpty ? '-' : e.billNumber,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      Text(
                        e.pharmacistId,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete entry',
                        onPressed: () => _deleteEntry(e),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final entries = _filteredEntries;
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No entries to export')));
      }
      return;
    }

    final header =
        'Date/Time,Drug Name,Barcode,Type,Qty,Unit,Doctor Name,Reg No,Patient Name,Aadhaar Last 4,Batch,Address,Bill No,Pharmacist\n';
    final rows = entries
        .map((e) {
          return '"${_fmt.format(e.dispensedAt)}","${e.drugName}","${e.barcode}",'
              '"${e.type.label}","${e.quantity}","${e.unit}","${e.doctorName}",'
              '"${e.doctorRegNo}","${e.patientName}","XXXX-XXXX-${e.patientAadhaarLast4}",'
              '"${e.batchNumber}","${e.patientAddress}","${e.billNumber}",'
              '"${e.pharmacistId}"';
        })
        .join('\n');

    final csv = header + rows;

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/narcotic_register_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      );
      await file.writeAsString(csv);
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Narcotic Register Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Print / export the current register view to PDF. Preserves the
  /// "Print / Export" action from the prescriptions register copy (R18.2),
  /// rendered locally from the canonical entries via the pdf/printing packages.
  Future<void> _exportPdf() async {
    final entries = _filteredEntries;
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No entries to export')));
      }
      return;
    }

    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final headers = [
        'Date/Time',
        'Drug',
        'Type',
        'Qty',
        'Doctor',
        'Reg No',
        'Patient',
        'Aadhaar',
        'Batch',
        'Address',
        'Bill #',
        'Pharmacist',
      ];
      final data = entries
          .map(
            (e) => [
              _fmt.format(e.dispensedAt),
              e.drugName,
              e.type.label,
              '${e.quantity} ${e.unit}',
              e.doctorName,
              e.doctorRegNo,
              e.patientName,
              'XXXX-XXXX-${e.patientAadhaarLast4}',
              e.batchNumber.isEmpty ? '-' : e.batchNumber,
              e.patientAddress.isEmpty ? '-' : e.patientAddress,
              e.billNumber.isEmpty ? '-' : e.billNumber,
              e.pharmacistId,
            ],
          )
          .toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                '${_activeType.label} — Drug Inspector Compliance Register',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated: ${_fmt.format(DateTime.now())}   |   Total entries: ${entries.length}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'narcotic_register_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteEntry(NarcoticRegisterEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Delete dispensing record for ${entry.drugName} → ${entry.patientName}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _entries.remove(entry));
    _box ??= await Hive.openBox<String>(_hiveBox);
    await _box!.delete(entry.id);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (range != null) setState(() => _dateRange = range);
  }

  // ── Scan & Auto-fill dispense dialog ────────────────────────────────────────

  Future<void> _openScanAndDispenseDialog() async {
    String? scannedBarcode;
    String? scannedDrugName;

    // Step 1: Scan barcode
    final barcode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: SizedBox(
            width: responsiveValue<double>(
              context,
              mobile: MediaQuery.of(context).size.width * 0.9,
              tablet: 400,
              desktop: 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Scan Controlled Drug',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan barcode on the drug package to auto-fill drug details.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                DesktopUsbScanner(
                  onProductScanned: (product) =>
                      Navigator.pop(ctx, product.barcode),
                  onProductNotFound: (code) => Navigator.pop(ctx, code),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (barcode == null || barcode.isEmpty) return;

    // Step 2: Resolve drug name from local DB or lookup service
    try {
      final userId = _session.ownerId ?? '';
      final result = await sl<ProductsRepository>().search(
        barcode,
        userId: userId,
      );
      final products = result.data ?? [];
      if (products.isNotEmpty) {
        final match = products.firstWhere(
          (p) => p.barcode == barcode || p.altBarcodes.contains(barcode),
          orElse: () => products.first,
        );
        scannedBarcode = barcode;
        scannedDrugName = match.name;
      } else {
        // Try lookup service
        final lookupService = sl<BarcodeLookupService>();
        await lookupService.initialize();
        final lookupResult = await lookupService.lookupBarcode(
          barcode: barcode,
          businessId: _session.currentBusinessId,
        );
        scannedBarcode = barcode;
        scannedDrugName = lookupResult.product?.name ?? barcode;
      }
    } catch (_) {
      scannedBarcode = barcode;
      scannedDrugName = barcode;
    }

    if (mounted) {
      await _openDispenseDialog(
        prefillBarcode: scannedBarcode,
        prefillDrugName: scannedDrugName,
      );
    }
  }

  // ── Manual / pre-filled dispense dialog ─────────────────────────────────────

  Future<void> _openDispenseDialog({
    String? prefillBarcode,
    String? prefillDrugName,
  }) async {
    final drugNameCtrl = TextEditingController(text: prefillDrugName ?? '');
    final barcodeCtrl = TextEditingController(text: prefillBarcode ?? '');
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'tab');
    final doctorNameCtrl = TextEditingController();
    final doctorRegCtrl = TextEditingController();
    final patientNameCtrl = TextEditingController();
    final aadhaarCtrl = TextEditingController();
    final patientAddressCtrl = TextEditingController();
    final batchNumberCtrl = TextEditingController();
    final billNumberCtrl = TextEditingController();
    DrugRegisterType selectedType = _activeType;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                color: Colors.red.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Add Dispensing Entry',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: responsiveValue<double>(
              context,
              mobile: MediaQuery.of(context).size.width * 0.9,
              tablet: 480,
              desktop: 480,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Register type selector
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<DrugRegisterType>(
                      segments: DrugRegisterType.values
                          .map(
                            (t) => ButtonSegment(
                              value: t,
                              label: Text(
                                context.isMobile
                                    ? t.name.replaceAll('schedule', 'Sched ')
                                    : t.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              icon: Icon(t.icon, size: 14),
                            ),
                          )
                          .toList(),
                      selected: {selectedType},
                      onSelectionChanged: (s) =>
                          setDS(() => selectedType = s.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.red.shade700
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Drug Details'),
                  const SizedBox(height: 8),
                  _dialogField(drugNameCtrl, 'Drug Name *', Icons.medication),
                  const SizedBox(height: 10),
                  context.isMobile
                      ? Column(
                          children: [
                            _dialogField(barcodeCtrl, 'Barcode', Icons.qr_code),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _dialogField(
                                    qtyCtrl,
                                    'Qty *',
                                    Icons.numbers,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _dialogField(
                                    unitCtrl,
                                    'Unit',
                                    Icons.straighten,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _dialogField(
                                barcodeCtrl,
                                'Barcode',
                                Icons.qr_code,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dialogField(
                                qtyCtrl,
                                'Qty *',
                                Icons.numbers,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dialogField(
                                unitCtrl,
                                'Unit',
                                Icons.straighten,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 10),
                  context.isMobile
                      ? Column(
                          children: [
                            _dialogField(
                              batchNumberCtrl,
                              'Batch No',
                              Icons.inventory_2_outlined,
                            ),
                            const SizedBox(height: 10),
                            _dialogField(
                              billNumberCtrl,
                              'Bill / Invoice No',
                              Icons.receipt_long_outlined,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _dialogField(
                                batchNumberCtrl,
                                'Batch No',
                                Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dialogField(
                                billNumberCtrl,
                                'Bill / Invoice No',
                                Icons.receipt_long_outlined,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Prescribing Doctor'),
                  const SizedBox(height: 8),
                  context.isMobile
                      ? Column(
                          children: [
                            _dialogField(
                              doctorNameCtrl,
                              'Doctor Name *',
                              Icons.person,
                            ),
                            const SizedBox(height: 10),
                            _dialogField(
                              doctorRegCtrl,
                              'Reg No *',
                              Icons.badge,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _dialogField(
                                doctorNameCtrl,
                                'Doctor Name *',
                                Icons.person,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dialogField(
                                doctorRegCtrl,
                                'Reg No *',
                                Icons.badge,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Patient Details'),
                  const SizedBox(height: 8),
                  context.isMobile
                      ? Column(
                          children: [
                            _dialogField(
                              patientNameCtrl,
                              'Patient Name *',
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 10),
                            _dialogField(
                              aadhaarCtrl,
                              'Aadhaar last 4 digits *',
                              Icons.credit_card,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _dialogField(
                                patientNameCtrl,
                                'Patient Name *',
                                Icons.person_outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 160,
                              child: _dialogField(
                                aadhaarCtrl,
                                'Aadhaar last 4 digits *',
                                Icons.credit_card,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 10),
                  _dialogField(
                    patientAddressCtrl,
                    'Patient Address',
                    Icons.home_outlined,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save Entry'),
              onPressed: () {
                if (drugNameCtrl.text.trim().isEmpty ||
                    qtyCtrl.text.trim().isEmpty ||
                    doctorNameCtrl.text.trim().isEmpty ||
                    doctorRegCtrl.text.trim().isEmpty ||
                    patientNameCtrl.text.trim().isEmpty ||
                    aadhaarCtrl.text.trim().length != 4) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required (*) fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final entry = NarcoticRegisterEntry(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  drugName: drugNameCtrl.text.trim(),
                  barcode: barcodeCtrl.text.trim(),
                  type: selectedType,
                  quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                  unit: unitCtrl.text.trim().isEmpty
                      ? 'tab'
                      : unitCtrl.text.trim(),
                  doctorName: doctorNameCtrl.text.trim(),
                  doctorRegNo: doctorRegCtrl.text.trim(),
                  patientName: patientNameCtrl.text.trim(),
                  patientAadhaarLast4: aadhaarCtrl.text.trim(),
                  pharmacistId: _session.ownerId ?? 'pharmacist',
                  dispensedAt: DateTime.now(),
                  patientAddress: patientAddressCtrl.text.trim(),
                  batchNumber: batchNumberCtrl.text.trim(),
                  billNumber: billNumberCtrl.text.trim(),
                );

                setState(() => _entries.add(entry));
                _saveEntryToHive(entry);
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Entry saved: ${entry.drugName} → ${entry.patientName}',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    drugNameCtrl.dispose();
    barcodeCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    doctorNameCtrl.dispose();
    doctorRegCtrl.dispose();
    patientNameCtrl.dispose();
    aadhaarCtrl.dispose();
    patientAddressCtrl.dispose();
    batchNumberCtrl.dispose();
    billNumberCtrl.dispose();
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }
}
