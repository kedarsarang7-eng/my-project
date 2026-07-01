import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// RMA / Warranty Report for Computer Shop.
/// Shows return merchandise authorizations and warranty claims.
class RmaReportScreen extends StatefulWidget {
  const RmaReportScreen({super.key});

  @override
  State<RmaReportScreen> createState() => _RmaReportScreenState();
}

class _RmaReportScreenState extends State<RmaReportScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rmas = [];
  final Map<String, int> _statusCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = sl<ApiClient>();
      // Try RMA endpoint, fallback to job cards
      final res = await api.get('/computer/rma', queryParameters: {'limit': '200'});
      if (!mounted) return;
      if (!res.isSuccess) {
        // Fallback: load job cards instead
        final jcRes = await api.get('/computer/job-cards', queryParameters: {'limit': '200'});
        if (!mounted) return;
        if (!jcRes.isSuccess) {
          setState(() { _error = jcRes.error ?? 'Failed'; _loading = false; });
          return;
        }
        _parseItems(jcRes.data);
        return;
      }
      _parseItems(res.data);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _parseItems(dynamic rawData) {
    final data = (rawData is Map<String, dynamic>) ? rawData : <String, dynamic>{};
    final nestedData = data['data'] ?? data;
    final rawItems = (nestedData is Map) ? (nestedData['items'] ?? nestedData['rmas'] ?? nestedData['jobCards'] ?? []) : [];
    final items = (rawItems is List)
        ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final counts = <String, int>{};
    for (final item in items) {
      final status = (item['status'] ?? 'unknown').toString();
      counts[status] = (counts[status] ?? 0) + 1;
    }

    setState(() {
      _rmas = items;
      _statusCounts.clear();
      _statusCounts.addAll(counts);
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': case 'pending': return Colors.orange;
      case 'in_progress': case 'processing': return Colors.blue;
      case 'resolved': case 'completed': case 'closed': return Colors.green;
      case 'rejected': case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RMA / Warranty Report'),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _card('Total RMAs', '${_rmas.length}', Icons.assignment_return_rounded, Colors.blue, isDark),
                          const SizedBox(width: 12),
                          _card('Open', '${_statusCounts['open'] ?? _statusCounts['pending'] ?? 0}', Icons.pending_rounded, Colors.orange, isDark),
                          const SizedBox(width: 12),
                          _card('Resolved', '${_statusCounts['resolved'] ?? _statusCounts['completed'] ?? _statusCounts['closed'] ?? 0}', Icons.check_circle_rounded, Colors.green, isDark),
                        ],
                      ),
                    ),
                    // Status chips
                    if (_statusCounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          children: _statusCounts.entries.map((e) => Chip(
                            label: Text('${e.key}: ${e.value}'),
                            backgroundColor: _statusColor(e.key).withValues(alpha: 0.15),
                            side: BorderSide(color: _statusColor(e.key).withValues(alpha: 0.4)),
                          )).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _rmas.isEmpty
                          ? Center(child: Text('No RMA/warranty entries', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('ID')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Product/Component')),
                                    DataColumn(label: Text('Serial #')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Reason')),
                                  ],
                                  rows: _rmas.map((r) {
                                    final status = (r['status'] ?? 'unknown').toString();
                                    return DataRow(
                                      color: WidgetStateProperty.all(_statusColor(status).withValues(alpha: 0.04)),
                                      cells: [
                                        DataCell(Text((r['id'] ?? r['SK'] ?? '-').toString().length > 12 ? '...${(r['id'] ?? r['SK'] ?? '').toString().substring((r['id'] ?? r['SK'] ?? '').toString().length - 8)}' : (r['id'] ?? r['SK'] ?? '-').toString())),
                                        DataCell(Text(_formatDate(r['createdAt'] ?? r['date']))),
                                        DataCell(SizedBox(width: 140, child: Text(r['customerName']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(SizedBox(width: 180, child: Text(r['productName']?.toString() ?? r['componentName']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(Text(r['serialNumber']?.toString() ?? '-')),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                                        )),
                                        DataCell(SizedBox(width: 160, child: Text(r['reason']?.toString() ?? r['description']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
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

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(d.toString()));
    } catch (_) {
      return d.toString();
    }
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
