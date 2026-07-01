// ============================================================================
// Audit Viewer Screen — Unified Audit Log with Filters + CSV Export
// ============================================================================
// Super Admin can query and view all audit logs with filters:
//   - Tenant, Actor, Category, Action, Time Range, Result
//   - CSV export for compliance reporting
//   - Real-time pagination
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/api_config.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AuditViewerScreen extends ConsumerStatefulWidget {
  const AuditViewerScreen({super.key});

  @override
  ConsumerState<AuditViewerScreen> createState() => _AuditViewerScreenState();
}

class _AuditViewerScreenState extends ConsumerState<AuditViewerScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _logs = [];
  String? _nextCursor;
  bool _hasMore = false;
  
  // Filters
  final TextEditingController _tenantIdCtrl = TextEditingController();
  final TextEditingController _actorIdCtrl = TextEditingController();
  String? _selectedCategory;
  String? _selectedResult;
  DateTime? _startDate;
  DateTime? _endDate;
  int _limit = 100;

  final List<String> _categories = [
    'plan_change',
    'license_change',
    'feature_override',
    'security',
    'billing',
    'system',
  ];

  final List<String> _results = ['success', 'failure', 'partial'];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs({bool append = false}) async {
    setState(() => _loading = true);
    
    try {
      final queryParams = <String, String>{
        'limit': _limit.toString(),
        if (!append && _nextCursor != null) 'cursor': _nextCursor!,
        if (append && _nextCursor != null) 'cursor': _nextCursor!,
        if (_tenantIdCtrl.text.isNotEmpty) 'tenantId': _tenantIdCtrl.text,
        if (_actorIdCtrl.text.isNotEmpty) 'actorId': _actorIdCtrl.text,
        'category': ?_selectedCategory,
        'result': ?_selectedResult,
        if (_startDate != null) 'startTime': _startDate!.toIso8601String(),
        if (_endDate != null) 'endTime': _endDate!.toIso8601String(),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/admin/audit')
          .replace(queryParameters: queryParams);

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final logs = List<Map<String, dynamic>>.from(data['data'] ?? []);
        final pagination = data['pagination'] ?? {};
        
        setState(() {
          if (append) {
            _logs.addAll(logs);
          } else {
            _logs = logs;
          }
          _nextCursor = pagination['nextCursor'];
          _hasMore = pagination['hasMore'] ?? false;
        });
      } else {
        final err = jsonDecode(res.body)['message'] ?? 'Failed to load logs';
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
    
    setState(() => _loading = false);
  }

  Future<void> _exportToCsv() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export')),
      );
      return;
    }

    try {
      final csv = StringBuffer();
      csv.writeln('Timestamp,ID,Actor,Actor Type,Action,Category,Target,Target Type,Result,Tenant ID,Metadata');
      
      for (final log in _logs) {
        final actor = log['actor'] ?? {};
        final target = log['target'] ?? {};
        final metadata = jsonEncode(log['metadata'] ?? {}).replaceAll('"', '""');
        
        csv.writeln(
          '${log['timestamp']},'
          '${log['id']},'
          '${actor['id'] ?? ''},'
          '${actor['type'] ?? ''},'
          '${log['action'] ?? ''},'
          '${log['category'] ?? ''},'
          '${target['id'] ?? ''},'
          '${target['type'] ?? ''},'
          '${log['result'] ?? ''},'
          '${log['tenantId'] ?? ''},'
          '"$metadata"'
        );
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/audit_logs_$timestamp.csv');
      await file.writeAsString(csv.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Audit Logs Export - $timestamp',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _loadSummary() async {
    try {
      final days = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Period'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Last 7 days'),
                onTap: () => Navigator.pop(context, 7),
              ),
              ListTile(
                title: const Text('Last 14 days'),
                onTap: () => Navigator.pop(context, 14),
              ),
              ListTile(
                title: const Text('Last 30 days'),
                onTap: () => Navigator.pop(context, 30),
              ),
            ],
          ),
        ),
      );

      if (days == null) return;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/audit/summary?days=$days'),
        headers: {'Authorization': 'Bearer ${ApiConfig.adminToken}'},
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        _showSummaryDialog(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showSummaryDialog(Map<String, dynamic> data) {
    final counts = data['categoryCounts'] ?? {};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period: ${data['period']?['days'] ?? '?'} days'),
            const Divider(),
            ...counts.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.toString().replaceAll('_', ' ').toUpperCase()),
                  Text(
                    e.value.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _tenantIdCtrl.clear();
      _actorIdCtrl.clear();
      _selectedCategory = null;
      _selectedResult = null;
      _startDate = null;
      _endDate = null;
      _nextCursor = null;
    });
    _loadAuditLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: _loadSummary,
            tooltip: 'Summary',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAuditLogs(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Filter Panel
          ExpansionTile(
            title: const Text('Filters'),
            subtitle: Text(
              _activeFilterCount > 0 ? '$_activeFilterCount active' : 'Tap to filter',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tenant & Actor
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tenantIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tenant ID',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _actorIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Actor ID',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Category & Result
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All')),
                              ..._categories.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.replaceAll('_', ' ').toUpperCase()),
                              )),
                            ],
                            onChanged: (v) => setState(() => _selectedCategory = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedResult,
                            decoration: const InputDecoration(
                              labelText: 'Result',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All')),
                              ..._results.map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.toUpperCase()),
                              )),
                            ],
                            onChanged: (v) => setState(() => _selectedResult = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Date Range
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _startDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _startDate != null
                                    ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                    : 'Select',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _endDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _endDate != null
                                    ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                    : 'Select',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _loadAuditLogs(),
                            icon: const Icon(Icons.search),
                            label: const Text('Apply Filters'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_logs.length} records',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_hasMore)
                  TextButton(
                    onPressed: _loading ? null : () => _loadAuditLogs(append: true),
                    child: _loading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Load more'),
                  ),
              ],
            ),
          ),
          
          // Audit Log List
          Expanded(
            child: _logs.isEmpty && !_loading
                ? const Center(child: Text('No audit logs found'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final actor = log['actor'] ?? {};
                      final target = log['target'] ?? {};
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: _buildResultIcon(log['result']),
                          title: Row(
                            children: [
                              Text(
                                log['action']?.toString().toUpperCase() ?? 'UNKNOWN',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  log['category']?.toString() ?? 'unknown',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _categoryColor(log['category']),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${actor['type'] ?? 'unknown'}: ${actor['id']?.toString().substring(0, 8) ?? 'unknown'} → '
                                '${target['type'] ?? 'unknown'}: ${target['id']?.toString().substring(0, 8) ?? 'unknown'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (log['tenantId'] != null)
                                Text(
                                  'Tenant: ${log['tenantId'].toString().substring(0, 12)}...',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              Text(
                                _formatTimestamp(log['timestamp']),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          onTap: () => _showLogDetails(log),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildResultIcon(String? result) {
    switch (result) {
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'failure':
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case 'partial':
        return const Icon(Icons.warning, color: Colors.orange, size: 20);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 20);
    }
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'plan_change':
        return Colors.blue.shade100;
      case 'license_change':
        return Colors.green.shade100;
      case 'feature_override':
        return Colors.orange.shade100;
      case 'security':
        return Colors.red.shade100;
      case 'billing':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal());
    } catch (_) {
      return timestamp;
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_tenantIdCtrl.text.isNotEmpty) count++;
    if (_actorIdCtrl.text.isNotEmpty) count++;
    if (_selectedCategory != null) count++;
    if (_selectedResult != null) count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    return count;
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log['action']?.toString().toUpperCase() ?? 'Unknown Action'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', log['id']),
              _buildDetailRow('Timestamp', log['timestamp']),
              _buildDetailRow('Category', log['category']),
              _buildDetailRow('Result', log['result']),
              const Divider(),
              const Text('Actor:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('  ID', log['actor']?['id']),
              _buildDetailRow('  Type', log['actor']?['type']),
              _buildDetailRow('  Role', log['actor']?['role']),
              const Divider(),
              const Text('Target:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('  ID', log['target']?['id']),
              _buildDetailRow('  Type', log['target']?['type']),
              _buildDetailRow('  Name', log['target']?['name']),
              if (log['tenantId'] != null) ...[
                const Divider(),
                _buildDetailRow('Tenant ID', log['tenantId']),
              ],
              if (log['metadata'] != null) ...[
                const Divider(),
                const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  const JsonEncoder.withIndent('  ').convert(log['metadata']),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tenantIdCtrl.dispose();
    _actorIdCtrl.dispose();
    super.dispose();
  }
}
