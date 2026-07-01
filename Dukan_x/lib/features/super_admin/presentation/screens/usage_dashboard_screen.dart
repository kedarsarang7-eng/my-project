// ============================================================================
// Usage Dashboard Screen — Super Admin Mobile Panel
// ============================================================================
// Real-time dashboard: active tenants, license expirations in next 30 days,
// plan distribution chart, flagged violations.
// Per-tenant: current user count, device count, feature usage.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class UsageDashboardScreen extends ConsumerStatefulWidget {
  const UsageDashboardScreen({super.key});
  @override
  ConsumerState<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends ConsumerState<UsageDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _expiringLicenses = [];
  List<Map<String, dynamic>> _violations = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadDashboard(); }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/dashboard-stats'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] ?? {};
        setState(() {
          _stats = Map<String, dynamic>.from(data['stats'] ?? {});
          _expiringLicenses = List<Map<String, dynamic>>.from(data['expiringLicenses'] ?? []);
          _violations = List<Map<String, dynamic>>.from(data['violations'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard)],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // KPI Cards Row
                  _buildKpiRow(),
                  const SizedBox(height: 16),
                  // Plan Distribution
                  _buildPlanDistribution(),
                  const SizedBox(height: 16),
                  // Expiring Licenses
                  _buildExpiringSection(),
                  const SizedBox(height: 16),
                  // Violations
                  _buildViolationsSection(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        _kpiCard('Active Tenants', (_stats['activeTenants'] ?? 0).toString(), Icons.business, Colors.blue),
        _kpiCard('Total Users', (_stats['totalUsers'] ?? 0).toString(), Icons.people, Colors.green),
        _kpiCard('Expiring <30d', _expiringLicenses.length.toString(), Icons.timer, Colors.orange),
        _kpiCard('Violations', _violations.length.toString(), Icons.warning, Colors.red),
      ].map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList(),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDistribution() {
    final dist = Map<String, int>.from(_stats['planDistribution'] ?? {'basic': 0, 'pro': 0, 'premium': 0, 'enterprise': 0});
    final total = dist.values.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plan Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...dist.entries.map((e) {
              final pct = total > 0 ? (e.value / total * 100).round() : 0;
              final color = {'basic': Colors.grey, 'pro': Colors.teal, 'premium': Colors.blue, 'enterprise': Colors.purple}[e.key] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(e.key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total > 0 ? e.value / total : 0,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value} ($pct%)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text('Expiring Soon (< 30 days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            if (_expiringLicenses.isEmpty)
              const Text('No licenses expiring soon', style: TextStyle(color: Colors.grey))
            else
              ..._expiringLicenses.take(10).map((lic) {
                final days = lic['daysLeft'] ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(lic['tenantName'] ?? 'Unknown'),
                  subtitle: Text(lic['plan'] ?? 'basic'),
                  trailing: Text(
                    days <= 0 ? 'EXPIRED' : '${days}d left',
                    style: TextStyle(
                      color: days <= 7 ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text('Security Violations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            if (_violations.isEmpty)
              const Text('No violations detected', style: TextStyle(color: Colors.grey))
            else
              ..._violations.take(10).map((v) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.error, color: Colors.red, size: 20),
                title: Text(v['type'] ?? 'Unknown violation'),
                subtitle: Text(v['tenantId'] ?? ''),
                trailing: Text(v['timestamp'] ?? '', style: const TextStyle(fontSize: 11)),
              )),
          ],
        ),
      ),
    );
  }
}
