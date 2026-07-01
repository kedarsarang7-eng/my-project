import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ac_repository.dart';
import '../../data/providers/ac_providers.dart';
import '../widgets/ac_screen_wrapper.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Admissions Portal Screen
/// Manages online admission applications and workflow
class AcAdmissionsScreen extends ConsumerStatefulWidget {
  const AcAdmissionsScreen({super.key});

  @override
  ConsumerState<AcAdmissionsScreen> createState() => _AcAdmissionsScreenState();
}

class _AcAdmissionsScreenState extends ConsumerState<AcAdmissionsScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(acRepositoryProvider);
      final data = await repo.getAdmissionsApplications(
        status: _selectedFilter,
      );
      setState(() {
        _applications = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading applications: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return AcScreenWrapper(
      title: 'Admissions Portal',
      actions: [
        FilledButton.icon(
          onPressed: () => _showApplicationForm(context),
          icon: const Icon(Icons.add),
          label: isMobile ? const Text('New') : const Text('New Application'),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadApplications,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      child: Column(
        children: [
          // Filters and Search
          _buildFilters(isMobile),
          const SizedBox(height: 16),
          // Stats Cards
          _buildStatsCards(isMobile),
          const SizedBox(height: 16),
          // Applications List
          Expanded(child: _buildApplicationsTable()),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    final segmentedButton = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'all', label: Text('All')),
        ButtonSegment(value: 'pending', label: Text('Pending')),
        ButtonSegment(value: 'under_review', label: Text('Review')),
        ButtonSegment(value: 'admitted', label: Text('Admitted')),
        ButtonSegment(value: 'rejected', label: Text('Rejected')),
      ],
      selected: {_selectedFilter},
      onSelectionChanged: (set) {
        setState(() => _selectedFilter = set.first);
        _loadApplications();
      },
    );

    final searchField = TextField(
      decoration: const InputDecoration(
        hintText: 'Search by name, phone...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: segmentedButton,
                  ),
                  const SizedBox(height: 16),
                  searchField,
                ],
              )
            : Row(
                children: [
                  segmentedButton,
                  const SizedBox(width: 16),
                  Expanded(child: searchField),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final stats = {
      'Total Applications': _applications.length,
      'Pending Review': _applications
          .where((a) => a['status'] == 'pending')
          .length,
      'Admitted': _applications.where((a) => a['status'] == 'admitted').length,
      'Rejected': _applications.where((a) => a['status'] == 'rejected').length,
    };

    final statsWidgets = stats.entries
        .map(
          (entry) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.value.toString(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();

    return isMobile
        ? GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: statsWidgets,
          )
        : Row(children: statsWidgets.map((w) => Expanded(child: w)).toList());
  }

  Widget _buildApplicationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_applications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No applications found'),
          ],
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Application ID')),
              DataColumn(label: Text('Student Name')),
              DataColumn(label: Text('Applied For')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Applied Date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _applications
                .where((app) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  return (app['firstName']?.toString().toLowerCase().contains(
                            query,
                          ) ??
                          false) ||
                      (app['lastName']?.toString().toLowerCase().contains(
                            query,
                          ) ??
                          false) ||
                      (app['phone']?.toString().contains(query) ?? false) ||
                      (app['id']?.toString().toLowerCase().contains(query) ??
                          false);
                })
                .map(
                  (app) => DataRow(
                    cells: [
                      DataCell(
                        Text(app['applicationNumber'] ?? app['id'] ?? 'N/A'),
                      ),
                      DataCell(
                        Text(
                          '${app['firstName'] ?? ''} ${app['lastName'] ?? ''}',
                        ),
                      ),
                      DataCell(Text(app['applyingForClass'] ?? 'N/A')),
                      DataCell(Text(app['phone'] ?? 'N/A')),
                      DataCell(_buildStatusChip(app['status'])),
                      DataCell(
                        Text(
                          app['createdAt']?.toString().split('T').first ??
                              'N/A',
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _viewApplication(app),
                              tooltip: 'View',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editStatus(app),
                              tooltip: 'Update Status',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final colors = {
      'submitted': Colors.blue,
      'under_review': Colors.orange,
      'documents_pending': Colors.amber,
      'shortlisted': Colors.teal,
      'interview_scheduled': Colors.purple,
      'admitted': Colors.green,
      'rejected': Colors.red,
      'waitlisted': Colors.grey,
    };

    return Chip(
      label: Text(
        (status ?? 'unknown').replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: colors[status] ?? Colors.grey,
      padding: EdgeInsets.zero,
    );
  }

  void _showApplicationForm(BuildContext context) {
    // Navigate to application form
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Admission Application'),
        content: const Text('Application form would open here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _viewApplication(Map<String, dynamic> app) {
    // Show application details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Application ${app['applicationNumber'] ?? app['id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${app['firstName']} ${app['lastName']}'),
              Text('Phone: ${app['phone']}'),
              Text('Email: ${app['email'] ?? 'N/A'}'),
              Text('Status: ${app['status']}'),
              Text('Applied: ${app['createdAt']}'),
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

  void _editStatus(Map<String, dynamic> app) {
    // Update status workflow
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Application Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select new status:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        'under_review',
                        'documents_pending',
                        'shortlisted',
                        'interview_scheduled',
                        'admitted',
                        'rejected',
                        'waitlisted',
                      ]
                      .map(
                        (status) => ActionChip(
                          label: Text(status.replaceAll('_', ' ')),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateApplicationStatus(app['id'], status);
                          },
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateApplicationStatus(String id, String status) async {
    try {
      final repo = ref.read(acRepositoryProvider);
      await repo.updateApplicationStatus(id, status: status);
      _loadApplications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }
}
