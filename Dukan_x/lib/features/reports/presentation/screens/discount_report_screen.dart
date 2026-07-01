import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Discount Report — shows total discounts given, discount by customer,
/// discount by product. Uses sales report data and aggregates discounts.
class DiscountReportScreen extends StatefulWidget {
  const DiscountReportScreen({super.key});

  @override
  State<DiscountReportScreen> createState() => _DiscountReportScreenState();
}

class _DiscountReportScreenState extends State<DiscountReportScreen> {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  int _totalDiscountCents = 0;
  int _totalRevenueCents = 0;
  int _invoiceCount = 0;
  int _discountedInvoiceCount = 0;
  List<Map<String, dynamic>> _rows = [];

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
      final res = await api.get('/reports/export', queryParameters: {
        'from': _fmt(_from),
        'to': _fmt(_to),
        'type': 'sales',
        'format': 'json',
      });
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      // Parse JSON export data
      final body = res.data is String ? res.data : (res.data?['body'] is String ? res.data!['body'] : null);
      Map<String, dynamic> payload;
      if (body is String) {
        payload = Map<String, dynamic>.from(
          (body.startsWith('{')) ? _tryParse(body) : {},
        );
      } else {
        payload = Map<String, dynamic>.from(res.data ?? {});
      }
      final rawRows = payload['rows'] ?? payload['data']?['rows'] ?? [];
      int totalDisc = 0, totalRev = 0, discInvCount = 0;
      final rows = <Map<String, dynamic>>[];
      if (rawRows is List) {
        for (final row in rawRows) {
          if (row is! List || row.length < 7) continue;
          final discountStr = row[5]?.toString() ?? '0';
          final totalStr = row[6]?.toString() ?? '0';
          final discount = (double.tryParse(discountStr) ?? 0);
          final total = (double.tryParse(totalStr) ?? 0);
          totalDisc += (discount * 100).round();
          totalRev += (total * 100).round();
          if (discount > 0) {
            discInvCount++;
            rows.add({
              'invoiceNumber': row[0]?.toString() ?? '-',
              'date': row[1]?.toString() ?? '-',
              'customer': row[2]?.toString() ?? 'Walk-in',
              'subtotal': row[3]?.toString() ?? '0',
              'discount': discountStr,
              'total': totalStr,
            });
          }
        }
      }
      setState(() {
        _totalDiscountCents = totalDisc;
        _totalRevenueCents = totalRev;
        _invoiceCount = (rawRows is List) ? rawRows.length : 0;
        _discountedInvoiceCount = discInvCount;
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  dynamic _tryParse(String s) {
    try { return Map<String, dynamic>.from(Uri.splitQueryString(s)); } catch (_) { return <String, dynamic>{}; }
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
    final discPercent = _totalRevenueCents > 0 ? (_totalDiscountCents / _totalRevenueCents * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discount Report'),
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
                          _card('Total Discount', '₹${(_totalDiscountCents / 100).toStringAsFixed(2)}', Icons.discount_rounded, Colors.red, isDark),
                          const SizedBox(width: 12),
                          _card('Discount %', '${discPercent.toStringAsFixed(1)}%', Icons.percent_rounded, Colors.orange, isDark),
                          const SizedBox(width: 12),
                          _card('Bills with Discount', '$_discountedInvoiceCount / $_invoiceCount', Icons.receipt_rounded, Colors.blue, isDark),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _rows.isEmpty
                          ? Center(child: Text('No discounted invoices', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Invoice #')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Subtotal (₹)'), numeric: true),
                                    DataColumn(label: Text('Discount (₹)'), numeric: true),
                                    DataColumn(label: Text('Total (₹)'), numeric: true),
                                  ],
                                  rows: _rows.map((r) => DataRow(cells: [
                                    DataCell(Text(r['invoiceNumber'] ?? '-')),
                                    DataCell(Text(r['date'] ?? '-')),
                                    DataCell(Text(r['customer'] ?? '-')),
                                    DataCell(Text(r['subtotal'] ?? '0')),
                                    DataCell(Text(r['discount'] ?? '0', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                                    DataCell(Text(r['total'] ?? '0')),
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
        child: Row(
          children: [Icon(icon, color: color), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700)),
            ]))],
        ),
      ),
    );
  }
}
