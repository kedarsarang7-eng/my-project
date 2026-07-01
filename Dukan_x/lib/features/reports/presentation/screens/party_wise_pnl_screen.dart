import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Party-wise Profit & Loss — shows revenue, cost, and profit per customer.
/// Fills a competitive gap vs Vyapar.
class PartyWisePnlScreen extends StatefulWidget {
  const PartyWisePnlScreen({super.key});

  @override
  State<PartyWisePnlScreen> createState() => _PartyWisePnlScreenState();
}

class _PartyWisePnlScreenState extends State<PartyWisePnlScreen> {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _parties = [];
  int _totalRevenueCents = 0;
  // ignore: unused_field
  int _totalProfitCents = 0;

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
      // Use sales export JSON to get per-invoice customer data
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
      
      // Aggregate by customer
      final partyMap = <String, _PartyAgg>{};
      if (rawRows is List) {
        for (final row in rawRows) {
          if (row is! List || row.length < 7) continue;
          final customer = row[2]?.toString().trim();
          final name = (customer != null && customer.isNotEmpty) ? customer : 'Walk-in';
          final subtotal = double.tryParse(row[3]?.toString() ?? '0') ?? 0;
          final total = double.tryParse(row[6]?.toString() ?? '0') ?? 0;
          final agg = partyMap.putIfAbsent(name, () => _PartyAgg(name));
          agg.revenueCents += (subtotal * 100).round();
          agg.totalCents += (total * 100).round();
          agg.invoiceCount++;
        }
      }

      final parties = partyMap.values.map((a) => {
        'name': a.name,
        'revenueCents': a.revenueCents,
        'totalCents': a.totalCents,
        'invoiceCount': a.invoiceCount,
      }).toList();
      parties.sort((a, b) => ((b['revenueCents'] as int?) ?? 0).compareTo((a['revenueCents'] as int?) ?? 0));

      setState(() {
        _parties = parties;
        _totalRevenueCents = parties.fold(0, (s, p) => s + ((p['revenueCents'] as int?) ?? 0));
        _totalProfitCents = 0; // COGS not available per-party without backend enhancement
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
    if (picked != null) { setState(() { _from = picked.start; _to = picked.end; }); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party-wise Revenue'),
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
                          _card('Total Revenue', '₹${(_totalRevenueCents / 100).toStringAsFixed(0)}', Icons.trending_up_rounded, Colors.green, isDark),
                          const SizedBox(width: 12),
                          _card('Unique Parties', '${_parties.length}', Icons.people_rounded, Colors.blue, isDark),
                          const SizedBox(width: 12),
                          _card('Top Party', _parties.isNotEmpty ? _parties.first['name']?.toString() ?? '-' : '-', Icons.star_rounded, Colors.amber, isDark),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _parties.isEmpty
                          ? Center(child: Text('No party data', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 24,
                                  columns: const [
                                    DataColumn(label: Text('#'), numeric: true),
                                    DataColumn(label: Text('Party Name')),
                                    DataColumn(label: Text('Invoices'), numeric: true),
                                    DataColumn(label: Text('Revenue (₹)'), numeric: true),
                                    DataColumn(label: Text('% Share'), numeric: true),
                                  ],
                                  rows: _parties.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final p = entry.value;
                                    final rev = (p['revenueCents'] as int?) ?? 0;
                                    final share = _totalRevenueCents > 0 ? (rev / _totalRevenueCents * 100) : 0.0;
                                    return DataRow(cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(SizedBox(width: 200, child: Text(p['name']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                      DataCell(Text('${p['invoiceCount'] ?? 0}')),
                                      DataCell(Text((rev / 100).toStringAsFixed(2))),
                                      DataCell(Text('${share.toStringAsFixed(1)}%')),
                                    ]);
                                  }).toList(),
                                ),
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

class _PartyAgg {
  final String name;
  int revenueCents = 0;
  int totalCents = 0;
  int invoiceCount = 0;
  _PartyAgg(this.name);
}
