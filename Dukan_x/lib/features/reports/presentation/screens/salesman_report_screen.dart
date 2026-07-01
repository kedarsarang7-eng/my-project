import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Salesman Performance Report — shows per-salesman billing totals.
/// Used by Wholesale for salesman efficiency and route sales.
/// Groups invoice data by salesman/staff name.
class SalesmanReportScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const SalesmanReportScreen({
    super.key,
    this.title = 'Salesman Performance',
    this.subtitle = 'Per-salesman billing and collections',
  });

  @override
  State<SalesmanReportScreen> createState() => _SalesmanReportScreenState();
}

class _SalesmanReportScreenState extends State<SalesmanReportScreen> {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _salesmen = [];
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
    _load();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = sl<ApiClient>();
      final res = await api.get('/reports/sales', queryParameters: {
        'from': _fmt(_from), 'to': _fmt(_to),
      });
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>? ?? {};
      // Salesperson breakdown if available from backend
      final salespersonBreakdown = data['salesperson'] ?? data['bySalesperson'] ?? {};
      final staffMap = <String, Map<String, dynamic>>{};

      if (salespersonBreakdown is Map && salespersonBreakdown.isNotEmpty) {
        for (final entry in salespersonBreakdown.entries) {
          final name = entry.key?.toString() ?? 'Unknown';
          final val = entry.value;
          staffMap[name] = {
            'name': name,
            'totalCents': (val is Map ? (val['totalCents'] as num?)?.toInt() ?? 0 : 0),
            'invoiceCount': (val is Map ? (val['invoiceCount'] as num?)?.toInt() ?? 0 : 0),
          };
        }
      } else {
        // Fallback: single entry with overall totals
        final totalCents = (data['totalRevenueCents'] as num?)?.toInt() ?? 0;
        final count = (data['invoiceCount'] as num?)?.toInt() ?? 0;
        staffMap['All Staff'] = {'name': 'All Staff', 'totalCents': totalCents, 'invoiceCount': count};
      }

      final sorted = staffMap.values.toList()
        ..sort((a, b) => ((b['totalCents'] as int?) ?? 0).compareTo((a['totalCents'] as int?) ?? 0));

      setState(() {
        _salesmen = sorted;
        _totalRevenue = sorted.fold(0.0, (s, e) => s + ((e['totalCents'] as int?) ?? 0) / 100);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

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
        title: Text(widget.title),
        actions: [
          TextButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range_rounded), label: Text('${_fmt(_from)} → ${_fmt(_to)}')),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
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
                          _card('Staff Count', '${_salesmen.length}', Icons.people_rounded, Colors.blue, isDark),
                          const SizedBox(width: 12),
                          _card('Top Performer', _salesmen.isNotEmpty ? _salesmen.first['name']?.toString() ?? '-' : '-', Icons.star_rounded, Colors.amber, isDark),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _salesmen.isEmpty
                          ? Center(child: Text('No data', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('#'), numeric: true),
                                  DataColumn(label: Text('Salesman')),
                                  DataColumn(label: Text('Invoices'), numeric: true),
                                  DataColumn(label: Text('Revenue (₹)'), numeric: true),
                                  DataColumn(label: Text('% Share'), numeric: true),
                                ],
                                rows: _salesmen.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final s = entry.value;
                                  final rev = ((s['totalCents'] as int?) ?? 0) / 100;
                                  final share = _totalRevenue > 0 ? (rev / _totalRevenue * 100) : 0.0;
                                  return DataRow(cells: [
                                    DataCell(Text('${i + 1}')),
                                    DataCell(SizedBox(width: 200, child: Text(s['name']?.toString() ?? '-'))),
                                    DataCell(Text('${s['invoiceCount'] ?? 0}')),
                                    DataCell(Text(rev.toStringAsFixed(2))),
                                    DataCell(Text('${share.toStringAsFixed(1)}%')),
                                  ]);
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
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
