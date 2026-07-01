// Auto Parts - Job Card Management Screen
// Real API integration with action panel for Edit/View/Delete

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../data/models/job_card_model.dart';
import '../../data/repositories/auto_parts_repository.dart';

class JobCardManagementScreen extends StatefulWidget {
  const JobCardManagementScreen({super.key});

  @override
  State<JobCardManagementScreen> createState() =>
      _JobCardManagementScreenState();
}

class _JobCardManagementScreenState extends State<JobCardManagementScreen> {
  // FIX #2: Safe DI — not in field initializer
  late AutoPartsRepository _repository;
  late SessionManager _session;
  bool _diReady = false;
  String? _diError;

  List<JobCard> _jobCards = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter;

  final List<String> _statusOptions = [
    'ALL',
    'INTAKE',
    'DIAGNOSIS',
    'IN_PROGRESS',
    'WAITING_PARTS',
    'QUALITY_CHECK',
    'READY',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    // FIX #2: Catch DI failure gracefully
    try {
      _repository = AutoPartsRepository(sl<ApiClient>());
      _session = sl<SessionManager>();
      _diReady = true;
    } catch (e) {
      _diError = 'Failed to initialize: $e';
      return;
    }
    _loadJobCards();
  }

  Future<void> _loadJobCards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repository.getJobCards(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
      );

