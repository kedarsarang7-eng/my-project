import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class StockSummaryReportScreen extends StatefulWidget {
  const StockSummaryReportScreen({super.key});

  @override
  State<StockSummaryReportScreen> createState() => _StockSummaryReportScreenState();
}

class _StockSummaryReportScreenState extends State<StockSummaryReportScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _stockFilter = 'all'; // all, low, out, negative

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = sl<ApiClient>();
      final res = await api.get('/inventory/products', queryParameters: {'limit': '500'});
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>? ?? {};
      final rawItems = data['items'] ?? data['products'] ?? [];
      setState(() {
        _products = (rawItems is List)
            ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _products;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        return name.contains(q) || sku.contains(q);
      }).toList();
    }
    switch (_stockFilter) {
      case 'low':
        list = list.where((p) {
          final qty = (p['currentStock'] as num?)?.toDouble() ?? 0;
          final low = (p['lowStockThreshold'] as num?)?.toDouble() ?? 5;
          return qty > 0 && qty <= low;
        }).toList();
        break;
      case 'out':
        list = list.where((p) => ((p['currentStock'] as num?)?.toDouble() ?? 0) == 0).toList();
        break;
      case 'negative':
        list = list.where((p) => ((p['currentStock'] as num?)?.toDouble() ?? 0) < 0).toList();
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _filtered;
    int totalItems = items.length;
    double totalValue = 0;
    int lowStockCount = 0;
    int outOfStockCount = 0;
    for (final p in items) {
      final qty = (p['currentStock'] as num?)?.toDouble() ?? 0;
      final cost = (p['purchasePriceCents'] as num?)?.toDouble() ?? 0;
      totalValue += qty * cost / 100;
      final low = (p['lowStockThreshold'] as num?)?.toDouble() ?? 5;
      if (qty <= 0) {
        outOfStockCount++;
      } else if (qty <= low) {
        lowStockCount++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Summary Report'),
        actions: [
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
                    // Summary
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _card('Total Items', '$totalItems', Icons.inventory_2_rounded, Colors.blue, isDark),
                          const SizedBox(width: 12),
                          _card('Stock Value', '₹${totalValue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, Colors.green, isDark),
                          const SizedBox(width: 12),
                          _card('Low Stock', '$lowStockCount', Icons.warning_rounded, Colors.orange, isDark),
                          const SizedBox(width: 12),
                          _card('Out of Stock', '$outOfStockCount', Icons.remove_shopping_cart_rounded, Colors.red, isDark),
                        ],
                      ),
                    ),
                    // Toolbar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'all', label: Text('All')),
                              ButtonSegment(value: 'low', label: Text('Low')),
                              ButtonSegment(value: 'out', label: Text('Out')),
                              ButtonSegment(value: 'negative', label: Text('Negative')),
                            ],
                            selected: {_stockFilter},
                            onSelectionChanged: (v) => setState(() => _stockFilter = v.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Table
                    Expanded(
                      child: items.isEmpty
                          ? Center(child: Text('No products match', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Product')),
                                    DataColumn(label: Text('SKU')),
                                    DataColumn(label: Text('Current Stock'), numeric: true),
                                    DataColumn(label: Text('Unit')),
                                    DataColumn(label: Text('Purchase Price (₹)'), numeric: true),
                                    DataColumn(label: Text('Sale Price (₹)'), numeric: true),
                                    DataColumn(label: Text('Stock Value (₹)'), numeric: true),
                                  ],
                                  rows: items.map((p) {
                                    final qty = (p['currentStock'] as num?)?.toDouble() ?? 0;
                                    final cost = (p['purchasePriceCents'] as num?)?.toDouble() ?? 0;
                                    final sale = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
                                    final value = qty * cost / 100;
                                    final low = (p['lowStockThreshold'] as num?)?.toDouble() ?? 5;
                                    Color? rowColor;
                                    if (qty <= 0) {
                                      rowColor = Colors.red.withValues(alpha: 0.08);
                                    } else if (qty <= low) {
                                      rowColor = Colors.orange.withValues(alpha: 0.08);
                                    }
                                    return DataRow(
                                      color: rowColor != null ? WidgetStateProperty.all(rowColor) : null,
                                      cells: [
                                        DataCell(SizedBox(width: 200, child: Text(p['name']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(Text(p['sku']?.toString() ?? '-')),
                                        DataCell(Text(qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2))),
                                        DataCell(Text(p['unit']?.toString() ?? '-')),
                                        DataCell(Text((cost / 100).toStringAsFixed(2))),
                                        DataCell(Text((sale / 100).toStringAsFixed(2))),
                                        DataCell(Text(value.toStringAsFixed(2))),
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
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                  Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
