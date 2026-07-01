// ============================================================================
// Alert Management Screen — Super Admin Mobile Panel
// ============================================================================
// Monitors: 90% user-limit alerts, 7-day license expiry warnings,
// cross-tenant violations, denylist events.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

enum AlertSeverity { critical, warning, info }

class AlertManagementScreen extends ConsumerStatefulWidget {
  const AlertManagementScreen({super.key});
  @override
  ConsumerState<AlertManagementScreen> createState() => _AlertManagementScreenState();
}

class _AlertManagementScreenState extends ConsumerState<AlertManagementScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  String _severityFilter = 'all';

  @override
  void initState() { super.initState(); _loadAlerts(); }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/alerts'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_severityFilter == 'all') return _alerts;
    return _alerts.where((a) => a['severity'] == _severityFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAlerts),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Critical', 'critical', Colors.red),
                const SizedBox(width: 8),
                _filterChip('Warning', 'warning', Colors.orange),
                const SizedBox(width: 8),
                _filterChip('Info', 'info', Colors.blue),
              ],
            ),
          ),
          // Alert List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAlerts.isEmpty
                    ? const Center(child: Text('No alerts', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _loadAlerts,
                        child: ListView.builder(
                          itemCount: _filteredAlerts.length,
                          itemBuilder: (ctx, i) => _buildAlertCard(_filteredAlerts[i]),
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _filterChip(String label, String value, [Color? color]) {
    final isSelected = _severityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color?.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _severityFilter = value),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] ?? 'info';
    final Color color;
    final IconData icon;

    switch (severity) {
      case 'critical':
        color = Colors.red;
        icon = Icons.error;
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning_amber;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info_outline;
    }

    final isResolved = alert['resolved'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isResolved ? Colors.grey.shade300 : color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: isResolved ? Colors.grey : color, size: 22),
        ),
        title: Text(
          alert['title'] ?? 'Alert',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isResolved ? TextDecoration.lineThrough : null,
            color: isResolved ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(alert['tenantName'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Text(alert['timestamp'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: isResolved
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : IconButton(
                icon: const Icon(Icons.check, size: 20),
                onPressed: () => _resolveAlert(alert),
              ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _resolveAlert(Map<String, dynamic> alert) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/alerts/${alert['id']}/resolve'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      _loadAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
