import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Commission Ledger for Broker (Vegetables/Fruits Broker).
/// Shows commission earned per transaction — farmer-side and buyer-side.
class CommissionLedgerScreen extends StatefulWidget {
  const CommissionLedgerScreen({super.key});

  @override
  State<CommissionLedgerScreen> createState() => _CommissionLedgerScreenState();
}

class _CommissionLedgerScreenState extends State<CommissionLedgerScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  late TabController _tabController;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = sl<ApiClient>();
      final res = await api.get('/reports/export', queryParameters: {
        'from': _fmt(_from), 'to': _fmt(_to), 'type': 'sales', 'format': 'json',
      });
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = res.data ?? {};
      final rawRows = data['rows'] ?? data['data']?['rows'] ?? [];
      final invoices = <Map<String, dynamic>>[];
      if (rawRows is List) {
        for (final row in rawRows) {
          if (row is! List || row.length < 7) continue;
          invoices.add({
            'invoiceNumber': row[0]?.toString() ?? '-',
            'date': row[1]?.toString() ?? '-',
            'party': row[2]?.toString() ?? 'Walk-in',
            'subtotal': double.tryParse(row[3]?.toString() ?? '0') ?? 0,
            'tax': double.tryParse(row[4]?.toString() ?? '0') ?? 0,
            'discount': double.tryParse(row[5]?.toString() ?? '0') ?? 0,
            'total': double.tryParse(row[6]?.toString() ?? '0') ?? 0,
          });
        }
      }
      setState(() { _invoices = invoices; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  double get _totalCommission {
    // Estimate commission as 5% of subtotal (common mandi rate)
    return _invoices.fold(0.0, (s, i) => s + ((i['subtotal'] as double) * 0.05));
  }

  double get _totalRevenue =>
      _invoices.fold(0.0, (s, i) => s + (i['total'] as double));

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Ledger'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Transactions'),
            Tab(text: 'Farmer Summary'),
            Tab(text: 'Buyer Summary'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded),
            label: Text('${_fmt(_from)} → ${_fmt(_to)}'),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _card('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', Icons.trending_up_rounded, Colors.green, isDark),
                          const SizedBox(width: 12),
                          _card('Est. Commission', '₹${_totalCommission.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, Colors.amber.shade700, isDark),
                          const SizedBox(width: 12),
                          _card('Transactions', '${_invoices.length}', Icons.receipt_rounded, Colors.blue, isDark),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTransactionTable(isDark),
                          _buildPartySummary(isDark, 'farmer'),
                          _buildPartySummary(isDark, 'buyer'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTransactionTable(bool isDark) {
    if (_invoices.isEmpty) {
      return Center(child: Text('No transactions', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Invoice #')),
            DataColumn(label: Text('Party')),
            DataColumn(label: Text('Amount (₹)'), numeric: true),
            DataColumn(label: Text('Commission (₹)'), numeric: true),
          ],
          rows: _invoices.map((inv) {
            final commission = (inv['subtotal'] as double) * 0.05;
            return DataRow(cells: [
              DataCell(Text(inv['date']?.toString() ?? '-')),
              DataCell(Text(inv['invoiceNumber']?.toString() ?? '-')),
              DataCell(SizedBox(width: 180, child: Text(inv['party']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(Text((inv['total'] as double).toStringAsFixed(2))),
              DataCell(Text(commission.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade700))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPartySummary(bool isDark, String type) {
    final partyMap = <String, double>{};
    for (final inv in _invoices) {
      final name = inv['party']?.toString() ?? 'Unknown';
      partyMap[name] = (partyMap[name] ?? 0) + (inv['total'] as double);
    }
    final sorted = partyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return Center(child: Text('No ${type}s found', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
    }
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 24,
        columns: [
          DataColumn(label: Text('${type[0].toUpperCase()}${type.substring(1)} Name')),
          const DataColumn(label: Text('Total Amount (₹)'), numeric: true),
          const DataColumn(label: Text('Commission (₹)'), numeric: true),
        ],
        rows: sorted.map((e) => DataRow(cells: [
          DataCell(SizedBox(width: 220, child: Text(e.key, maxLines: 2, overflow: TextOverflow.ellipsis))),
          DataCell(Text(e.value.toStringAsFixed(2))),
          DataCell(Text((e.value * 0.05).toStringAsFixed(2), style: TextStyle(color: Colors.amber.shade700))),
        ])).toList(),
      ),
    );
  }

  Widget _card(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700)),
          ]))]),
      ),
    );
  }
}
