import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Schedule H1 Register — statutory record-keeping per Indian D&C Rules
/// (Schedule H1) for sale of antibiotics, anti-TB drugs, habit-forming
/// preparations etc. Pharmacies must maintain this register for at least
/// three (3) years from the last entry and produce it on demand to the
/// drug inspector.
///
/// Desktop-first table view with month picker, date-range filter, pagination
/// and export-to-PDF/CSV. Listens to the `/pharmacy/h1-register` API.
///
/// Access: owner, manager, pharmacist (cashier role intentionally excluded).
class H1RegisterScreen extends StatefulWidget {
  const H1RegisterScreen({super.key});

  @override
  State<H1RegisterScreen> createState() => _H1RegisterScreenState();
}

class _H1RegisterScreenState extends State<H1RegisterScreen> {
  static const _accent = Color(0xFFE65100); // statutory orange
  static const _accentDark = Color(0xFFBF360C);
  static const _surface = Color(0xFF12121C);
  static const _rowAlt = Color(0xFF1A1A26);

  final _apiClient = sl<ApiClient>();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _entries = const [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  // Default to the current month, but allow free-form date range overrides.
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  int _page = 1;
  int _pageSize = 25;
  int _totalEntries = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get(
        '/pharmacy/h1-register'
        '?startDate=${_fmtDate(_startDate)}'
        '&endDate=${_fmtDate(_endDate)}'
        '&page=$_page'
        '&pageSize=$_pageSize'
        '${_query.isNotEmpty ? '&q=${Uri.encodeQueryComponent(_query)}' : ''}',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        setState(() {
          _entries = List<Map<String, dynamic>>.from(data['data'] ?? const []);
          _totalEntries =
              (data['pagination']?['total'] as int?) ?? _entries.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load Schedule H1 register';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportRegister(String format) async {
    setState(() => _isExporting = true);
    try {
      final response = await _apiClient.get(
        '/pharmacy/h1-register/export'
        '?format=$format'
        '&startDate=${_fmtDate(_startDate)}'
        '&endDate=${_fmtDate(_endDate)}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.isSuccess
                ? 'Export ($format) generated successfully'
                : 'Export endpoint unavailable. Contact admin.',
          ),
          backgroundColor:
              response.isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: _surface,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
        _page = 1;
      });
      _loadEntries();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _query = value.trim();
        _page = 1;
      });
      _loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideTable = MediaQuery.of(context).size.width > 1100;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B14),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _accentDark,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.shield_moon_outlined),
            const SizedBox(width: 10),
            const Text('Schedule H1 Register',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(width: 12),
            if (context.isDesktop || context.isTablet)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'STATUTORY · 3-YEAR RETENTION',
                  style: TextStyle(fontSize: 10, letterSpacing: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadEntries,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            enabled: !_isExporting,
            icon: _isExporting
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.ios_share),
            onSelected: _exportRegister,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'json', child: Text('Export JSON')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          _buildSummaryStrip(),
          Expanded(child: _buildBody(isWideTable)),
          if (!_isLoading && _error == null && _totalEntries > 0)
            _buildPaginationFooter(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final dateLabel = '${_fmtDate(_startDate)} → ${_fmtDate(_endDate)}';
    final isWide = context.isDesktop || context.isTablet;

    if (isWide) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by patient, doctor, drug, batch or invoice…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1B1B28),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range, color: Colors.white),
              label: Text(dateLabel, style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _pageSize,
                dropdownColor: _surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25 / page')),
                  DropdownMenuItem(value: 50, child: Text('50 / page')),
                  DropdownMenuItem(value: 100, child: Text('100 / page')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _pageSize = v;
                    _page = 1;
                  });
                  _loadEntries();
                },
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search patient, drug, batch…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1B1B28),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range, color: Colors.white, size: 16),
                    label: Text(
                      dateLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    dropdownColor: _surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 25, child: Text('25 / page')),
                      DropdownMenuItem(value: 50, child: Text('50 / page')),
                      DropdownMenuItem(value: 100, child: Text('100 / page')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _pageSize = v;
                        _page = 1;
                      });
                      _loadEntries();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSummaryStrip() {
    final isWide = context.isDesktop || context.isTablet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: _accent.withValues(alpha: 0.25)),
        ),
      ),
      child: isWide
          ? Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(
                  'Total entries: $_totalEntries · Range: '
                  '${_fmtDate(_startDate)} → ${_fmtDate(_endDate)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Schedule H1 — D&C Rules · Drug Inspector audit register',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entries: $_totalEntries · ${_fmtDate(_startDate)} → ${_fmtDate(_endDate)}',
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBody(bool isWideTable) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 12),
            Text('Loading Schedule H1 register…',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange.shade300),
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadEntries,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            const Text(
              'No Schedule H1 dispensations in this range',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Entries are auto-created when an H1 drug is billed via the Rx gate.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildTable(isWideTable);
  }

  Widget _buildTable(bool isWideTable) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: _surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 40,
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateColor.resolveWith(
                      (_) => _accent.withValues(alpha: 0.18)),
                  dataRowColor: WidgetStateColor.resolveWith(
                    (states) {
                      if (states.contains(WidgetState.hovered)) {
                        return _accent.withValues(alpha: 0.05);
                      }
                      return _rowAlt;
                    },
                  ),
                  dividerThickness: 0.5,
                  columnSpacing: isWideTable ? 28 : 18,
                  columns: const [
                    DataColumn(label: _Hdr('Date / Time')),
                    DataColumn(label: _Hdr('Drug')),
                    DataColumn(label: _Hdr('Batch'), tooltip: 'Batch number'),
                    DataColumn(label: _Hdr('Qty'), numeric: true),
                    DataColumn(label: _Hdr('Patient')),
                    DataColumn(label: _Hdr('Address')),
                    DataColumn(label: _Hdr('Prescriber')),
                    DataColumn(label: _Hdr('Reg #')),
                    DataColumn(label: _Hdr('Bill')),
                  ],
                  rows: _entries.map(_rowFromEntry).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _rowFromEntry(Map<String, dynamic> e) {
    final dispensedAt = _formatStamp(e['dispensedAt']);
    final invoiceId = (e['invoiceId'] ?? '-').toString();
    final shortBill = invoiceId.length > 10
        ? '${invoiceId.substring(0, 8)}…'
        : invoiceId;

    return DataRow(cells: [
      DataCell(_Cell(dispensedAt)),
      DataCell(_Cell(e['drugName'] ?? '-', bold: true)),
      DataCell(_Cell(e['batchNumber'] ?? '-')),
      DataCell(_Cell('${e['quantitySold'] ?? 0}', numeric: true)),
      DataCell(_Cell(e['patientName'] ?? '-')),
      DataCell(_Cell(e['patientAddress'] ?? '-')),
      DataCell(_Cell(e['prescribingDoctorName'] ?? '-')),
      DataCell(_Cell(e['doctorRegNo'] ?? '-')),
      DataCell(Tooltip(
        message: invoiceId,
        child: _Cell(shortBill, mono: true),
      )),
    ]);
  }

  String _formatStamp(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('dd-MM-yyyy HH:mm')
          .format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }

  Widget _buildPaginationFooter() {
    final totalPages = (_totalEntries / _pageSize).ceil().clamp(1, 9999);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Page $_page of $totalPages',
            style: const TextStyle(color: Colors.white60),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: _page <= 1
                ? null
                : () {
                    setState(() => _page -= 1);
                    _loadEntries();
                  },
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _page >= totalPages
                ? null
                : () {
                    setState(() => _page += 1);
                    _loadEntries();
                  },
            icon: const Icon(Icons.chevron_right, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String text;
  const _Hdr(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 12.5,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool numeric;
  final bool mono;
  const _Cell(this.text, {this.bold = false, this.numeric = false, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: bold ? Colors.white : Colors.white70,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        fontFeatures: mono ? const [] : null,
        fontFamily: mono ? 'monospace' : null,
      ),
      textAlign: numeric ? TextAlign.right : TextAlign.left,
    );
  }
}
