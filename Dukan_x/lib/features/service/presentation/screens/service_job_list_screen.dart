/// Service Job List Screen
/// Shows all service/repair jobs with filtering and status overview
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/service_job.dart';
import '../../services/service_job_service.dart';
import 'create_service_job_screen.dart';
import 'service_job_detail_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ServiceJobListScreen extends StatefulWidget {
  const ServiceJobListScreen({super.key});

  @override
  State<ServiceJobListScreen> createState() => _ServiceJobListScreenState();
}

class _ServiceJobListScreenState extends State<ServiceJobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ServiceJobService _service;
  String? _userId;
  ServiceJobStatus? _filterStatus;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: sl<CurrencyService>().symbol,
  );
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service = ServiceJobService(AppDatabase.instance);
    _loadUser();
  }

  String? _sessionError;
  bool _isLoadingUser = true;

  Future<void> _loadUser() async {
    final userId = sl<SessionManager>().userId;
    if (!mounted) return;

    if (userId != null) {
      setState(() {
        _userId = userId;
        _isLoadingUser = false;
        _sessionError = null;
      });
      return;
    }

    // Identity is null immediately — show error and start a 10-second timeout
    setState(() {
      _isLoadingUser = false;
      _sessionError = 'Invalid or expired session. Please log in again.';
    });

    // Allow up to 10 seconds for the session to resolve
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      final retryUserId = sl<SessionManager>().userId;
      if (retryUserId != null) {
        setState(() {
          _userId = retryUserId;
          _sessionError = null;
        });
      } else if (_userId == null) {
        setState(() {
          _sessionError = 'Session could not be resolved. Please try again.';
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Jobs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by job #, customer, or device...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _debounceTimer?.cancel();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  _debounceTimer?.cancel();
                  if (value.isEmpty) {
                    // Clear immediately so the full list shows within 300ms
                    setState(() => _searchQuery = '');
                  } else {
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (mounted) {
                          setState(() => _searchQuery = value);
                        }
                      },
                    );
                  }
                },
              ),
            ),

            // Status overview cards
            if (_userId != null)
              SizedBox(
                height: 100,
                child: FutureBuilder<Map<ServiceJobStatus, int>>(
                  future: _service.getJobCounts(_userId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final counts = snapshot.data!;
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildStatusCard(
                          'Received',
                          counts[ServiceJobStatus.received] ?? 0,
                          FuturisticColors.info,
                          Icons.inbox,
                        ),
                        _buildStatusCard(
                          'In Progress',
                          counts[ServiceJobStatus.inProgress] ?? 0,
                          FuturisticColors.warning,
                          Icons.build,
                        ),
                        _buildStatusCard(
                          'Ready',
                          counts[ServiceJobStatus.ready] ?? 0,
                          FuturisticColors.success,
                          Icons.check_circle,
                        ),
                        _buildStatusCard(
                          'Waiting Parts',
                          counts[ServiceJobStatus.waitingParts] ?? 0,
                          FuturisticColors.accent2,
                          Icons.hourglass_empty,
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Job list
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildJobList(activeOnly: true),
                  _buildJobList(completedOnly: true),
                  _buildJobList(),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Semantics(
      label: '$label: $count jobs',
      child: Tooltip(
        message: '$label: $count jobs',
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: InkWell(
            onTap: () {
              // Filter by this status
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: FuturisticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobList({bool activeOnly = false, bool completedOnly = false}) {
    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessionError != null || _userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: FuturisticColors.error.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                _sessionError ??
                    'Invalid or expired session. Please log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: FuturisticColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoadingUser = true;
                    _sessionError = null;
                  });
                  _loadUser();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<ServiceJob>>(
      stream: activeOnly
          ? _service.watchActiveJobs(_userId!)
          : _service.watchAllJobs(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 64,
                  color: FuturisticColors.textDisabled,
                ),
                const SizedBox(height: 16),
                Text(
                  'No service jobs yet',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    color: FuturisticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create a new job',
                  style: TextStyle(color: FuturisticColors.textDisabled),
                ),
              ],
            ),
          );
        }

        var jobs = snapshot.data!;

        // Filter by completed status
        if (completedOnly) {
          jobs = jobs
              .where(
                (j) =>
                    j.status == ServiceJobStatus.delivered ||
                    j.status == ServiceJobStatus.cancelled,
              )
              .toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          jobs = jobs.where((j) {
            return j.jobNumber.toLowerCase().contains(query) ||
                j.customerName.toLowerCase().contains(query) ||
                j.customerPhone.contains(query) ||
                j.brand.toLowerCase().contains(query) ||
                j.model.toLowerCase().contains(query) ||
                (j.imeiOrSerial?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        // Filter by status
        if (_filterStatus != null) {
          jobs = jobs.where((j) => j.status == _filterStatus).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _buildJobCard(jobs[index]),
        );
      },
    );
  }

  Widget _buildJobCard(ServiceJob job) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(job.status);
    final isOverdue =
        job.expectedDelivery != null &&
        job.expectedDelivery!.isBefore(DateTime.now()) &&
        job.isActive;

    return Semantics(
      label:
          'Service job ${job.jobNumber} for ${job.customerName}, '
          '${job.brand} ${job.model}, status: ${job.status.displayName}',
      child: Tooltip(
        message:
            '${job.jobNumber} – ${job.customerName} (${job.status.displayName})',
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            onTap: () => _navigateToDetail(context, job),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Job number
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          job.jobNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          job.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (job.priority == ServicePriority.urgent) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.priority_high,
                          color: FuturisticColors.error,
                          size: 20,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Customer info
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: FuturisticColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Device info
                  Row(
                    children: [
                      Icon(
                        _getDeviceIcon(job.deviceType),
                        size: 18,
                        color: FuturisticColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${job.brand} ${job.model}',
                          style: TextStyle(
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Problem preview
                  Text(
                    job.problemDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FuturisticColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Footer row
                  Row(
                    children: [
                      // Received date
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: FuturisticColors.textDisabled,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dateFormat.format(job.receivedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: FuturisticColors.textDisabled,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Expected delivery
                      if (job.expectedDelivery != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isOverdue
                              ? FuturisticColors.error
                              : FuturisticColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dateFormat.format(job.expectedDelivery!),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? FuturisticColors.error
                                : FuturisticColors.textDisabled,
                            fontWeight: isOverdue ? FontWeight.bold : null,
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Amount
                      if (job.grandTotal > 0)
                        Text(
                          _currencyFormat.format(job.grandTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                      // Warranty badge
                      if (job.isUnderWarranty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: FuturisticColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: FuturisticColors.success.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'WARRANTY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: FuturisticColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ServiceJobStatus status) {
    switch (status) {
      case ServiceJobStatus.received:
        return FuturisticColors.info;
      case ServiceJobStatus.diagnosed:
        return FuturisticColors.accent2;
      case ServiceJobStatus.waitingApproval:
        return FuturisticColors.warning;
      case ServiceJobStatus.approved:
        return FuturisticColors.accent1;
      case ServiceJobStatus.waitingParts:
        return FuturisticColors.accent2;
      case ServiceJobStatus.inProgress:
        return FuturisticColors.warning;
      case ServiceJobStatus.completed:
        return FuturisticColors.success;
      case ServiceJobStatus.ready:
        return FuturisticColors.success;
      case ServiceJobStatus.delivered:
        return FuturisticColors.textSecondary;
      case ServiceJobStatus.cancelled:
        return FuturisticColors.error;
    }
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.mobile:
        return Icons.phone_android;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.desktop:
        return Icons.desktop_windows;
      case DeviceType.tablet:
        return Icons.tablet;
      case DeviceType.other:
        return Icons.devices;
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 14.0,
                  tablet: 16.0,
                  desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == null,
                  onSelected: (_) {
                    setState(() => _filterStatus = null);
                    Navigator.pop(context);
                  },
                ),
                ...ServiceJobStatus.values.map(
                  (status) => FilterChip(
                    label: Text(status.displayName),
                    selected: _filterStatus == status,
                    onSelected: (_) {
                      setState(() => _filterStatus = status);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateServiceJobScreen()),
    );
  }

  void _navigateToDetail(BuildContext context, ServiceJob job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ServiceJobDetailScreen(job: job)),
    );
  }
}
