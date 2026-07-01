// ignore_for_file: unused_field
// ============================================================================
// License Feature Override Screen — Manual Feature Grid + CSV Export
// ============================================================================
// Super Admin can add/remove individual features from a license regardless
// of plan. Changes are audited and trigger manifest invalidation.
//
// Features:
//   - Searchable feature grid with checkboxes
//   - Bulk add/remove with reason capture
//   - CSV export of current overrides
//   - Real-time override status display
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// All possible features that can be manually overridden
final Map<String, Map<String, dynamic>> _allFeatures = {
  // Core POS
  'standard_pos': {'name': 'Standard POS', 'category': 'Core', 'tier': 'basic'},
  'basic_inventory': {'name': 'Basic Inventory', 'category': 'Core', 'tier': 'basic'},
  'customer_ledger': {'name': 'Customer Ledger', 'category': 'Core', 'tier': 'basic'},
  'expense_tracker': {'name': 'Expense Tracker', 'category': 'Core', 'tier': 'basic'},
  'accounting_khata': {'name': 'Accounting (Khata)', 'category': 'Core', 'tier': 'basic'},
  
  // Pro Features
  'advanced_reports': {'name': 'Advanced Reports', 'category': 'Analytics', 'tier': 'pro'},
  'barcode_tag_printing': {'name': 'Barcode/Tag Printing', 'category': 'Inventory', 'tier': 'pro'},
  'stock_valuation': {'name': 'Stock Valuation', 'category': 'Inventory', 'tier': 'pro'},
  'basic_reorder_alerts': {'name': 'Basic Reorder Alerts', 'category': 'Inventory', 'tier': 'pro'},
  
  // Premium Features
  'advanced_role_permissions': {'name': 'Advanced Role Permissions', 'category': 'Security', 'tier': 'premium'},
  'vendor_po_automation': {'name': 'Vendor PO Automation', 'category': 'Procurement', 'tier': 'premium'},
  'aging_reports': {'name': 'Aging Reports', 'category': 'Analytics', 'tier': 'premium'},
  'api_access': {'name': 'API Access', 'category': 'Integration', 'tier': 'premium'},
  
  // Enterprise Features
  'multi_branch': {'name': 'Multi-Branch', 'category': 'Scale', 'tier': 'enterprise'},
  'centralized_inventory_sync': {'name': 'Centralized Inventory Sync', 'category': 'Scale', 'tier': 'enterprise'},
  'audit_logs': {'name': 'Audit Logs', 'category': 'Security', 'tier': 'enterprise'},
  'advanced_analytics': {'name': 'Advanced Analytics', 'category': 'Analytics', 'tier': 'enterprise'},
  'financial_reconciliation_engine': {'name': 'Financial Reconciliation', 'category': 'Finance', 'tier': 'enterprise'},
  'cloud_backup': {'name': 'Cloud Backup', 'category': 'Data', 'tier': 'enterprise'},
  'hierarchical_role_control': {'name': 'Hierarchical Role Control', 'category': 'Security', 'tier': 'enterprise'},
  
  // Business Type Specific
  'restaurant_kot': {'name': 'Restaurant KOT', 'category': 'Vertical', 'tier': 'pro'},
  'restaurant_table_management': {'name': 'Table Management', 'category': 'Vertical', 'tier': 'pro'},
  'fuel_pos_petrol_pump': {'name': 'Fuel POS (Petrol Pump)', 'category': 'Vertical', 'tier': 'pro'},
  'clinic_appointment_system': {'name': 'Clinic Appointment System', 'category': 'Vertical', 'tier': 'premium'},
  'clinic_prescription': {'name': 'Prescription Management', 'category': 'Vertical', 'tier': 'premium'},
  'salon_appointment_booking': {'name': 'Salon Appointment Booking', 'category': 'Vertical', 'tier': 'pro'},
  'hotel_checkin_checkout': {'name': 'Hotel Check-in/Check-out', 'category': 'Vertical', 'tier': 'premium'},
  
  // Integrations
  'whatsapp_integration': {'name': 'WhatsApp Integration', 'category': 'Integration', 'tier': 'premium'},
  'sms_gateway': {'name': 'SMS Gateway', 'category': 'Integration', 'tier': 'premium'},
  'email_marketing': {'name': 'Email Marketing', 'category': 'Integration', 'tier': 'enterprise'},
  'ecommerce_sync': {'name': 'E-commerce Sync', 'category': 'Integration', 'tier': 'enterprise'},
  
  // Advanced
  'custom_workflows': {'name': 'Custom Workflows', 'category': 'Advanced', 'tier': 'enterprise'},
  'ai_demand_forecasting': {'name': 'AI Demand Forecasting', 'category': 'Advanced', 'tier': 'enterprise'},
  'white_label': {'name': 'White Label', 'category': 'Advanced', 'tier': 'enterprise'},
  'dedicated_support': {'name': 'Dedicated Support', 'category': 'Support', 'tier': 'enterprise'},
};

