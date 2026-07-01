// Jewellery Repair Management Screen - Modern Professional UI
// Feature 3: Repair/Service Module

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/rid_generator.dart';
import '../../data/models/jewellery_repair_model.dart';
import '../../data/repositories/jewellery_repair_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class JewelleryRepairScreen extends StatefulWidget {
  const JewelleryRepairScreen({super.key});

  @override
  State<JewelleryRepairScreen> createState() => _JewelleryRepairScreenState();
}

class _JewelleryRepairScreenState extends State<JewelleryRepairScreen> {
  final JewelleryRepairRepository _repository = JewelleryRepairRepository(
    sl(),
    sl<SessionManager>(),
  );

  List<JewelleryRepair> _repairs = [];
  RepairStatistics? _statistics;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all',
    'pending',
    'in_progress',
    'ready',
    'delivered',
    'overdue',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _repository.initialize();

      List<JewelleryRepair> repairs;

      switch (_selectedFilter) {
        case 'pending':
          repairs = await _repository.getRepairs(status: RepairStatus.pending);
          break;
        case 'in_progress':
          repairs = await _repository.getRepairs(
            status: RepairStatus.inProgress,
          );
          break;
        case 'ready':
          repairs = await _repository.getRepairs(status: RepairStatus.ready);
          break;
        case 'delivered':
          repairs = await _repository.getRepairs(
            status: RepairStatus.delivered,
          );
          break;
        case 'overdue':
          repairs = await _repository.getOverdueJobs();
          break;
        default:
          repairs = await _repository.getRepairs(includeCompleted: true);
      }

      final stats = await _repository.getStatistics();

      setState(() {
        _repairs = repairs;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load repairs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewJob() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateRepairJobDialog(),
    );

    if (result == true) {
      await _loadData();
    }
  }

  void _showJobDetails(JewelleryRepair repair) {
    showDialog(
      context: context,
      builder: (context) => RepairJobDetailDialog(repair: repair),
    );
  }

