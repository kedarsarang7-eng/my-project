// ============================================================================
// Computer Shop — RMA (Return Merchandise Authorization) Screen
// ============================================================================
// Features:
// - Create RMA requiring non-empty serial + vendor/brand references
// - Update RMA status via dropdown
// - Surface returned errors leaving prior data unchanged
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/computer_job_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RmaScreen extends ConsumerStatefulWidget {
  const RmaScreen({super.key});

  @override
  ConsumerState<RmaScreen> createState() => _RmaScreenState();
}

class _RmaScreenState extends ConsumerState<RmaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serialController = TextEditingController();
  final _brandController = TextEditingController();
  final _reasonController = TextEditingController();
  final _oemRmaNumberController = TextEditingController();

  // Status update fields
  final _rmaIdController = TextEditingController();
  RmaStatus _selectedStatus = RmaStatus.initiated;

  @override
  void dispose() {
    _serialController.dispose();
    _brandController.dispose();
    _reasonController.dispose();
    _oemRmaNumberController.dispose();
    _rmaIdController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateRma() async {
    // Validate form fields (serial + brand must be non-empty).
    if (!_formKey.currentState!.validate()) return;

    final serial = _serialController.text.trim();
    final brand = _brandController.text.trim();
    final reason = _reasonController.text.trim();
    final oemRmaNumber = _oemRmaNumberController.text.trim();

    await ref
        .read(rmaProvider.notifier)
        .createRma(
          componentSerialId: serial,
          brand: brand,
          reason: reason,
          oemRmaNumber: oemRmaNumber.isEmpty ? null : oemRmaNumber,
        );

    final state = ref.read(rmaProvider);
    if (state.createdRmaId != null && state.error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('RMA created: ${state.createdRmaId}')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitUpdateStatus() async {
    final rmaId = _rmaIdController.text.trim();
    if (rmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Please enter an RMA ID to update')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref
        .read(rmaProvider.notifier)
        .updateRmaStatus(rmaId, _selectedStatus);

    final state = ref.read(rmaProvider);
    if (state.statusUpdateSuccess && state.error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RMA $rmaId status updated to ${RmaStatusCodec.label(_selectedStatus)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rmaState = ref.watch(rmaProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RMA Management',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Return Merchandise Authorization',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error display — surfaces returned errors leaving prior data unchanged (Req 9.6)
              if (rmaState.error != null) _ErrorBanner(error: rmaState.error!),

              // Create RMA section
              _CreateRmaCard(
                formKey: _formKey,
                serialController: _serialController,
                brandController: _brandController,
                reasonController: _reasonController,
                oemRmaNumberController: _oemRmaNumberController,
                isLoading: rmaState.isLoading,
                onSubmit: _submitCreateRma,
              ),
              const SizedBox(height: 24),

              // Created RMA display (Req 9.1 — show created RMA after success)
              if (rmaState.createdRmaId != null && rmaState.error == null)
                _CreatedRmaCard(rmaId: rmaState.createdRmaId!),

              if (rmaState.createdRmaId != null && rmaState.error == null)
                const SizedBox(height: 24),

              // Update RMA Status section (Req 9.3)
              _UpdateStatusCard(
                rmaIdController: _rmaIdController,
                selectedStatus: _selectedStatus,
                isLoading: rmaState.isLoading,
                onStatusChanged: (status) {
                  if (status != null) setState(() => _selectedStatus = status);
                },
                onSubmit: _submitUpdateStatus,
                statusUpdateSuccess: rmaState.statusUpdateSuccess,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Error Banner
// ============================================================================

class _ErrorBanner extends StatelessWidget {
  final String error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Create RMA Card
// ============================================================================

class _CreateRmaCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController serialController;
  final TextEditingController brandController;
  final TextEditingController reasonController;
  final TextEditingController oemRmaNumberController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _CreateRmaCard({
    required this.formKey,
    required this.serialController,
    required this.brandController,
    required this.reasonController,
    required this.oemRmaNumberController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_return,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Create RMA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Submit a Return Merchandise Authorization to the vendor',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Serial Reference (required, non-empty) — Req 9.1
              TextFormField(
                controller: serialController,
                decoration: InputDecoration(
                  labelText: 'Serial Reference *',
                  hintText: 'Component serial number',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Serial reference is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vendor/Brand Reference (required, non-empty) — Req 9.1
              TextFormField(
                controller: brandController,
                decoration: InputDecoration(
                  labelText: 'Vendor / Brand *',
                  hintText: 'e.g., ASUS, Dell, HP',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vendor/brand reference is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Describe the defect or reason for return',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // OEM RMA Number (optional)
              TextFormField(
                controller: oemRmaNumberController,
                decoration: InputDecoration(
                  labelText: 'OEM RMA Number (optional)',
                  hintText: 'If already assigned by vendor',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onSubmit,
                  icon: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(isLoading ? 'Creating...' : 'Create RMA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Created RMA Card
// ============================================================================

class _CreatedRmaCard extends StatelessWidget {
  final String rmaId;

  const _CreatedRmaCard({required this.rmaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade600),
            const SizedBox(height: 12),
            Text(
              'RMA Created Successfully',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'RMA ID: $rmaId',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Update RMA Status Card
// ============================================================================

class _UpdateStatusCard extends StatelessWidget {
  final TextEditingController rmaIdController;
  final RmaStatus selectedStatus;
  final bool isLoading;
  final ValueChanged<RmaStatus?> onStatusChanged;
  final VoidCallback onSubmit;
  final bool statusUpdateSuccess;

  const _UpdateStatusCard({
    required this.rmaIdController,
    required this.selectedStatus,
    required this.isLoading,
    required this.onStatusChanged,
    required this.onSubmit,
    required this.statusUpdateSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.update,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Update RMA Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Change the status of an existing RMA',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // RMA ID
            TextField(
              controller: rmaIdController,
              decoration: InputDecoration(
                labelText: 'RMA ID *',
                hintText: 'Enter the RMA identifier',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),

            // Status dropdown (Req 9.3)
            DropdownButtonFormField<RmaStatus>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'New Status *',
                prefixIcon: const Icon(Icons.swap_horiz),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              items: RmaStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRmaStatusIcon(status),
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(RmaStatusCodec.label(status)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onStatusChanged,
            ),
            const SizedBox(height: 24),

            // Update button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(isLoading ? 'Updating...' : 'Update Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Success indicator
            if (statusUpdateSuccess) ...[
              const SizedBox(height: 16),
              Semantics(
                label: 'Status updated successfully',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Status updated successfully',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getRmaStatusIcon(RmaStatus status) {
    switch (status) {
      case RmaStatus.initiated:
        return Icons.play_circle_outline;
      case RmaStatus.shippedToOem:
        return Icons.local_shipping;
      case RmaStatus.replacementReceived:
        return Icons.check_circle;
      case RmaStatus.rejectedByOem:
        return Icons.cancel;
      case RmaStatus.resolved:
        return Icons.done_all;
    }
  }
}