class LicenseFeatureOverrideScreen extends ConsumerStatefulWidget {
  final String licenseKey;
  final String tenantId;
  final String currentPlan;

  const LicenseFeatureOverrideScreen({
    super.key,
    required this.licenseKey,
    required this.tenantId,
    required this.currentPlan,
  });

  @override
  ConsumerState<LicenseFeatureOverrideScreen> createState() => _LicenseFeatureOverrideScreenState();
}

class _LicenseFeatureOverrideScreenState extends ConsumerState<LicenseFeatureOverrideScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _licenseData = {};
  List<String> _currentOverridesAdded = [];
  List<String> _currentOverridesRemoved = [];
  final Set<String> _selectedFeatures = {};
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadLicenseData();
  }

  Future<void> _loadLicenseData() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/license/${widget.licenseKey}'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] ?? {};
        setState(() {
          _licenseData = data;
          _currentOverridesAdded = List<String>.from(data['manualOverrides']?['added'] ?? []);
          _currentOverridesRemoved = List<String>.from(data['manualOverrides']?['removed'] ?? []);
          _selectedFeatures.addAll(_currentOverridesAdded);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading license: $e')),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _saveOverrides() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required for audit trail')),
      );
      return;
    }

    setState(() => _saving = true);
    
    try {
      // Calculate delta
      final toAdd = _selectedFeatures.where((f) => !_currentOverridesAdded.contains(f)).toList();
      final toRemove = _currentOverridesAdded.where((f) => !_selectedFeatures.contains(f)).toList();

      if (toAdd.isEmpty && toRemove.isEmpty) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save')),
        );
        return;
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/license/${widget.licenseKey}/features'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.adminToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'add': toAdd,
          'remove': toRemove,
          'reason': _reasonCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        setState(() {
          _currentOverridesAdded = List<String>.from(result['manualOverrides']?['added'] ?? []);
          _currentOverridesRemoved = List<String>.from(result['manualOverrides']?['removed'] ?? []);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Overrides saved: +${toAdd.length} / -${toRemove.length}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final err = jsonDecode(res.body)['message'] ?? 'Failed to save';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    
    setState(() => _saving = false);
  }

  Future<void> _exportToCsv() async {
    try {
      final csv = StringBuffer();
      csv.writeln('Feature Key,Feature Name,Category,Plan Tier,Status,Override Type');
      
      for (final entry in _allFeatures.entries) {
        final key = entry.key;
        final info = entry.value;
        String status = 'Default';
        String overrideType = '';
        
        if (_currentOverridesAdded.contains(key)) {
          status = 'Enabled (Override)';
          overrideType = 'Added';
        } else if (_currentOverridesRemoved.contains(key)) {
          status = 'Disabled (Override)';
          overrideType = 'Removed';
        }
        
        csv.writeln('$key,"${info['name']}",${info['category']},${info['tier']},$status,$overrideType');
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/license_overrides_${widget.licenseKey.substring(0, 8)}.csv');
      await file.writeAsString(csv.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'License Feature Overrides - ${widget.licenseKey.substring(0, 8)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> get _filteredFeatures {
    return _allFeatures.entries.where((entry) {
      final matchesSearch = _searchQuery.isEmpty ||
          entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.value['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _categoryFilter == 'All' || entry.value['category'] == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._allFeatures.values.map((v) => v['category']).toSet().cast<String>()];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Feature Overrides'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
            tooltip: 'Export to CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLicenseData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(widget.currentPlan.toUpperCase()),
                            backgroundColor: _planColor(widget.currentPlan),
                          ),
                          const Spacer(),
                          Text(
                            'License: ${widget.licenseKey.substring(0, 12)}...',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${_selectedFeatures.length} features',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manually added: ${_currentOverridesAdded.length} | Removed: ${_currentOverridesRemoved.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                // Search & Filter
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search features...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _categoryFilter,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _categoryFilter = v ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reason Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Reason for override (required)...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Feature Grid
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredFeatures.length,
                    itemBuilder: (context, index) {
                      final entry = _filteredFeatures[index];
                      final key = entry.key;
                      final info = entry.value;
                      final isSelected = _selectedFeatures.contains(key);
                      final isOverridden = _currentOverridesAdded.contains(key) || 
                                          _currentOverridesRemoved.contains(key);
                      
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Text(info['name']),
                            if (isOverridden)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OVERRIDE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Chip(
                              label: Text(info['category'], style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.grey.shade200,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              info['tier'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _tierColor(info['tier']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedFeatures.add(key);
                            } else {
                              _selectedFeatures.remove(key);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                
                // Save Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveOverrides,
                      icon: _saving 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Overrides'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _planColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'basic':
        return Colors.grey.shade300;
      case 'pro':
        return Colors.blue.shade100;
      case 'premium':
        return Colors.orange.shade100;
      case 'enterprise':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'basic':
        return Colors.grey;
      case 'pro':
        return Colors.blue;
      case 'premium':
        return Colors.orange;
      case 'enterprise':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}
