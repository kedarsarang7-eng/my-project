// ============================================================================
// Plan Override Screen — Super Admin Mobile Panel
// ============================================================================
// Override a tenant's plan, extend expiry, grant feature overrides.
// All changes logged to audit trail with IP + reason.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PlanOverrideScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final String tenantName;
  final String currentPlan;

  const PlanOverrideScreen({
    super.key,
    required this.tenantId,
    required this.tenantName,
    required this.currentPlan,
  });

  @override
  ConsumerState<PlanOverrideScreen> createState() => _PlanOverrideScreenState();
}

class _PlanOverrideScreenState extends ConsumerState<PlanOverrideScreen> {
  late String _selectedPlan;
  final _reasonCtrl = TextEditingController();
  final _extraDaysCtrl = TextEditingController(text: '0');
  bool _superAdminOverride = false;
  bool _saving = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.currentPlan;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/plan-history/${widget.tenantId}'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _history = List<Map<String, dynamic>>.from(data['data'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _savePlanChange() async {
    if (_reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required for audit trail')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/plan-override'),
        headers: {
          'Authorization': 'Bearer ${ApiConfig.adminToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'tenantId': widget.tenantId,
          'newPlan': _selectedPlan,
          'reason': _reasonCtrl.text,
          'extraDays': int.tryParse(_extraDaysCtrl.text) ?? 0,
          'superAdminOverride': _superAdminOverride,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan updated successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(res.body)['message'] ?? 'Failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plan Override: ${widget.tenantName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Plan
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Current Plan'),
              trailing: Chip(label: Text(widget.currentPlan.toUpperCase())),
            ),
          ),
          const SizedBox(height: 16),

          // New Plan Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPlan,
                    items: ['basic', 'pro', 'premium', 'enterprise']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPlan = v ?? _selectedPlan),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Extend Expiry
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Extend Expiry (days)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0 = no change',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Super Admin Override Toggle
          Card(
            child: SwitchListTile(
              title: const Text('Super Admin Override'),
              subtitle: const Text('Bypass all plan/feature checks for this tenant'),
              value: _superAdminOverride,
              onChanged: (v) => setState(() => _superAdminOverride = v),
              activeColor: Colors.red,
            ),
          ),
          const SizedBox(height: 12),

          // Reason (required)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reason (required for audit)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Why is this change being made?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          ElevatedButton.icon(
            onPressed: _saving ? null : _savePlanChange,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Apply Plan Change'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),

          const SizedBox(height: 24),

          // Change History
          const Text('Change History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Text('No plan changes recorded', style: TextStyle(color: Colors.grey))
          else
            ..._history.map((h) => Card(
              child: ListTile(
                dense: true,
                title: Text('${h['previous_plan']} → ${h['new_plan']}'),
                subtitle: Text('${h['change_reason'] ?? ''}\n${h['created_at'] ?? ''}'),
                trailing: Chip(
                  label: Text(h['change_type'] ?? '', style: const TextStyle(fontSize: 10)),
                  backgroundColor: h['change_type'] == 'upgrade' ? Colors.green.shade50 : Colors.orange.shade50,
                ),
              ),
            )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _extraDaysCtrl.dispose();
    super.dispose();
  }
}
