/// Second-Hand Intake Screen — Seller/Evidence/Inspection/Valuation Capture
///
/// Multi-step intake form for used devices with offline-capable draft saving.
/// Captures seller information, device details, ownership evidence,
/// inspection results, and valuation data.
///
/// Uses application services (MobileShopLocalRepository) — NOT direct
/// DynamoDB authority. Drafts are saved locally and synced when online.
///
/// Requirements: 4.1–4.4, 11.1–11.8, 12.7
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../billing/reconciliation_status_display.dart';
import '../models/imei_unit_models.dart';
import '../models/second_hand_intake_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'inventory_command_service.dart';

// ─── Intake Screen ───────────────────────────────────────────────────────────

/// Second-hand device intake form with offline draft support.
///
/// Flow:
/// 1. Seller Information (name, contact)
/// 2. Device Details (IMEI, brand, model, condition)
/// 3. Ownership Evidence (photo references, status)
/// 4. Inspection (result, notes, inspector)
/// 5. Valuation (proposed price, approved amount)
///
/// Drafts are saved to Drift at each step. Final submission queues the
/// intake command through the outbox for sync.
class SecondHandIntakeFormScreen extends StatefulWidget {
  /// The resolved tenant context (provided by guard).
  final TenantContext tenantContext;

  /// The local repository for tenant-bound data access.
  final MobileShopLocalRepository repository;

  /// Optional existing intake ID for editing a draft.
  final String? existingIntakeId;

  const SecondHandIntakeFormScreen({
    super.key,
    required this.tenantContext,
    required this.repository,
    this.existingIntakeId,
  });

  @override
  State<SecondHandIntakeFormScreen> createState() =>
      _SecondHandIntakeFormScreenState();
}

