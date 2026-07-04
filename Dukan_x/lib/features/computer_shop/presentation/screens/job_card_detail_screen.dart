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
import '../../../../features/invoice/screens/invoice_preview_screen.dart';
import '../../../../models/bill.dart' as bill_model;
import '../../data/repositories/computer_repository.dart';
import '../../providers/computer_job_providers.dart';
import '../../utils/computer_shop_business_rules.dart';
import '../../utils/job_status_codec.dart';
import '../../utils/money.dart';
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

  static const int _kTabCount = 3;

  @override
  Widget build(BuildContext context) {
    final jobDetailState = ref.watch(jobCardDetailProvider(widget.jobId));
    final job = jobDetailState.job;

    return DefaultTabController(
      length: _kTabCount,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: Text(
            job != null
                ? 'Job #${job.id.substring(0, 8).toUpperCase()}'
                : 'Job Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            if (job != null &&
                job.invoiceId != null &&
                job.invoiceId!.trim().isNotEmpty)
              _OpenInvoiceButton(
                invoiceId: job.invoiceId!,
                onOpenFailed: (message) => _showErrorSnackBar(message),
              ),
            if (job != null && job.status != ComputerJobStatus.delivered)
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
            : _buildJobContent(context, job, jobDetailState),
        floatingActionButton:
            job != null &&
                job.status != ComputerJobStatus.delivered &&
                _selectedTab == 1
            ? FloatingActionButton.extended(
                onPressed: () => _showAddPartDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Part'),
                backgroundColor: const Color(0xFF3B82F6),
              )
            : null,
      ),
    );
  }

  Widget _buildJobContent(
    BuildContext context,
    ComputerJobCard job,
    dynamic jobDetailState,
  ) {
    // Validate the TabController matches the expected tab count
    final TabController? tabController = DefaultTabController.maybeOf(context);
    if (tabController == null || tabController.length != _kTabCount) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Tab layout error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unable to initialize tabs. Expected $_kTabCount tabs but '
                '${tabController == null ? "no controller found" : "found ${tabController.length}"}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Status Bar
        _StatusBar(job: job, jobId: widget.jobId),
        // Tab Bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            isScrollable: false,
            onTap: (index) => setState(() => _selectedTab = index),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
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
                isEditable: job.status != ComputerJobStatus.delivered,
              ),
              _LaborTab(job: job, onUpdateLabor: _showUpdateLaborDialog),
            ],
          ),
        ),
      ],
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
      builder: (sheetContext) => AddPartBottomSheet(
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
            if (!mounted) return;
            Navigator.pop(sheetContext);
            _showSuccessSnackBar('Part added successfully');
          } catch (e) {
            if (!mounted) return;
            _showErrorSnackBar('Failed to add part: $e');
          }
        },
      ),
    );
  }

  void _showAssignTechnicianDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AssignTechnicianDialog(
        onAssign: (techId, techName) async {
          try {
            await ref
                .read(jobCardDetailProvider(widget.jobId).notifier)
                .assignTechnician(techId, techName);
            if (!mounted) return;
            Navigator.pop(dialogContext);
            _showSuccessSnackBar('Technician assigned');
          } catch (e) {
            if (!mounted) return;
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
      builder: (dialogContext) => UpdateLaborDialog(
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
            if (!mounted) return;
            Navigator.pop(dialogContext);
            _showSuccessSnackBar('Labor costs updated');
          } catch (e) {
            if (!mounted) return;
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
      builder: (dialogContext) => ConvertToInvoiceDialog(
        job: job,
        onConvert: (customerName, customerPhone, paymentMode, discount) async {
          try {
            final result = await ref
                .read(jobCardDetailProvider(widget.jobId).notifier)
                .convertToInvoice(
                  customerName: customerName,
                  customerPhone: customerPhone,
                  paymentMode: paymentMode,
                  discount: discount,
                );
            if (!mounted) return;
            Navigator.pop(dialogContext);
            _showSuccessSnackBar(
              'Converted to Invoice: ${result['invoiceNumber']}',
            );
            final invoiceId = result['invoiceId']?.toString();
            if (invoiceId == null || invoiceId.trim().isEmpty) {
              // Req 16.3: no usable invoice identifier — suppress the
              // navigation control (handled by the invoiceId-driven
              // AppBar action) and surface an error, while the success
              // snackbar above still reflects the conversion outcome.
              _showErrorSnackBar(
                'Invoice created but could not be opened: no invoice reference returned',
              );
            }
          } catch (e) {
            if (!mounted) return;
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
// Open Invoice Button (Req 16)
// ============================================================================
//
// Persistent navigation control shown whenever the job card carries a
// non-null, non-empty `invoiceId` (i.e. conversion succeeded). Tapping it
// fetches the invoice and opens it; on retrieval failure the screen stays
// put and an error is surfaced via [onOpenFailed] (Req 16.4).

class _OpenInvoiceButton extends ConsumerStatefulWidget {
  final String invoiceId;
  final void Function(String message) onOpenFailed;

  const _OpenInvoiceButton({
    required this.invoiceId,
    required this.onOpenFailed,
  });

  @override
  ConsumerState<_OpenInvoiceButton> createState() => _OpenInvoiceButtonState();
}

class _OpenInvoiceButtonState extends ConsumerState<_OpenInvoiceButton> {
  bool _isOpening = false;

  Future<void> _openInvoice() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);

    try {
      final repository = ref.read(computerRepositoryProvider);
      final raw = await repository.getInvoiceById(widget.invoiceId);

      final id = raw['id']?.toString() ?? widget.invoiceId;
      if (id.trim().isEmpty) {
        throw Exception('Invoice reference is empty');
      }

      final items = (raw['items'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => bill_model.BillItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      final bill = bill_model.Bill(
        id: id,
        invoiceNumber: raw['invoiceNumber']?.toString() ?? '',
        customerId: raw['customerId']?.toString() ?? '',
        customerName: raw['customerName']?.toString() ?? 'Walk-in',
        customerPhone: raw['customerPhone']?.toString() ?? '',
        date:
            DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        items: items,
        subtotal: Money.paiseToRupeesOr(raw['subtotalCents'], 0.0),
        totalTax: Money.paiseToRupeesOr(raw['taxCents'], 0.0),
        grandTotal: Money.paiseToRupeesOr(raw['totalCents'], 0.0),
        paidAmount: Money.paiseToRupeesOr(raw['paidCents'], 0.0),
        status: raw['status']?.toString() ?? 'Unpaid',
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(bill: bill)),
      );
    } catch (e) {
      if (!mounted) return;
      widget.onOpenFailed('Could not open invoice: $e');
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Open Invoice',
      onPressed: _isOpening ? null : _openInvoice,
      icon: _isOpening
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long),
    );
  }
}

// ============================================================================
// Status Bar
// ============================================================================

class _StatusBar extends ConsumerWidget {
  final ComputerJobCard job;
  final String jobId;

  const _StatusBar({required this.job, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(job.status);
    final validTransitions = ref.watch(
      validStatusTransitionsProvider(job.status),
    );
    final steps = [
      ComputerJobStatus.intake,
      ComputerJobStatus.diagnosis,
      ComputerJobStatus.partsOrdered,
      ComputerJobStatus.underRepair,
      ComputerJobStatus.qa,
      ComputerJobStatus.delivered,
    ];
    final currentStep = steps.indexOf(job.status);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                label: 'Status: ${JobStatusCodec.label(job.status)}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(job.status),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        JobStatusCodec.label(job.status),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status-change control
              _StatusChangeControl(
                currentStatus: job.status,
                validTransitions: validTransitions,
                onStatusSelected: (newStatus) async {
                  await ref
                      .read(jobCardDetailProvider(jobId).notifier)
                      .updateStatus(newStatus);
                  // Check for errors after update
                  final state = ref.read(jobCardDetailProvider(jobId));
                  if (state.error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text(state.error!)),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
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
                final stepLabel = _getAbbreviatedStepLabel(step);

                return Row(
                  children: [
                    if (index > 0)
                      Container(
                        width: 24,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: isCompleted
                            ? const Color(0xFF3B82F6)
                            : Colors.grey.shade300,
                      ),
                    Semantics(
                      label:
                          '$stepLabel: ${isCompleted ? (isCurrent ? "current step" : "completed") : "pending"}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey.shade200,
                              shape: isCurrent
                                  ? BoxShape.circle
                                  : (isCompleted
                                        ? BoxShape.circle
                                        : BoxShape.circle),
                              border: isCurrent
                                  ? Border.all(
                                      color: const Color(0xFF3B82F6),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check
                                  : (isCurrent
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked),
                              size: 14,
                              color: isCompleted
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stepLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isCompleted
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
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

  Color _getStatusColor(ComputerJobStatus status) {
    switch (status) {
      case ComputerJobStatus.intake:
        return Colors.orange;
      case ComputerJobStatus.diagnosis:
        return Colors.amber;
      case ComputerJobStatus.partsOrdered:
        return Colors.deepOrange;
      case ComputerJobStatus.underRepair:
        return Colors.blue;
      case ComputerJobStatus.qa:
        return Colors.purple;
      case ComputerJobStatus.ready:
        return Colors.teal;
      case ComputerJobStatus.delivered:
        return Colors.green;
      case ComputerJobStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getAbbreviatedStepLabel(ComputerJobStatus status) {
    switch (status) {
      case ComputerJobStatus.intake:
        return 'Intake';
      case ComputerJobStatus.diagnosis:
        return 'Diag';
      case ComputerJobStatus.partsOrdered:
        return 'Parts';
      case ComputerJobStatus.underRepair:
        return 'Repair';
      case ComputerJobStatus.qa:
        return 'QC';
      case ComputerJobStatus.ready:
        return 'Ready';
      case ComputerJobStatus.delivered:
        return 'Done';
      case ComputerJobStatus.cancelled:
        return 'Cancel';
    }
  }

  IconData _getStatusIcon(ComputerJobStatus status) {
    switch (status) {
      case ComputerJobStatus.intake:
        return Icons.login;
      case ComputerJobStatus.diagnosis:
        return Icons.search;
      case ComputerJobStatus.partsOrdered:
        return Icons.shopping_cart;
      case ComputerJobStatus.underRepair:
        return Icons.build;
      case ComputerJobStatus.qa:
        return Icons.verified;
      case ComputerJobStatus.ready:
        return Icons.check_circle_outline;
      case ComputerJobStatus.delivered:
        return Icons.check_circle;
      case ComputerJobStatus.cancelled:
        return Icons.cancel;
    }
  }
}

// ============================================================================
// Status Change Control
// ============================================================================

class _StatusChangeControl extends StatelessWidget {
  final ComputerJobStatus currentStatus;
  final List<ComputerJobStatus> validTransitions;
  final Future<void> Function(ComputerJobStatus) onStatusSelected;

  const _StatusChangeControl({
    required this.currentStatus,
    required this.validTransitions,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasTransitions = validTransitions.isNotEmpty;

    return PopupMenuButton<ComputerJobStatus>(
      enabled: hasTransitions,
      onSelected: onStatusSelected,
      tooltip: hasTransitions ? 'Change status' : 'No further transitions',
      offset: const Offset(0, 40),
      itemBuilder: (context) => validTransitions.map((status) {
        return PopupMenuItem<ComputerJobStatus>(
          value: status,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(JobStatusCodec.label(status)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasTransitions
                ? const Color(0xFF3B82F6)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
          color: hasTransitions
              ? const Color(0xFF3B82F6).withOpacity(0.05)
              : Colors.grey.shade50,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasTransitions ? Icons.swap_horiz : Icons.block,
              size: 16,
              color: hasTransitions
                  ? const Color(0xFF3B82F6)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Text(
              hasTransitions ? 'Change Status' : 'No further transitions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasTransitions
                    ? const Color(0xFF3B82F6)
                    : Colors.grey.shade500,
              ),
            ),
            if (hasTransitions) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: const Color(0xFF3B82F6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ComputerJobStatus status) {
    switch (status) {
      case ComputerJobStatus.intake:
        return Colors.orange;
      case ComputerJobStatus.diagnosis:
        return Colors.amber;
      case ComputerJobStatus.partsOrdered:
        return Colors.deepOrange;
      case ComputerJobStatus.underRepair:
        return Colors.blue;
      case ComputerJobStatus.qa:
        return Colors.purple;
      case ComputerJobStatus.ready:
        return Colors.teal;
      case ComputerJobStatus.delivered:
        return Colors.green;
      case ComputerJobStatus.cancelled:
        return Colors.grey;
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
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
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
                ? Theme.of(context).colorScheme.onSurface
                : (isHighlighted
                      ? Theme.of(context).colorScheme.primary
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
