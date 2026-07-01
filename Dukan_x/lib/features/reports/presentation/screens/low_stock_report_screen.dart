import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Low Stock Alert Report — products below reorder threshold.
/// Uses product inventory API and filters by low stock status.
class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({super.key});

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lowItems = [];
  List<Map<String, dynamic>> _outItems = [];
  String _searchQuery = '';

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
      final all = (rawItems is List)
          ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final low = <Map<String, dynamic>>[];
      final out = <Map<String, dynamic>>[];
      for (final p in all) {
        final qty = (p['currentStock'] as num?)?.toDouble() ?? 0;
        final threshold = (p['lowStockThreshold'] as num?)?.toDouble() ?? 5;
        if (qty <= 0) {
          out.add(p);
        } else if (qty <= threshold) {
          low.add(p);
        }
      }
      // Sort by stock ascending (most critical first)
      low.sort((a, b) => ((a['currentStock'] as num?)?.toDouble() ?? 0).compareTo((b['currentStock'] as num?)?.toDouble() ?? 0));
      out.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
      setState(() { _lowItems = low; _outItems = out; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Low Stock Alert Report'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Low Stock (${_lowItems.length})'),
              Tab(text: 'Out of Stock (${_outItems.length})'),
            ],
          ),
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
                            _card('Low Stock', '${_lowItems.length}', Icons.warning_rounded, Colors.orange, isDark),
                            const SizedBox(width: 12),
                            _card('Out of Stock', '${_outItems.length}', Icons.remove_shopping_cart_rounded, Colors.red, isDark),
                            const SizedBox(width: 12),
                            _card('Critical Total', '${_lowItems.length + _outItems.length}', Icons.error_rounded, Colors.deepOrange, isDark),
                          ],
                        ),
                      ),
                      // Search
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildTable(_filter(_lowItems), isDark, Colors.orange),
                            _buildTable(_filter(_outItems), isDark, Colors.red),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> items, bool isDark, Color alertColor) {
    if (items.isEmpty) {
      return Center(child: Text('No items', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Current Stock'), numeric: true),
            DataColumn(label: Text('Threshold'), numeric: true),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Purchase Price (₹)'), numeric: true),
          ],
          rows: items.map((p) {
            final qty = (p['currentStock'] as num?)?.toDouble() ?? 0;
            final threshold = (p['lowStockThreshold'] as num?)?.toDouble() ?? 5;
            final cost = (p['purchasePriceCents'] as num?)?.toDouble() ?? 0;
            return DataRow(
              color: WidgetStateProperty.all(alertColor.withValues(alpha: 0.06)),
              cells: [
                DataCell(SizedBox(width: 200, child: Text(p['name']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text(p['sku']?.toString() ?? '-')),
                DataCell(Text(qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2),
                    style: TextStyle(fontWeight: FontWeight.w700, color: alertColor))),
                DataCell(Text(threshold.toStringAsFixed(0))),
                DataCell(Text(p['unit']?.toString() ?? '-')),
                DataCell(Text((cost / 100).toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ),
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
