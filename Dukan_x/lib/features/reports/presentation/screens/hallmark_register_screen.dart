import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Hallmark compliance register — BIS mandatory for all jewellers.
/// Shows HUID, purity, weight, article type for all sold items.
class HallmarkRegisterScreen extends StatefulWidget {
  const HallmarkRegisterScreen({super.key});

  @override
  State<HallmarkRegisterScreen> createState() => _HallmarkRegisterScreenState();
}

class _HallmarkRegisterScreenState extends State<HallmarkRegisterScreen> {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _items = [];
  int _totalItems = 0;
  double _totalWeight = 0;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 90));
    _load();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = sl<ApiClient>();
      final res = await api.get('/jewellery/reports/hallmark-register', queryParameters: {
        'from': _fmt(_from), 'to': _fmt(_to),
      });
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>? ?? {};
      setState(() {
        _items = (data['items'] is List)
            ? (data['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _totalItems = (data['totalItems'] as num?)?.toInt() ?? _items.length;
        _totalWeight = (data['totalWeightGrams'] as num?)?.toDouble() ?? 0;
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
        title: const Text('Hallmark Compliance Register'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range, color: Colors.white), label: Text('${_fmt(_from)} → ${_fmt(_to)}', style: const TextStyle(color: Colors.white))),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: Colors.white)),
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
                          _card('Total Items', '$_totalItems', Icons.diamond_rounded, Colors.amber.shade700, isDark),
                          const SizedBox(width: 12),
                          _card('Total Weight', '${_totalWeight.toStringAsFixed(2)}g', Icons.scale_rounded, Colors.deepPurple, isDark),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.amber.withValues(alpha: 0.08),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(child: Text('BIS Hallmarking Order 2023 — This register must be available for inspection at all times.', style: TextStyle(fontSize: 12, color: Colors.white70))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(child: Text('No hallmarked items sold in period', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Invoice #')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Product')),
                                    DataColumn(label: Text('HUID')),
                                    DataColumn(label: Text('Purity')),
                                    DataColumn(label: Text('Weight (g)'), numeric: true),
                                    DataColumn(label: Text('Article Type')),
                                    DataColumn(label: Text('Amount (₹)'), numeric: true),
                                  ],
                                  rows: _items.map((r) => DataRow(cells: [
                                    DataCell(Text(r['invoiceNumber']?.toString() ?? '-')),
                                    DataCell(Text(r['invoiceDate']?.toString() ?? '-')),
                                    DataCell(Text(r['customerName']?.toString() ?? '-')),
                                    DataCell(SizedBox(width: 160, child: Text(r['productName']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                    DataCell(Text(r['huid']?.toString() ?? 'N/A', style: TextStyle(fontWeight: FontWeight.w600, color: r['huid']?.toString() == 'N/A' ? Colors.red : null))),
                                    DataCell(Text(r['purity']?.toString() ?? '-')),
                                    DataCell(Text(((r['weightGrams'] as num?)?.toDouble() ?? 0).toStringAsFixed(2))),
                                    DataCell(Text(r['articleType']?.toString() ?? '-')),
                                    DataCell(Text((((r['amountCents'] as num?)?.toDouble() ?? 0) / 100).toStringAsFixed(2))),
                                  ])).toList(),
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
            Text(value, style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700)),
          ]))]),
      ),
    );
  }
}