      setState(() {
        _jobCards = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load job cards: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onDeleteJobCard(JobCard jobCard) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      entityName: 'Job Card',
      entityIdentifier:
          '${jobCard.jobCardNumber} - ${jobCard.vehicle.registrationNumber}',
      isSoftDelete: true,
    );

    if (!confirmed) return;

    try {
      await _repository.deleteJobCard(jobCard.id);

      setState(() {
        _jobCards.removeWhere((j) => j.id == jobCard.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job card ${jobCard.jobCardNumber} moved to recycle bin',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restoreJobCard(jobCard),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete job card: $e');
    }
  }

  Future<void> _restoreJobCard(JobCard jobCard) async {
    try {
      await _repository.restoreJobCard(jobCard.id);
      _loadJobCards();
    } catch (e) {
      _showError('Failed to restore job card: $e');
    }
  }

  Future<void> _onUpdateStatus(JobCard jobCard, String newStatus) async {
    try {
      await _repository.updateJobCardStatus(jobCard.id, status: newStatus);
      _loadJobCards();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update status: $e');
    }
  }

  // FIX #1: Dialog panels instead of Navigator.push — keeps desktop shell intact
  void _onViewJobCard(JobCard jobCard) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: JobCardDetailScreen(jobCard: jobCard),
      ),
    );
  }

  void _onEditJobCard(JobCard jobCard) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: JobCardEditScreen(jobCard: jobCard),
      ),
    ).then((_) {
      if (mounted) _loadJobCards();
    });
  }

  void _showError(String message) {
    // FIX #3: mounted guard
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'INTAKE':
        return Colors.blue;
      case 'DIAGNOSIS':
        return Colors.purple;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'WAITING_PARTS':
        return Colors.amber;
      case 'QUALITY_CHECK':
        return Colors.teal;
      case 'READY':
        return Colors.green;
      case 'DELIVERED':
        return Colors.indigo;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildAppBar(isDark),
          _buildFilterBar(isDark),
          Expanded(
            child: _error != null
                ? _buildErrorWidget()
                : isDesktop
                ? _buildDesktopView()
                : _buildMobileView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewJobCard(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Job Card',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.build_outlined, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service Job Cards',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_jobCards.length} active jobs',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadJobCards),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusOptions.map((status) {
            final isSelected =
                _statusFilter == status ||
                (status == 'ALL' && _statusFilter == null);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status.replaceAll('_', ' ')),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = status == 'ALL' ? null : status;
                  });
                  _loadJobCards();
                },
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                selectedColor: _getStatusColor(status).withValues(alpha: 0.2),
                checkmarkColor: _getStatusColor(status),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopView() {
    if (!_diReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _diError ?? 'Initialization failed',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
    // FIX #4: Horizontal scroll wrapper + RepaintBoundary
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1200,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: DataTable2(
              columnSpacing: 16,
              horizontalMargin: 16,
              minWidth: 1100,
              columns: const [
                DataColumn2(label: Text('Job Card #'), size: ColumnSize.S),
                DataColumn2(label: Text('Vehicle'), size: ColumnSize.M),
                DataColumn2(label: Text('Customer'), size: ColumnSize.M),
                DataColumn2(label: Text('Issue'), size: ColumnSize.L),
                DataColumn2(label: Text('Status'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Est. Cost'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Actions'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
              ],
              rows: _jobCards.map((job) => _buildJobCardRow(job)).toList(),
              empty: _buildEmptyState(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow2 _buildJobCardRow(JobCard job) {
    return DataRow2(
      cells: [
        DataCell(
          Text(
            job.jobCardNumber,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${job.vehicle.make} ${job.vehicle.model}'),
              Text(
                job.vehicle.registrationNumber,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(job.customerName),
              Text(
                job.customerPhone ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        DataCell(
          Text(job.reportedIssue, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(job.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              job.status.replaceAll('_', ' '),
              style: TextStyle(
                color: _getStatusColor(job.status),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            '₹${job.estimatedCostPaisa.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view':
                  _onViewJobCard(job);
                  break;
                case 'edit':
                  _onEditJobCard(job);
                  break;
                case 'delete':
                  _onDeleteJobCard(job);
                  break;
                default:
                  _onUpdateStatus(job, value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('View Details')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuDivider(),
              ..._getNextStatuses(job.status).map(
                (s) => PopupMenuItem(
                  value: s,
                  child: Text('Mark as ${s.replaceAll('_', ' ')}'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  List<String> _getNextStatuses(String current) {
    final flow = {
      'INTAKE': ['DIAGNOSIS'],
      'DIAGNOSIS': ['IN_PROGRESS'],
      'IN_PROGRESS': ['WAITING_PARTS', 'QUALITY_CHECK'],
      'WAITING_PARTS': ['IN_PROGRESS'],
      'QUALITY_CHECK': ['READY'],
      'READY': ['DELIVERED'],
    };
    return flow[current] ?? [];
  }

  Widget _buildMobileView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _jobCards.length,
      itemBuilder: (context, index) {
        final job = _jobCards[index];
        return _buildJobCardCard(job);
      },
    );
  }

  Widget _buildJobCardCard(JobCard job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(job.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.build, color: _getStatusColor(job.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.jobCardNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${job.vehicle.make} ${job.vehicle.model}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                EntityActionPanel.standard(
                  onView: () => _onViewJobCard(job),
                  onEdit: () => _onEditJobCard(job),
                  onDelete: () => _onDeleteJobCard(job),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Customer', job.customerName),
            _buildInfoRow('Reg. No.', job.vehicle.registrationNumber),
            _buildInfoRow('Issue', job.reportedIssue, maxLines: 2),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Est: ₹${job.estimatedCostPaisa.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (_getNextStatuses(job.status).isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _onUpdateStatus(
                      job,
                      _getNextStatuses(job.status).first,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(
                        _getNextStatuses(job.status).first,
                      ),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Mark ${_getNextStatuses(job.status).first.replaceAll('_', ' ')}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadJobCards, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No job cards found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new job card to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // FIX #5: Stub implemented
  void _createNewJobCard() {
    context.push('/auto-parts/job-cards/create').then((_) {
      if (mounted) _loadJobCards();
    });
  }
}

// FIX #8: Detail/Edit screens sized for Dialog with close button
class JobCardDetailScreen extends StatelessWidget {
  final JobCard jobCard;
  const JobCardDetailScreen({super.key, required this.jobCard});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Job Card ${jobCard.jobCardNumber}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JobDetailRow('Job Card #', jobCard.jobCardNumber),
              _JobDetailRow('Customer', jobCard.customerName),
              _JobDetailRow('Phone', jobCard.customerPhone ?? '—'),
              _JobDetailRow(
                'Vehicle',
                '${jobCard.vehicle.make} ${jobCard.vehicle.model}',
              ),
              _JobDetailRow('Reg. No.', jobCard.vehicle.registrationNumber),
              _JobDetailRow('Issue', jobCard.reportedIssue),
              _JobDetailRow('Status', jobCard.status.replaceAll('_', ' ')),
              _JobDetailRow(
                'Est. Cost',
                '₹${jobCard.estimatedCostPaisa.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _JobDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class JobCardEditScreen extends StatelessWidget {
  final JobCard jobCard;
  const JobCardEditScreen({super.key, required this.jobCard});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Job Card'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Center(
          child: Text(
            'Editing job card ${jobCard.jobCardNumber} — implement fields here',
          ),
        ),
      ),
    );
  }
}
