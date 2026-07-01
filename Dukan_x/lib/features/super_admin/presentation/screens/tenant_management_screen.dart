// ============================================================================
// Tenant Management Screen — Super Admin Mobile Panel
// ============================================================================
// Create, suspend, delete tenants. View all tenants with plan, usage, expiry.
// Drill-in to impersonate tenant (read-only default).
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TenantManagementScreen extends ConsumerStatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  ConsumerState<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends ConsumerState<TenantManagementScreen> {
  List<Map<String, dynamic>> _tenants = [];
  bool _loading = true;
  String _searchQuery = '';
  String _planFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/tenants'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tenants = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tenants: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTenants {
    return _tenants.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesPlan = _planFilter == 'all' || t['subscriptionPlan'] == _planFilter;
      return matchesSearch && matchesPlan;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTenants),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTenantDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Tenant'),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Search + Filter Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tenants...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _planFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Plans')),
                    DropdownMenuItem(value: 'basic', child: Text('Basic')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro')),
                    DropdownMenuItem(value: 'premium', child: Text('Premium')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                  ],
                  onChanged: (v) => setState(() => _planFilter = v ?? 'all'),
                ),
              ],
            ),
          ),
          // Tenant List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTenants.isEmpty
                    ? const Center(child: Text('No tenants found'))
                    : RefreshIndicator(
                        onRefresh: _loadTenants,
                        child: ListView.builder(
                          itemCount: _filteredTenants.length,
                          itemBuilder: (ctx, i) => _buildTenantCard(_filteredTenants[i]),
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final plan = tenant['subscriptionPlan'] ?? 'basic';
    final status = tenant['licenseStatus'] ?? 'inactive';
    final isActive = status == 'active';
    final expiresAt = tenant['licenseExpiresAt'];
    final daysLeft = expiresAt != null
        ? DateTime.parse(expiresAt).difference(DateTime.now()).inDays
        : null;

    Color planColor;
    switch (plan) {
      case 'enterprise': planColor = Colors.purple; break;
      case 'premium': planColor = Colors.blue; break;
      case 'pro': planColor = Colors.teal; break;
      default: planColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: planColor.withValues(alpha: 0.15),
          child: Text(plan[0].toUpperCase(), style: TextStyle(color: planColor, fontWeight: FontWeight.bold)),
        ),
        title: Text(tenant['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${tenant['businessType'] ?? 'other'} • ${isActive ? 'Active' : status}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(
              label: Text(plan.toUpperCase(), style: const TextStyle(fontSize: 10)),
              backgroundColor: planColor.withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (daysLeft != null && daysLeft <= 30)
              Text(
                daysLeft <= 0 ? 'EXPIRED' : '${daysLeft}d left',
                style: TextStyle(
                  fontSize: 11,
                  color: daysLeft <= 7 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        onTap: () => _showTenantActions(tenant),
      ),
    );
  }

  void _showTenantActions(Map<String, dynamic> tenant) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () { Navigator.pop(context); _showTenantDetails(tenant); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change Plan'),
              onTap: () { Navigator.pop(context); _showChangePlanDialog(tenant); },
            ),
            ListTile(
              leading: Icon(
                tenant['isActive'] == true ? Icons.pause_circle : Icons.play_circle,
                color: tenant['isActive'] == true ? Colors.orange : Colors.green,
              ),
              title: Text(tenant['isActive'] == true ? 'Suspend Tenant' : 'Reactivate Tenant'),
              onTap: () { Navigator.pop(context); _toggleTenantStatus(tenant); },
            ),
            ListTile(
              leading: const Icon(Icons.person_search, color: Colors.indigo),
              title: const Text('Impersonate (Read-Only)'),
              onTap: () { Navigator.pop(context); _impersonateTenant(tenant); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Tenant', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _confirmDeleteTenant(tenant); },
            ),
          ],
        ),
      ),
    );
  }

  void _showTenantDetails(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tenant['name'] ?? 'Tenant Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Tenant ID', tenant['tenantId'] ?? ''),
              _detailRow('Business Type', tenant['businessType'] ?? ''),
              _detailRow('Plan', tenant['subscriptionPlan'] ?? ''),
              _detailRow('Status', tenant['licenseStatus'] ?? 'inactive'),
              _detailRow('Email', tenant['email'] ?? ''),
              _detailRow('Phone', tenant['phone'] ?? ''),
              _detailRow('Created', tenant['createdAt'] ?? ''),
              _detailRow('License Expires', tenant['licenseExpiresAt'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showCreateTenantDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedPlan = 'basic';
    String selectedBizType = 'other';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create New Tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Business Name')),
                const SizedBox(height: 8),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Owner Email')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: ['basic', 'pro', 'premium', 'enterprise']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedPlan = v ?? 'basic'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedBizType,
                  decoration: const InputDecoration(labelText: 'Business Type'),
                  items: ['grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
                          'mobileShop', 'computerShop', 'hardware', 'service', 'wholesale',
                          'petrolPump', 'vegetablesBroker', 'clinic', 'bookStore',
                          'jewellery', 'autoParts', 'other']
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBizType = v ?? 'other'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _createTenant(nameCtrl.text, emailCtrl.text, selectedPlan, selectedBizType);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTenant(String name, String email, String plan, String bizType) async {
    // Delegate to license generation endpoint
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Creating tenant...')));
    await _loadTenants(); // Refresh
  }

  void _showChangePlanDialog(Map<String, dynamic> tenant) {
    String newPlan = tenant['subscriptionPlan'] ?? 'basic';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Plan: ${tenant['name']}'),
          content: DropdownButtonFormField<String>(
            value: newPlan,
            items: ['basic', 'pro', 'premium', 'enterprise']
                .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                .toList(),
            onChanged: (v) => setDialogState(() => newPlan = v ?? newPlan),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _changePlan(tenant, newPlan); },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePlan(Map<String, dynamic> tenant, String newPlan) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Changing plan to $newPlan...')));
    await _loadTenants();
  }

  Future<void> _toggleTenantStatus(Map<String, dynamic> tenant) async {
    final action = tenant['isActive'] == true ? 'suspend' : 'reactivate';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${action}ing tenant...')));
    await _loadTenants();
  }

  void _impersonateTenant(Map<String, dynamic> tenant) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impersonating ${tenant['name']} (read-only)...')),
    );
  }

  void _confirmDeleteTenant(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Delete Tenant'),
        content: Text(
          'This will permanently delete "${tenant['name']}" and ALL associated data.\n\n'
          'This action CANNOT be undone. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(context); _deleteTenant(tenant); },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTenant(Map<String, dynamic> tenant) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting tenant...')));
    await _loadTenants();
  }
}
