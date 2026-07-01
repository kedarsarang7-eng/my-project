// ============================================================================
// Computer Shop — Job Card List Screen
// ============================================================================
// Modern, responsive design with real-time API integration
// Features: Search, filter by status, infinite scroll, pull-to-refresh
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/computer_repository.dart';
import '../../providers/computer_job_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class JobCardListScreen extends ConsumerStatefulWidget {
  const JobCardListScreen({super.key});

  @override
  ConsumerState<JobCardListScreen> createState() => _JobCardListScreenState();
}

class _JobCardListScreenState extends ConsumerState<JobCardListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(jobCardListProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(jobCardListProvider.notifier).loadJobs();
      }
    }
  }

  List<ComputerJobCard> _filterJobs(List<ComputerJobCard> jobs) {
    if (_searchQuery.isEmpty) return jobs;
    return jobs.where((job) {
      final query = _searchQuery.toLowerCase();
      return job.deviceBrand.toLowerCase().contains(query) ||
          job.deviceModel.toLowerCase().contains(query) ||
          job.serialNumber?.toLowerCase().contains(query) == true ||
          job.reportedIssue.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobCardListProvider);
    final statusOptions = ref.watch(jobStatusOptionsProvider);
    final filteredJobs = _filterJobs(jobState.jobs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Job Cards',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20, // PRESERVED: Desktop uses exactly 20 as before
                ),
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'Computer Shop',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(jobCardListProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // Search and Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by brand, model, serial, issue...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: statusOptions.map((option) {
                        final isSelected = _selectedStatus == option['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(option['label']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = selected
                                    ? option['value'] as String?
                                    : null;
                              });
                              ref
                                  .read(jobCardListProvider.notifier)
                                  .setStatusFilter(_selectedStatus);
                            },
                            selectedColor: (option['color'] as Color)
                                .withOpacity(0.1),
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? option['color'] as Color
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? option['color'] as Color
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Job Cards List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(jobCardListProvider.notifier).refresh(),
                child: jobState.isLoading && jobState.jobs.isEmpty
                    ? const _LoadingState()
                    : jobState.error != null && jobState.jobs.isEmpty
                    ? _ErrorState(
                        error: jobState.error!,
                        onRetry: () =>
                            ref.read(jobCardListProvider.notifier).refresh(),
                      )
                    : filteredJobs.isEmpty
                    ? _EmptyState(
                        hasFilter:
                            _searchQuery.isNotEmpty || _selectedStatus != null,
                        onClearFilter: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                            _selectedStatus = null;
                          });
                          ref
                              .read(jobCardListProvider.notifier)
                              .setStatusFilter(null);
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            filteredJobs.length + (jobState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= filteredJobs.length) {
                            return const _LoadMoreIndicator();
                          }
                          final job = filteredJobs[index];
                          return _JobCardTile(
                            job: job,
                            onTap: () => _navigateToDetail(job),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(),
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  void _navigateToDetail(ComputerJobCard job) {
    context.push('/computer-shop/job-card-detail', extra: {'jobId': job.id});
  }

  void _navigateToCreate() {
    context.push('/computer-shop/create-job-card');
  }
}

// ============================================================================
// Job Card Tile Widget
// ============================================================================

class _JobCardTile extends StatelessWidget {
  final ComputerJobCard job;
  final VoidCallback onTap;

  const _JobCardTile({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(job.status);
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Device Info + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.computer, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Device Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job.deviceBrand} ${job.deviceModel}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (job.serialNumber != null)
                          Text(
                            'S/N: ${job.serialNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(job.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Issue Description
              Text(
                job.reportedIssue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              // Footer: Technician + Costs + Date
              Row(
                children: [
                  // Technician
                  if (job.technicianName != null)
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  if (job.technicianName != null) const SizedBox(width: 4),
                  if (job.technicianName != null)
                    Expanded(
                      child: Text(
                        job.technicianName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Costs
                  if (job.actualLaborCost != null ||
                      job.actualPartsCost != null)
                    Text(
                      currencyFormat.format(
                        (job.actualLaborCost ?? 0) + (job.actualPartsCost ?? 0),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Date
                  Text(
                    DateFormat('dd MMM yyyy').format(job.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'INTAKE':
        return Colors.orange;
      case 'DIAGNOSIS':
        return Colors.amber;
      case 'AWAITING_PARTS':
        return Colors.deepOrange;
      case 'REPAIRING':
        return Colors.blue;
      case 'QC':
        return Colors.purple;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'INTAKE':
        return 'Intake';
      case 'DIAGNOSIS':
        return 'Diagnosis';
      case 'AWAITING_PARTS':
        return 'Awaiting Parts';
      case 'REPAIRING':
        return 'Repairing';
      case 'QC':
        return 'QC';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
    }
  }
}

// ============================================================================
// Loading, Error, and Empty States
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading job cards...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Failed to load job cards',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClearFilter;

  const _EmptyState({required this.hasFilter, required this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.filter_list_off : Icons.computer,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No jobs match your filters' : 'No job cards yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try adjusting your search or filters'
                  : 'Create your first service job card to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            if (hasFilter)
              OutlinedButton.icon(
                onPressed: onClearFilter,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push('/computer-shop/create-job-card'),
                icon: const Icon(Icons.add),
                label: const Text('Create Job Card'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
