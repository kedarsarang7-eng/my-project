import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ExpenseRegisterScreen extends StatefulWidget {
  const ExpenseRegisterScreen({super.key});

  @override
  State<ExpenseRegisterScreen> createState() => _ExpenseRegisterScreenState();
}

class _ExpenseRegisterScreenState extends State<ExpenseRegisterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _totalCents = 0;
  int _expenseCount = 0;
  late DateTime _from;
  late DateTime _to;
  String _categoryFilter = '';

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
      final query = <String, String>{
        'from': _fmt(_from),
        'to': _fmt(_to),
      };
      if (_categoryFilter.isNotEmpty) query['category'] = _categoryFilter;
      final res = await api.get('/reports/expense-register', queryParameters: query);
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>? ?? {};
      final rawItems = data['items'];
      final totals = data['totals'] as Map<String, dynamic>? ?? {};
      setState(() {
        _items = (rawItems is List)
            ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _totalCents = (totals['totalCents'] as num?)?.toInt() ?? 0;
        _expenseCount = (totals['expenseCount'] as num?)?.toInt() ?? _items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
        title: const Text('Expense Register'),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded),
            label: Text('${_fmt(_from)} → ${_fmt(_to)}'),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Category filter',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (v) {
                _categoryFilter = v.trim();
                _load();
              },
            ),
          ),
          const SizedBox(width: 8),
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
                    // Summary cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _summaryCard('Total Expenses', '₹${(_totalCents / 100).toStringAsFixed(2)}', Icons.money_off_rounded, Colors.red, isDark),
                          const SizedBox(width: 12),
                          _summaryCard('Transactions', '$_expenseCount', Icons.receipt_long_rounded, Colors.orange, isDark),
                          const SizedBox(width: 12),
                          _summaryCard('Avg Expense', _expenseCount > 0 ? '₹${(_totalCents / _expenseCount / 100).toStringAsFixed(2)}' : '₹0', Icons.analytics_rounded, Colors.blue, isDark),
                        ],
                      ),
                    ),
                    // Table
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Text('No expenses in this period',
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Category')),
                                    DataColumn(label: Text('Amount (₹)'), numeric: true),
                                    DataColumn(label: Text('Payment Mode')),
                                    DataColumn(label: Text('Vendor')),
                                    DataColumn(label: Text('Notes')),
                                  ],
                                  rows: _items.map((e) {
                                    final amt = (e['amountCents'] as num?)?.toInt() ?? 0;
                                    return DataRow(cells: [
                                      DataCell(Text(e['expenseDate']?.toString() ?? '-')),
                                      DataCell(Text(e['category']?.toString() ?? '-')),
                                      DataCell(Text((amt / 100).toStringAsFixed(2))),
                                      DataCell(Text(e['paymentMode']?.toString() ?? '-')),
                                      DataCell(Text(e['vendorName']?.toString() ?? '-')),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            e['notes']?.toString() ?? '-',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
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

  Widget _summaryCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  Text(label, style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
