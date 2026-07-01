import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/super_admin_repository.dart';
import 'license_list_screen.dart';
import 'tenant_management_screen.dart';
import 'usage_dashboard_screen.dart';
import 'alert_management_screen.dart';
import 'audit_viewer_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Super Admin Central Control — Tabs for Tenants + Licenses
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SuperAdminRepository _repo = SuperAdminRepository();
  List<TenantData>? _tenants;
  bool _isLoading = true;
  String? _error;

  static const List<String> availableModules = [
    'grocery', 'pharmacy', 'restaurant', 'clothing',
    'electronics', 'hardware', 'clinic', 'wholesale',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadTenants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final tenants = await _repo.getAllTenants();
      setState(() { _tenants = tenants; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _toggleModule(TenantData tenant, String module, bool enabled) async {
    try {
      await _repo.toggleTenantModule(tenantId: tenant.id, businessType: module, enabled: enabled);
      setState(() {
        if (enabled) {
          if (!tenant.activeModules.contains(module)) tenant.activeModules.add(module);
        } else {
          tenant.activeModules.remove(module);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Module ${enabled ? 'enabled' : 'disabled'}'),
          backgroundColor: FuturisticColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: FuturisticColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: const Text('Super Admin: SaaS Central Control'),
        backgroundColor: FuturisticColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTenants),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FuturisticColors.premiumBlue,
          labelColor: Colors.white,
          unselectedLabelColor: FuturisticColors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Tenants'),
            Tab(icon: Icon(Icons.vpn_key), text: 'Licenses'),
            Tab(icon: Icon(Icons.people), text: 'Manage'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Usage'),
            Tab(icon: Icon(Icons.notifications), text: 'Alerts'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Audit'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
        controller: _tabController,
        children: [
          _buildTenantsTab(),
          const LicenseListScreen(),
          const TenantManagementScreen(),
          const UsageDashboardScreen(),
          const AlertManagementScreen(),
          const AuditViewerScreen(),
        ],
      ),
      ),
    );
  }

  Widget _buildTenantsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: FuturisticColors.primary));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: FuturisticColors.error, size: 48),
        const SizedBox(height: 16),
        Text('Error: $_error', style: TextStyle(color: FuturisticColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadTenants, child: const Text('Retry')),
      ]));
    }
    if (_tenants == null || _tenants!.isEmpty) {
      return Center(child: Text('No tenants found.', style: TextStyle(color: FuturisticColors.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: FuturisticColors.premiumCardDecoration(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: FuturisticColors.textPrimary),
            dataTextStyle: TextStyle(color: FuturisticColors.textPrimary),
            columns: [
              const DataColumn(label: Text('Business ID')),
              const DataColumn(label: Text('Name')),
              ...availableModules.map((m) => DataColumn(
                label: Text(m.toUpperCase(), style: const TextStyle(fontSize: 12)),
              )),
            ],
            rows: _tenants!.map((tenant) {
              return DataRow(cells: [
                DataCell(Text(tenant.id, style: const TextStyle(fontSize: 12))),
                DataCell(Text(tenant.name ?? 'Unknown')),
                ...availableModules.map((module) {
                  final isEnabled = tenant.activeModules.contains(module);
                  return DataCell(Switch(
                    value: isEnabled,
                    activeColor: FuturisticColors.primary,
                    onChanged: (val) => _toggleModule(tenant, module, val),
                  ));
                }),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
