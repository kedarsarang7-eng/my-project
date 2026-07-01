// ============================================================================
// Computer Shop — Job Card Detail Screen
// ============================================================================
// Complete job management with:
// - Job details view/edit
// - Parts management (add/view)
// - Technician assignment
// - Labor cost tracking
// - Status updates
// - Convert to invoice
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/computer_repository.dart';
import '../../providers/computer_job_providers.dart';
import '../widgets/job_card_dialogs.dart';

class JobCardDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobCardDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobCardDetailScreen> createState() =>
      _JobCardDetailScreenState();
}

class _JobCardDetailScreenState extends ConsumerState<JobCardDetailScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final jobDetailState = ref.watch(jobCardDetailProvider(widget.jobId));
    final job = jobDetailState.job;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        title: Text(
          job != null
              ? 'Job #${job.id.substring(0, 8).toUpperCase()}'
              : 'Job Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          if (job != null && job.status != 'DELIVERED')
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'convert_invoice',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 20),
                      SizedBox(width: 8),
                      Text('Convert to Invoice'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'assign_tech',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text('Assign Technician'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'update_labor',
                  child: Row(
                    children: [
                      Icon(Icons.attach_money, size: 20),
                      SizedBox(width: 8),
                      Text('Update Labor Cost'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: jobDetailState.isLoading && job == null
          ? const _LoadingState()
          : jobDetailState.error != null && job == null
          ? _ErrorState(
              error: jobDetailState.error!,
              onRetry: () => ref
                  .read(jobCardDetailProvider(widget.jobId).notifier)
                  .loadJob(),
            )
          : job == null
          ? const Center(child: Text('Job not found'))
          : Column(
              children: [
                // Status Bar
                _StatusBar(job: job),
                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: false,
                    onTap: (index) => setState(() => _selectedTab = index),
                    indicatorColor: const Color(0xFF3B82F6),
                    labelColor: const Color(0xFF3B82F6),
                    unselectedLabelColor: Colors.grey.shade600,
                    tabs: const [
                      Tab(text: 'Details', icon: Icon(Icons.info_outline)),
                      Tab(text: 'Parts', icon: Icon(Icons.build)),
                      Tab(text: 'Labor', icon: Icon(Icons.paid)),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _DetailsTab(job: job),
                      _PartsTab(
                        jobId: widget.jobId,
                        parts: jobDetailState.parts,
                        isEditable: job.status != 'DELIVERED',
                      ),
                      _LaborTab(
                        job: job,
                        onUpdateLabor: _showUpdateLaborDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton:
          job != null && job.status != 'DELIVERED' && _selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddPartDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Part'),
              backgroundColor: const Color(0xFF3B82F6),
            )
          : null,
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'convert_invoice':
        _showConvertToInvoiceDialog();
        break;
      case 'assign_tech':
        _showAssignTechnicianDialog();
        break;
      case 'update_labor':
        _showUpdateLaborDialog();
        break;
    }
  }

  void _showAddPartDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPartBottomSheet(
        jobId: widget.jobId,
        onAdd: (productId, quantity, unitPrice, notes) async {
          try {
            await ref
                .read(jobCardDetailProvider(widget.jobId).notifier)
                .addPart(
                  productId: productId,
                  quantity: quantity,
                  unitPrice: unitPrice,
                  notes: notes,
                );
            Navigator.pop(context);
            _showSuccessSnackBar('Part added successfully');
          } catch (e) {
            _showErrorSnackBar('Failed to add part: $e');
          }
        },
      ),
    );
  }

  void _showAssignTechnicianDialog() {
    showDialog(
      context: context,
      builder: (context) => AssignTechnicianDialog(
        onAssign: (techId, techName) async {
          try {
            await ref
                .read(jobCardDetailProvider(widget.jobId).notifier)
                .assignTechnician(techId, techName);
            Navigator.pop(context);
            _showSuccessSnackBar('Technician assigned');
          } catch (e) {
            _showErrorSnackBar('Failed to assign technician: $e');
          }
        },
      ),
    );
  }

  void _showUpdateLaborDialog() {
    final job = ref.read(jobCardDetailProvider(widget.jobId)).job;
    if (job == null) return;

    showDialog(
      context: context,
      builder: (context) => UpdateLaborDialog(
        estimatedLaborCost: job.estimatedLaborCost,
        actualLaborCost: job.actualLaborCost,
        diagnosis: job.diagnosis,
        onUpdate: (estimated, actual, diagnosis) async {
          try {
            await ref
                .read(jobCardDetailProvider(widget.jobId).notifier)
                .updateLaborCost(
                  estimatedLaborCost: estimated,
                  actualLaborCost: actual,
                  diagnosis: diagnosis,
                );
            Navigator.pop(context);
            _showSuccessSnackBar('Labor costs updated');
          } catch (e) {
            _showErrorSnackBar('Failed to update labor cost: $e');
          }
        },
      ),
    );
  }

  void _showConvertToInvoiceDialog() {
    final job = ref.read(jobCardDetailProvider(widget.jobId)).job;
    if (job == null) return;

    showDialog(
      context: context,
      builder: (context) => ConvertToInvoiceDialog(
        job: job,
        onConvert:
            (customerName, customerPhone, paymentMode, discountCents) async {
              try {
                final result = await ref
                    .read(jobCardDetailProvider(widget.jobId).notifier)
                    .convertToInvoice(
                      customerName: customerName,
                      customerPhone: customerPhone,
                      paymentMode: paymentMode,
                      discountCents: discountCents,
                    );
                Navigator.pop(context);
                _showSuccessSnackBar(
                  'Converted to Invoice: ${result['invoiceNumber']}',
                );
                // Navigate to invoice if needed
              } catch (e) {
                _showErrorSnackBar('Failed to convert: $e');
              }
            },
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// Status Bar
// ============================================================================

class _StatusBar extends StatelessWidget {
  final ComputerJobCard job;

  const _StatusBar({required this.job});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(job.status);
    final steps = [
      'INTAKE',
      'DIAGNOSIS',
      'AWAITING_PARTS',
      'REPAIRING',
      'QC',
      'DELIVERED',
    ];
    final currentStep = steps.indexOf(job.status);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if (job.technicianName != null)
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      job.technicianName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Steps
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isCompleted = index <= currentStep;
                final isCurrent = index == currentStep;

                return Row(
                  children: [
                    if (index > 0)
                      Container(
                        width: 24,
                        height: 2,
                        color: isCompleted
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: const Color(0xFF3B82F6),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : Icons.circle,
                        size: 14,
                        color: isCompleted
                            ? Colors.white
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
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
        return 'Quality Check';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
    }
  }
}

// ============================================================================
// Details Tab
// ============================================================================

class _DetailsTab extends StatelessWidget {
  final ComputerJobCard job;

  const _DetailsTab({required this.job});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'Device Information',
            icon: Icons.computer,
            children: [
              _InfoRow('Brand', job.deviceBrand),
              _InfoRow('Model', job.deviceModel),
              if (job.serialNumber != null)
                _InfoRow('Serial Number', job.serialNumber!),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Problem Description',
            icon: Icons.report_problem_outlined,
            children: [
              Text(
                job.reportedIssue,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
          if (job.diagnosis != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Diagnosis',
              icon: Icons.medical_services_outlined,
              children: [
                Text(
                  job.diagnosis!,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Timeline',
            icon: Icons.calendar_today,
            children: [
              _InfoRow(
                'Created',
                DateFormat('dd MMM yyyy, hh:mm a').format(job.createdAt),
              ),
              _InfoRow(
                'Updated',
                DateFormat('dd MMM yyyy, hh:mm a').format(job.updatedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Parts Tab
// ============================================================================

class _PartsTab extends StatelessWidget {
  final String jobId;
  final List<ComputerJobPart> parts;
  final bool isEditable;

  const _PartsTab({
    required this.jobId,
    required this.parts,
    required this.isEditable,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final totalPartsCost = parts.fold<double>(0, (sum, p) => sum + p.totalCost);

    return Column(
      children: [
        // Parts List
        Expanded(
          child: parts.isEmpty
              ? _EmptyPartsState(isEditable: isEditable)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parts.length,
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.build,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        title: Text(
                          part.productName ?? 'Unknown Part',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${part.quantity} × ${currencyFormat.format(part.unitPrice)}',
                            ),
                            if (part.notes != null)
                              Text(
                                part.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          currencyFormat.format(part.totalCost),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Total Cost Footer
        if (parts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Parts Cost',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  currencyFormat.format(totalPartsCost),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyPartsState extends StatelessWidget {
  final bool isEditable;

  const _EmptyPartsState({required this.isEditable});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No parts added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEditable
                ? 'Add parts used for this repair job'
                : 'No parts were used for this job',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Labor Tab
// ============================================================================

class _LaborTab extends StatelessWidget {
  final ComputerJobCard job;
  final VoidCallback onUpdateLabor;

  const _LaborTab({required this.job, required this.onUpdateLabor});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final estimated = job.estimatedLaborCost ?? 0;
    final actual = job.actualLaborCost ?? 0;
    final parts = job.actualPartsCost ?? 0;
    final total = actual + parts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cost Summary Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.paid, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text(
                        'Cost Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _CostRow(
                    label: 'Estimated Labor',
                    value: currencyFormat.format(estimated),
                    isHighlighted: false,
                  ),
                  const SizedBox(height: 12),
                  _CostRow(
                    label: 'Actual Labor',
                    value: currencyFormat.format(actual),
                    isHighlighted: actual > 0,
                  ),
                  const SizedBox(height: 12),
                  _CostRow(
                    label: 'Parts Cost',
                    value: currencyFormat.format(parts),
                    isHighlighted: parts > 0,
                  ),
                  const Divider(height: 24),
                  _CostRow(
                    label: 'Total Cost',
                    value: currencyFormat.format(total),
                    isHighlighted: true,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Update Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpdateLabor,
              icon: const Icon(Icons.edit),
              label: const Text('Update Labor Costs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final bool isTotal;

  const _CostRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal
                ? FontWeight.bold
                : (isHighlighted ? FontWeight.w600 : FontWeight.normal),
            color: isTotal
                ? const Color(0xFF1E293B)
                : (isHighlighted
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Loading & Error States
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Failed to load job',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
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
