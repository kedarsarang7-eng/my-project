import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Old Gold Purchase Register — PML Act compliance for amounts > ₹50K.
class OldGoldRegisterScreen extends StatefulWidget {
  const OldGoldRegisterScreen({super.key});

  @override
  State<OldGoldRegisterScreen> createState() => _OldGoldRegisterScreenState();
}

class _OldGoldRegisterScreenState extends State<OldGoldRegisterScreen> {
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _items = [];
  int _totalPurchases = 0;
  double _totalWeight = 0;
  int _totalAmount = 0;
  int _pmlFlagged = 0;

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
      final res = await api.get('/jewellery/reports/old-gold-register', queryParameters: {
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
        _totalPurchases = (data['totalPurchases'] as num?)?.toInt() ?? _items.length;
        _totalWeight = (data['totalWeightGrams'] as num?)?.toDouble() ?? 0;
        _totalAmount = (data['totalAmount'] as num?)?.toInt() ?? 0;
        _pmlFlagged = (data['pmlFlaggedCount'] as num?)?.toInt() ?? 0;
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
        title: const Text('Old Gold Purchase Register'),
        backgroundColor: Colors.amber.shade900,
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
                          _card('Purchases', '$_totalPurchases', Icons.shopping_bag_rounded, Colors.amber.shade700, isDark),
                          const SizedBox(width: 12),
                          _card('Total Weight', '${_totalWeight.toStringAsFixed(2)}g', Icons.scale_rounded, Colors.deepPurple, isDark),
                          const SizedBox(width: 12),
                          _card('Total Amount', '₹${(_totalAmount / 100).toStringAsFixed(0)}', Icons.currency_rupee_rounded, Colors.green, isDark),
                          const SizedBox(width: 12),
                          _card('PML Flagged', '$_pmlFlagged', Icons.warning_rounded, Colors.red, isDark),
                        ],
                      ),
                    ),
                    if (_pmlFlagged > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.red.withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            const Icon(Icons.gavel_rounded, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text('$_pmlFlagged transactions ≥ ₹50,000 — KYC mandatory under PML Act', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red))),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(child: Text('No old gold purchases in period', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Supplier/Customer')),
                                    DataColumn(label: Text('Metal')),
                                    DataColumn(label: Text('Weight (g)'), numeric: true),
                                    DataColumn(label: Text('Purity')),
                                    DataColumn(label: Text('Rate/g (₹)'), numeric: true),
                                    DataColumn(label: Text('Amount (₹)'), numeric: true),
                                    DataColumn(label: Text('KYC Ref')),
                                  ],
                                  rows: _items.map((r) {
                                    final amt = (r['totalAmount'] as num?)?.toInt() ?? 0;
                                    final isPml = amt >= 5000000;
                                    return DataRow(
                                      color: isPml ? WidgetStateProperty.all(Colors.red.withValues(alpha: 0.06)) : null,
                                      cells: [
                                        DataCell(Text(r['purchaseDate']?.toString() ?? '-')),
                                        DataCell(Text(r['supplierName']?.toString() ?? '-')),
                                        DataCell(Text(r['metalType']?.toString() ?? 'Gold')),
                                        DataCell(Text(((r['weightGrams'] as num?)?.toDouble() ?? 0).toStringAsFixed(2))),
                                        DataCell(Text(r['purity']?.toString() ?? '-')),
                                        DataCell(Text((((r['ratePerGramCents'] as num?)?.toDouble() ?? 0) / 100).toStringAsFixed(2))),
                                        DataCell(Text((amt / 100).toStringAsFixed(2))),
                                        DataCell(Text(r['kycReference']?.toString() ?? 'N/A', style: TextStyle(color: r['kycReference']?.toString() == 'N/A' && isPml ? Colors.red : null))),
                                      ],
                                    );
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
