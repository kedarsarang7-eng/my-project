import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Job Card Report — shows service/repair job cards with turnaround analysis.
/// Used by Service Center, Computer Shop, and Auto Parts.
class JobCardReportScreen extends StatefulWidget {
  const JobCardReportScreen({super.key});

  @override
  State<JobCardReportScreen> createState() => _JobCardReportScreenState();
}

class _JobCardReportScreenState extends State<JobCardReportScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jobs = [];
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
      // Try service jobs first, then computer job cards
      var res = await api.get('/service/jobs', queryParameters: {'limit': '200'});
      if (!res.isSuccess) {
        res = await api.get('/computer/job-cards', queryParameters: {'limit': '200'});
      }
      if (!mounted) return;
      if (!res.isSuccess) {
        setState(() { _error = res.error ?? 'Failed'; _loading = false; });
        return;
      }
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>? ?? {};
      final rawItems = data['items'] ?? data['jobs'] ?? data['jobCards'] ?? [];
      final items = (rawItems is List)
          ? rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      final counts = <String, int>{};
      for (final job in items) {
        final status = (job['status'] ?? 'unknown').toString();
        counts[status] = (counts[status] ?? 0) + 1;
      }

      // Sort by created date desc
      items.sort((a, b) {
        final aDate = (a['createdAt'] ?? '').toString();
        final bDate = (b['createdAt'] ?? '').toString();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _jobs = items;
        _statusCounts.clear();
        _statusCounts.addAll(counts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': case 'pending': case 'received': return Colors.orange;
      case 'in_progress': case 'diagnosing': case 'repairing': return Colors.blue;
      case 'completed': case 'closed': case 'delivered': return Colors.green;
      case 'cancelled': case 'rejected': return Colors.red;
      case 'waiting_parts': case 'on_hold': return Colors.purple;
      default: return Colors.grey;
    }
  }

  int _calcTurnaround(Map<String, dynamic> job) {
    try {
      final created = DateTime.parse(job['createdAt'].toString());
      final completed = job['completedAt'] != null
          ? DateTime.parse(job['completedAt'].toString())
          : DateTime.now();
      return completed.difference(created).inDays;
    } catch (_) {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final openJobs = _statusCounts.entries
        .where((e) => ['open', 'pending', 'received', 'in_progress', 'diagnosing', 'repairing', 'waiting_parts', 'on_hold'].contains(e.key.toLowerCase()))
        .fold(0, (s, e) => s + e.value);
    final closedJobs = _jobs.length - openJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Card Report'),
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
                          _card('Total Jobs', '${_jobs.length}', Icons.build_rounded, Colors.blue, isDark),
                          const SizedBox(width: 12),
                          _card('Open', '$openJobs', Icons.pending_actions_rounded, Colors.orange, isDark),
                          const SizedBox(width: 12),
                          _card('Closed', '$closedJobs', Icons.check_circle_rounded, Colors.green, isDark),
                        ],
                      ),
                    ),
                    if (_statusCounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _statusCounts.entries.map((e) => Chip(
                            label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                            backgroundColor: _statusColor(e.key).withValues(alpha: 0.12),
                            side: BorderSide(color: _statusColor(e.key).withValues(alpha: 0.3)),
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _jobs.isEmpty
                          ? Center(child: Text('No job cards', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Device/Vehicle')),
                                    DataColumn(label: Text('Issue')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('TAT (days)'), numeric: true),
                                    DataColumn(label: Text('Amount (₹)'), numeric: true),
                                  ],
                                  rows: _jobs.map((j) {
                                    final status = (j['status'] ?? 'unknown').toString();
                                    final tat = _calcTurnaround(j);
                                    return DataRow(
                                      color: WidgetStateProperty.all(_statusColor(status).withValues(alpha: 0.04)),
                                      cells: [
                                        DataCell(Text(_formatDate(j['createdAt']))),
                                        DataCell(SizedBox(width: 140, child: Text(j['customerName']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(SizedBox(width: 140, child: Text(j['deviceName']?.toString() ?? j['vehicleName']?.toString() ?? j['productName']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(SizedBox(width: 160, child: Text(j['issue']?.toString() ?? j['description']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                        DataCell(Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(status))),
                                        )),
                                        DataCell(Text(tat >= 0 ? '$tat' : '-', style: TextStyle(color: tat > 7 ? Colors.red : null))),
                                        DataCell(Text(j['estimatedCostCents'] != null ? ((j['estimatedCostCents'] as num).toDouble() / 100).toStringAsFixed(2) : '-')),
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