class _SecondHandIntakeFormScreenState
    extends State<SecondHandIntakeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSaving = false;
  bool _draftSaved = false;

  // Seller fields
  final _sellerNameController = TextEditingController();
  final _sellerContactController = TextEditingController();

  // Device fields
  final _imeiController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _storageController = TextEditingController();
  DeviceCondition _condition = DeviceCondition.good;

  // Evidence fields
  OwnershipEvidenceStatus _evidenceStatus = OwnershipEvidenceStatus.pending;

  // Inspection fields
  InspectionResult? _inspectionResult;
  final _inspectionNotesController = TextEditingController();
  final _inspectorNameController = TextEditingController();

  // Valuation fields
  final _proposedPriceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _sellerNameController.dispose();
    _sellerContactController.dispose();
    _imeiController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _storageController.dispose();
    _inspectionNotesController.dispose();
    _inspectorNameController.dispose();
    _proposedPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingIntakeId != null
              ? 'Edit Intake Draft'
              : 'Second-Hand Intake',
        ),
        actions: [
          if (_draftSaved)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.save, size: 16),
                label: const Text('Draft Saved'),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveDraft,
            tooltip: 'Save draft offline',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: (step) => setState(() => _currentStep = step),
          controlsBuilder: _buildStepControls,
          steps: [
            _buildSellerStep(theme),
            _buildDeviceStep(theme),
            _buildEvidenceStep(theme),
            _buildInspectionStep(theme),
            _buildValuationStep(theme),
          ],
        ),
      ),
    );
  }

  // ─── Steps ─────────────────────────────────────────────────────────────────

  Step _buildSellerStep(ThemeData theme) {
    return Step(
      title: const Text('Seller Information'),
      subtitle: _sellerNameController.text.isNotEmpty
          ? Text(_sellerNameController.text)
          : null,
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextFormField(
            controller: _sellerNameController,
            decoration: const InputDecoration(
              labelText: 'Seller Name *',
              hintText: 'Enter seller full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Seller name is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sellerContactController,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              hintText: 'Phone or email',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Step _buildDeviceStep(ThemeData theme) {
    return Step(
      title: const Text('Device Details'),
      subtitle: _imeiController.text.isNotEmpty
          ? Text('IMEI: ${_imeiController.text}')
          : null,
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextFormField(
            controller: _imeiController,
            decoration: const InputDecoration(
              labelText: 'IMEI Number *',
              hintText: '15-digit IMEI',
              prefixIcon: Icon(Icons.qr_code),
            ),
            keyboardType: TextInputType.number,
            maxLength: 15,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'IMEI is required';
              if (v.trim().length != 15) return 'IMEI must be 15 digits';
              if (!RegExp(r'^\d{15}$').hasMatch(v.trim())) {
                return 'IMEI must contain only digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _brandController,
            decoration: const InputDecoration(
              labelText: 'Brand *',
              hintText: 'e.g. Samsung, Apple',
              prefixIcon: Icon(Icons.phone_android),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Brand is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model *',
              hintText: 'e.g. Galaxy S24, iPhone 15',
              prefixIcon: Icon(Icons.smartphone),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Model is required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g. Black',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _storageController,
                  decoration: const InputDecoration(
                    labelText: 'Storage',
                    hintText: 'e.g. 128GB',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConditionSelector(theme),
        ],
      ),
    );
  }

  Step _buildEvidenceStep(ThemeData theme) {
    return Step(
      title: const Text('Ownership Evidence'),
      subtitle: Text(_evidenceStatus.name),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ownership Verification Status',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<OwnershipEvidenceStatus>(
            segments: const [
              ButtonSegment(
                value: OwnershipEvidenceStatus.pending,
                label: Text('Pending'),
                icon: Icon(Icons.hourglass_empty),
              ),
              ButtonSegment(
                value: OwnershipEvidenceStatus.verified,
                label: Text('Verified'),
                icon: Icon(Icons.check_circle_outline),
              ),
              ButtonSegment(
                value: OwnershipEvidenceStatus.unverified,
                label: Text('Unverified'),
                icon: Icon(Icons.help_outline),
              ),
            ],
            selected: {_evidenceStatus},
            onSelectionChanged: (selected) {
              setState(() => _evidenceStatus = selected.first);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Upload evidence photos (bill, box, ID proof) to confirm ownership.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Evidence upload placeholder — uses approved object storage
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Integrate with evidence upload service
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Evidence upload coming soon')),
              );
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Evidence'),
          ),
        ],
      ),
    );
  }

  Step _buildInspectionStep(ThemeData theme) {
    return Step(
      title: const Text('Inspection'),
      subtitle: _inspectionResult != null
          ? Text(_inspectionResultLabel(_inspectionResult!))
          : null,
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspection Result', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<InspectionResult?>(
            segments: const [
              ButtonSegment(
                value: InspectionResult.pass,
                label: Text('Pass'),
                icon: Icon(Icons.check),
              ),
              ButtonSegment(
                value: InspectionResult.conditionalPass,
                label: Text('Conditional'),
                icon: Icon(Icons.warning_amber),
              ),
              ButtonSegment(
                value: InspectionResult.fail,
                label: Text('Fail'),
                icon: Icon(Icons.close),
              ),
            ],
            selected: _inspectionResult != null ? {_inspectionResult} : {},
            emptySelectionAllowed: true,
            onSelectionChanged: (selected) {
              setState(() {
                _inspectionResult = selected.isNotEmpty ? selected.first : null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _inspectorNameController,
            decoration: const InputDecoration(
              labelText: 'Inspector Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inspectionNotesController,
            decoration: const InputDecoration(
              labelText: 'Inspection Notes',
              hintText: 'Screen condition, battery health, etc.',
              prefixIcon: Icon(Icons.note_outlined),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Step _buildValuationStep(ThemeData theme) {
    return Step(
      title: const Text('Valuation'),
      subtitle: _proposedPriceController.text.isNotEmpty
          ? Text('₹${_proposedPriceController.text}')
          : null,
      isActive: _currentStep >= 4,
      state: StepState.indexed,
      content: Column(
        children: [
          TextFormField(
            controller: _proposedPriceController,
            decoration: const InputDecoration(
              labelText: 'Proposed Price (₹) *',
              hintText: 'Amount in rupees',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Price is required';
              final amount = int.tryParse(v.trim());
              if (amount == null || amount <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Additional Notes',
              hintText: 'Any relevant details',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _submitIntake,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSaving ? 'Submitting...' : 'Submit Intake'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Controls Builder ──────────────────────────────────────────────────────

  Widget _buildStepControls(BuildContext context, ControlsDetails details) {
    final isLastStep = _currentStep == 4;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (!isLastStep)
            FilledButton(
              onPressed: details.onStepContinue,
              child: const Text('Continue'),
            ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Condition Selector ────────────────────────────────────────────────────

  Widget _buildConditionSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Device Condition *', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DeviceCondition.values.map((condition) {
            final isSelected = _condition == condition;
            return ChoiceChip(
              label: Text(_conditionLabel(condition)),
              selected: isSelected,
              onSelected: (_) => setState(() => _condition = condition),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _onStepContinue() {
    if (_currentStep < 4) {
      setState(() => _currentStep += 1);
      _saveDraft(); // Auto-save draft on step advancement
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      // Save draft to local outbox — offline-capable
      final cmdService = InventoryCommandService(repository: widget.repository);
      await cmdService.queueIntakeSubmission(
        context: widget.tenantContext,
        intakeData: _buildIntakePayload(isDraft: true),
      );
      setState(() => _draftSaved = true);
    } catch (_) {
      // Draft save failure is non-fatal
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _submitIntake() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Queue the intake mutation for sync
      final cmdService = InventoryCommandService(repository: widget.repository);
      await cmdService.queueIntakeSubmission(
        context: widget.tenantContext,
        intakeData: _buildIntakePayload(isDraft: false),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intake submitted. Pending sync.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _buildIntakePayload({required bool isDraft}) {
    return {
      'isDraft': isDraft,
      'sellerName': _sellerNameController.text.trim(),
      'sellerContact': _sellerContactController.text.trim(),
      'imei': _imeiController.text.trim(),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'color': _colorController.text.trim(),
      'storage': _storageController.text.trim(),
      'condition': _condition.toWireValue(),
      'ownershipEvidenceStatus': _evidenceStatus.toWireValue(),
      if (_inspectionResult != null)
        'inspectionResult': _inspectionResult!.toWireValue(),
      'inspectionNotes': _inspectionNotesController.text.trim(),
      'inspectorName': _inspectorNameController.text.trim(),
      'proposedPrice': _proposedPriceController.text.trim(),
      'notes': _notesController.text.trim(),
    };
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _conditionLabel(DeviceCondition condition) {
  switch (condition) {
    case DeviceCondition.newDevice:
      return 'New';
    case DeviceCondition.likeNew:
      return 'Like New';
    case DeviceCondition.good:
      return 'Good';
    case DeviceCondition.fair:
      return 'Fair';
    case DeviceCondition.poor:
      return 'Poor';
    case DeviceCondition.damaged:
      return 'Damaged';
  }
}

String _inspectionResultLabel(InspectionResult result) {
  switch (result) {
    case InspectionResult.pass:
      return 'Pass';
    case InspectionResult.conditionalPass:
      return 'Conditional Pass';
    case InspectionResult.fail:
      return 'Fail';
  }
}