  Future<void> _updateStatus(
    JewelleryRepair repair,
    RepairStatus newStatus,
  ) async {
    try {
      await _repository.updateStatus(repair.id, newStatus);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: newStatus.color,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update status: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorWidget()
            : isDesktop
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewJob,
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NEW JOB', style: TextStyle(color: Colors.white)),
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
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar with stats
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildStatsPanel()),
            ],
          ),
        ),
        // Main content
        Expanded(
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: _repairs.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildStatsCards()),
        SliverToBoxAdapter(child: _buildFilterBar()),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= _repairs.length) return null;
            return _buildMobileCard(_repairs[index]);
          }, childCount: _repairs.length),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFD4AF37).withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repair & Service',
                        style: TextStyle(
                          fontSize: responsiveValue<double>(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 24,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Jewellery repair management',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    if (_statistics == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatItem(
            'Total Jobs',
            _statistics!.totalJobs.toString(),
            Icons.assignment,
            Colors.blue,
          ),
          _buildStatItem(
            'Pending',
            _statistics!.pendingJobs.toString(),
            Icons.pending_actions,
            Colors.orange,
          ),
          _buildStatItem(
            'In Progress',
            _statistics!.inProgressJobs.toString(),
            Icons.engineering,
            Colors.indigo,
          ),
          _buildStatItem(
            'Overdue',
            _statistics!.overdueJobs.toString(),
            Icons.warning,
            Colors.red,
          ),
          _buildStatItem(
            'Completed',
            _statistics!.deliveredJobs.toString(),
            Icons.check_circle,
            Colors.green,
          ),
          const Divider(height: 32),
          _buildRevenueStat(),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          value,
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
      ),
    );
  }

  Widget _buildRevenueStat() {
    if (_statistics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withOpacity(0.2),
            const Color(0xFFD4AF37).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue (This Month)',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_statistics!.displayTotalRevenue.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 24,
              ),
              fontWeight: FontWeight.bold,
              color: const Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profit: ₹${_statistics!.displayNetProfit.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_statistics == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _statistics!.totalJobs.toString(),
                  Icons.assignment,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  _statistics!.pendingJobs.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'In Progress',
                  _statistics!.inProgressJobs.toString(),
                  Icons.engineering,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Overdue',
                  _statistics!.overdueJobs.toString(),
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedFilter = filter);
                  _loadData();
                },
                selectedColor: const Color(0xFFD4AF37),
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.grey[100],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable2(
          columnSpacing: 16,
          horizontalMargin: 16,
          minWidth: 1200,
          columns: const [
            DataColumn2(label: Text('Job #'), size: ColumnSize.S),
            DataColumn2(label: Text('Customer'), size: ColumnSize.M),
            DataColumn2(label: Text('Item'), size: ColumnSize.M),
            DataColumn2(label: Text('Status'), size: ColumnSize.S),
            DataColumn2(label: Text('Priority'), size: ColumnSize.S),
            DataColumn2(label: Text('Days'), size: ColumnSize.S),
            DataColumn2(label: Text('Cost'), size: ColumnSize.S),
            DataColumn2(label: Text('Actions'), size: ColumnSize.S),
          ],
          rows: _repairs.map((repair) => _buildDataRow(repair)).toList(),
          empty: _buildEmptyState(),
        ),
      ),
    );
  }

  DataRow2 _buildDataRow(JewelleryRepair repair) {
    final isOverdue = repair.isOverdue;
    final daysRemaining = repair.daysRemaining;

    return DataRow2(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              repair.jobNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                repair.customerName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (repair.customerPhone != null)
                Text(
                  repair.customerPhone!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                repair.itemDescription,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              if (repair.workItems.isNotEmpty)
                Text(
                  '${repair.workItems.length} work items',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: repair.status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              repair.status.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: repair.status.color,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: repair.priority.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              repair.priority.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: repair.priority.color,
              ),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isOverdue)
                Text(
                  '${daysRemaining.abs()} days overdue',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (repair.promisedDate != null)
                Text(
                  daysRemaining > 0 ? '$daysRemaining days left' : 'Due today',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysRemaining <= 1 ? Colors.orange : Colors.green,
                  ),
                )
              else
                Text(
                  '${repair.daysInWorkshop} days',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(
          Text(
            '₹${(repair.actualCostPaisa ?? repair.estimatedCostPaisa ?? 0) / 100}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () => _showJobDetails(repair),
                tooltip: 'View',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'status') {
                    _showStatusUpdateDialog(repair);
                  } else if (value == 'assign') {
                    _showAssignDialog(repair);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.update, size: 18),
                        SizedBox(width: 8),
                        Text('Update Status'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'assign',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 18),
                        SizedBox(width: 8),
                        Text('Assign'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(JewelleryRepair repair) {
    final isOverdue = repair.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isOverdue ? Colors.red : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _showJobDetails(repair),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      repair.jobNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: repair.status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      repair.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: repair.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                repair.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (repair.customerPhone != null)
                Text(
                  repair.customerPhone!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
              Text(
                repair.itemDescription,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: repair.priority.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      repair.priority.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: repair.priority.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isOverdue)
                    Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '${repair.daysRemaining.abs()} days overdue',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${repair.daysInWorkshop} days in shop',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No repair jobs found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first repair job',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewJob,
            icon: const Icon(Icons.add),
            label: const Text('NEW JOB'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(JewelleryRepair repair) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RepairStatus.values.where((s) => s != repair.status).map((
            status,
          ) {
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(status.displayName),
              onTap: () {
                Navigator.pop(context);
                _updateStatus(repair, status);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAssignDialog(JewelleryRepair repair) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Craftsman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the craftsman details to assign to this job:'),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Craftsman Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                final name = nameController.text.trim();
                await _repository.assignRepair(
                  repair.id,
                  'craftsman_${name.toLowerCase().replaceAll(' ', '_')}',
                  name,
                );
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Assigned job to $name'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Assignment failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('ASSIGN'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPREHENSIVE JEWELLERY REPAIR DIALOGS
// ============================================================================

class CreateRepairJobDialog extends StatefulWidget {
  const CreateRepairJobDialog({super.key});

  @override
  State<CreateRepairJobDialog> createState() => _CreateRepairJobDialogState();
}

class _CreateRepairJobDialogState extends State<CreateRepairJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final JewelleryRepairRepository _repository = JewelleryRepairRepository(
    sl(),
    sl<SessionManager>(),
  );

  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _weightController = TextEditingController();
  final _complaintController = TextEditingController();
  final _costController = TextEditingController();

  String _category = 'Ring';
  String _metalType = 'Gold 22K';
  RepairPriority _priority = RepairPriority.normal;
  RepairType _repairType = RepairType.polishing;
  DateTime? _promisedDate;

  final List<String> _categories = [
    'Ring',
    'Necklace',
    'Bracelet',
    'Earrings',
    'Chain',
    'Bangles',
    'Pendant',
    'Other',
  ];

  final List<String> _metals = [
    'Gold 24K',
    'Gold 22K',
    'Gold 18K',
    'Silver',
    'Platinum',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _promisedDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _itemDescController.dispose();
    _weightController.dispose();
    _complaintController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _promisedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _promisedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final cost = _costController.text.isNotEmpty
          ? (double.parse(_costController.text) * 100).round()
          : 0;
      final weight = _weightController.text.isNotEmpty
          ? double.tryParse(_weightController.text)
          : null;

      final workItem = RepairWorkItem(
        id: 'item_1',
        type: _repairType,
        description:
            '${_repairType.displayName} for ${_itemDescController.text}',
        estimatedCostPaisa: cost,
      );

      final request = CreateRepairRequest(
        customerId: RidGenerator.next(
          sl<SessionManager>().ownerId ?? 'default',
        ),
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        itemDescription: _itemDescController.text.trim(),
        itemCategory: _category,
        metalType: _metalType,
        weightGrams: weight,
        workItems: [workItem],
        customerComplaint: _complaintController.text.isNotEmpty
            ? _complaintController.text.trim()
            : null,
        priority: _priority,
        promisedDate: _promisedDate,
        estimatedCostPaisa: cost,
        estimatedDays: _promisedDate!.difference(DateTime.now()).inDays,
      );

      await _repository.createRepair(request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating job card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Create Repair Job Card'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter name' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter phone' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Item Specifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _itemDescController,
                    decoration: const InputDecoration(
                      labelText:
                          'Item Description (e.g. Diamond Studded Gold Ring) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _category = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _metalType,
                          decoration: const InputDecoration(
                            labelText: 'Metal Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _metals.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _metalType = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          decoration: const InputDecoration(
                            labelText: 'Weight (Grams)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<RepairPriority>(
                          value: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: RepairPriority.values.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(p.displayName),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _priority = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Work & Pricing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RepairType>(
                    value: _repairType,
                    decoration: const InputDecoration(
                      labelText: 'Primary Service Required',
                      border: OutlineInputBorder(),
                    ),
                    items: RepairType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _repairType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _complaintController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Complaint / Instructions',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(
                            labelText: 'Estimated Cost (₹) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Promised Delivery Date *',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _promisedDate == null
                                      ? 'Select Date'
                                      : '${_promisedDate!.day}/${_promisedDate!.month}/${_promisedDate!.year}',
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('CREATE JOB CARD'),
                      ),
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
}

class RepairJobDetailDialog extends StatefulWidget {
  final JewelleryRepair repair;

  const RepairJobDetailDialog({super.key, required this.repair});

  @override
  State<RepairJobDetailDialog> createState() => _RepairJobDetailDialogState();
}

class _RepairJobDetailDialogState extends State<RepairJobDetailDialog> {
  late JewelleryRepair _repair;
  final JewelleryRepairRepository _repository = JewelleryRepairRepository(
    sl(),
    sl<SessionManager>(),
  );

  @override
  void initState() {
    super.initState();
    _repair = widget.repair;
  }

  Future<void> _refresh() async {
    final updated = await _repository.getRepairById(_repair.id);
    if (updated != null) {
      setState(() => _repair = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
        child: Scaffold(
          appBar: AppBar(
            title: Text('Job Card Details: ${_repair.jobNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _repair.priority.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Priority: ${_repair.priority.displayName}',
                        style: TextStyle(
                          color: _repair.priority.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _repair.status.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Status: ${_repair.status.displayName}',
                        style: TextStyle(
                          color: _repair.status.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Customer Info',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Name: ${_repair.customerName}'),
                if (_repair.customerPhone != null)
                  Text('Phone: ${_repair.customerPhone}'),
                const Divider(),
                const Text(
                  'Item Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Description: ${_repair.itemDescription}'),
                Text(
                  'Category: ${_repair.itemCategory ?? "N/A"} | Metal: ${_repair.metalType ?? "N/A"}',
                ),
                if (_repair.weightGrams != null)
                  Text('Weight: ${_repair.weightGrams} grams'),
                if (_repair.customerComplaint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Complaint: ${_repair.customerComplaint}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const Divider(),
                const Text(
                  'Assignment & Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assigned Craftsman: ${_repair.assignedToName ?? "Unassigned"}',
                ),
                if (_repair.promisedDate != null)
                  Text(
                    'Promised Date: ${_repair.promisedDate!.day}/${_repair.promisedDate!.month}/${_repair.promisedDate!.year}',
                    style: TextStyle(
                      color: _repair.isOverdue ? Colors.red : Colors.black,
                      fontWeight: _repair.isOverdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                const Divider(),
                const Text(
                  'Work Items & Estimates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._repair.workItems.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.type.displayName),
                    subtitle: Text(item.description),
                    trailing: Text(
                      item.estimatedCostPaisa != null
                          ? '₹${item.displayEstimatedCost!.toStringAsFixed(2)}'
                          : '₹0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
