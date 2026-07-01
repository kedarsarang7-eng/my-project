// WCAG 2.1 AA: Theme-derived color pairs target ≥4.5:1 contrast (normal text)
// and ≥3:1 (large text). Full conformance requires manual AT testing + expert review.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/clothing_repository_offline.dart';
import '../../data/models/tailoring_record.dart';
import '../../utils/clothing_business_rules.dart';
import '../../widgets/clothing_sync_indicator.dart';

class TailoringMeasurementsScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  final String? customerId;
  final Map<String, dynamic>? existingMeasurements;

  const TailoringMeasurementsScreen({
    super.key,
    this.invoiceId,
    this.customerId,
    this.existingMeasurements,
  });

  @override
  ConsumerState<TailoringMeasurementsScreen> createState() =>
      _TailoringMeasurementsScreenState();
}

class _TailoringMeasurementsScreenState
    extends ConsumerState<TailoringMeasurementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryDateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _customNotesCtrl = TextEditingController();

  String _priority = 'normal';

  // Measurement controllers
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _hipsCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _sleeveCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _neckCtrl = TextEditingController();
  final _inseamCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Set default delivery date to 7 days from now
    _deliveryDateCtrl.text = DateTime.now()
        .add(const Duration(days: 7))
        .toString()
        .split(' ')[0];

    // Load existing measurements if provided
    if (widget.existingMeasurements != null) {
      final measurements =
          widget.existingMeasurements!['measurements'] as Map<String, dynamic>?;
      if (measurements != null) {
        _chestCtrl.text = measurements['chest']?.toString() ?? '';
        _waistCtrl.text = measurements['waist']?.toString() ?? '';
        _hipsCtrl.text = measurements['hips']?.toString() ?? '';
        _lengthCtrl.text = measurements['length']?.toString() ?? '';
        _sleeveCtrl.text = measurements['sleeve']?.toString() ?? '';
        _shoulderCtrl.text = measurements['shoulder']?.toString() ?? '';
        _neckCtrl.text = measurements['neck']?.toString() ?? '';
        _inseamCtrl.text = measurements['inseam']?.toString() ?? '';
        _customNotesCtrl.text = measurements['customNotes']?.toString() ?? '';
      }

      _deliveryDateCtrl.text =
          widget.existingMeasurements!['deliveryDate']?.toString().split(
            ' ',
          )[0] ??
          _deliveryDateCtrl.text;
      _priority =
          widget.existingMeasurements!['priority']?.toString() ?? 'normal';
      _notesCtrl.text = widget.existingMeasurements!['notes']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _deliveryDateCtrl.dispose();
    _notesCtrl.dispose();
    _customNotesCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipsCtrl.dispose();
    _lengthCtrl.dispose();
    _sleeveCtrl.dispose();
    _shoulderCtrl.dispose();
    _neckCtrl.dispose();
    _inseamCtrl.dispose();
    super.dispose();
  }

  /// Map of measurement field labels to their controllers and corresponding
  /// [MeasurementKey] for bounds validation. Fields without a key (e.g., neck)
  /// are validated only for parseability (positive number).
  List<({String label, TextEditingController controller, MeasurementKey? key})>
  get _measurementFields => [
    (label: 'Chest', controller: _chestCtrl, key: MeasurementKey.chest),
    (label: 'Waist', controller: _waistCtrl, key: MeasurementKey.waist),
    (label: 'Hips', controller: _hipsCtrl, key: MeasurementKey.hip),
    (label: 'Length', controller: _lengthCtrl, key: MeasurementKey.length),
    (label: 'Sleeve', controller: _sleeveCtrl, key: MeasurementKey.sleeve),
    (
      label: 'Shoulder',
      controller: _shoulderCtrl,
      key: MeasurementKey.shoulder,
    ),
    (label: 'Neck', controller: _neckCtrl, key: null),
    (label: 'Inseam', controller: _inseamCtrl, key: MeasurementKey.inseam),
  ];

  Future<void> _saveMeasurements() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate each non-empty measurement field against ClothingBusinessRules
    final invalidFields = <String>[];
    final parsedMeasurements = <String, double>{};
    final typedMeasurements = <MeasurementKey, double>{};

    for (final field in _measurementFields) {
      final text = field.controller.text.trim();
      if (text.isEmpty) continue;

      final parsed = double.tryParse(text);
      if (parsed == null) {
        invalidFields.add(field.label);
        continue;
      }

      if (field.key != null) {
        if (!ClothingBusinessRules.isValidMeasurement(field.key!, parsed)) {
          invalidFields.add(field.label);
          continue;
        }
        typedMeasurements[field.key!] = parsed;
      } else {
        // For fields without a MeasurementKey (e.g., Neck), validate > 0
        if (parsed <= 0) {
          invalidFields.add(field.label);
          continue;
        }
      }

      parsedMeasurements[field.label.toLowerCase()] = parsed;
    }

    if (invalidFields.isNotEmpty) {
      // Reject the save, retain all entered values, name the invalid fields
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid measurement${invalidFields.length > 1 ? 's' : ''}: '
              '${invalidFields.join(', ')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Route through ClothingRepositoryOffline (offline-first, Req 12.1)
      final repository = ClothingRepositoryOffline(sl(), sl<SessionManager>());
      await repository.initialize();

      final session = sl<SessionManager>();
      final tenantId = session.currentBusinessId ?? session.ownerId ?? '';

      // Parse delivery date as typed DateTime (Req 9.6)
      final deliveryDate =
          DateTime.tryParse(_deliveryDateCtrl.text) ??
          DateTime.now().add(const Duration(days: 7));

      if (widget.existingMeasurements != null) {
        // Update existing tailoring record
        final existingId = widget.existingMeasurements!['id']?.toString() ?? '';
        final existingRecord = TailoringRecord(
          id: existingId,
          tenantId: tenantId,
          customerId: widget.customerId ?? '',
          invoiceId: widget.invoiceId ?? '',
          measurements: typedMeasurements,
          priority: _priority,
          deliveryDate: deliveryDate,
          notes: _notesCtrl.text,
        );
        await repository.updateTailoringRecord(existingRecord);
      } else {
        // Create new tailoring record
        final newRecord = TailoringRecord.create(
          tenantId: tenantId,
          customerId: widget.customerId ?? '',
          invoiceId: widget.invoiceId ?? '',
          measurements: typedMeasurements,
          priority: _priority,
          deliveryDate: deliveryDate,
          notes: _notesCtrl.text,
        );
        await repository.createTailoringRecord(newRecord);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingMeasurements != null
                  ? 'Measurements updated'
                  : 'Measurements saved',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving measurements: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.existingMeasurements != null
              ? 'Edit Measurements'
              : 'Take Measurements',
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
        actions: [
          ClothingSyncIndicator(
            repository: ClothingRepositoryOffline(sl(), sl<SessionManager>()),
          ),
          const SizedBox(width: 8),
          if (widget.existingMeasurements != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete measurements',
              onPressed: () => _showDeleteConfirmation(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Information
                    _buildSectionCard('Delivery Information', [
                      _buildDatePicker('Delivery Date', _deliveryDateCtrl),
                      const SizedBox(height: 16),
                      _buildPrioritySelector(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Notes',
                        _notesCtrl,
                        maxLines: 3,
                        optional: true,
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Body Measurements
                    _buildSectionCard('Body Measurements', [
                      _buildMeasurementGrid(),
                    ]),

                    const SizedBox(height: 24),

                    // Custom Notes
                    _buildSectionCard('Additional Notes', [
                      _buildTextField(
                        'Custom measurement notes or special requirements',
                        _customNotesCtrl,
                        maxLines: 4,
                        optional: true,
                      ),
                    ]),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveMeasurements,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.existingMeasurements != null
                              ? 'Update Measurements'
                              : 'Save Measurements',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildSectionCard(String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool optional = false,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${optional ? ' (Optional)' : ''}',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: optional
              ? null
              : (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter $label';
                  }
                  return validator?.call(value);
                },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: colorScheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementField(
    String label,
    TextEditingController controller, {
    String? unit,
    MeasurementKey? measurementKey,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Measurement field for $label',
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final number = double.tryParse(value);
                if (number == null) {
                  return 'Please enter a valid number for $label';
                }
                if (measurementKey != null) {
                  if (!ClothingBusinessRules.isValidMeasurement(
                    measurementKey,
                    number,
                  )) {
                    return '$label is out of valid range';
                  }
                } else {
                  // Fallback for fields without a MeasurementKey (e.g., Neck)
                  if (number <= 0) {
                    return 'Please enter a valid measurement for $label';
                  }
                }
              }
              return null;
            },
            decoration: InputDecoration(
              suffixText: unit ?? 'inches',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select a delivery date';
            }
            return null;
          },
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: colorScheme.surface,
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate:
                  DateTime.tryParse(controller.text) ??
                  DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              controller.text = date.toString().split(' ')[0];
            }
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Normal'),
                value: 'normal',
                groupValue: _priority,
                onChanged: (value) => setState(() => _priority = value!),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Urgent'),
                value: 'urgent',
                groupValue: _priority,
                onChanged: (value) => setState(() => _priority = value!),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Express'),
                value: 'express',
                groupValue: _priority,
                onChanged: (value) => setState(() => _priority = value!),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasurementGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMeasurementField(
                'Chest',
                _chestCtrl,
                measurementKey: MeasurementKey.chest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMeasurementField(
                'Waist',
                _waistCtrl,
                measurementKey: MeasurementKey.waist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMeasurementField(
                'Hips',
                _hipsCtrl,
                measurementKey: MeasurementKey.hip,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMeasurementField(
                'Length',
                _lengthCtrl,
                measurementKey: MeasurementKey.length,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMeasurementField(
                'Sleeve',
                _sleeveCtrl,
                measurementKey: MeasurementKey.sleeve,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMeasurementField(
                'Shoulder',
                _shoulderCtrl,
                measurementKey: MeasurementKey.shoulder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMeasurementField('Neck', _neckCtrl)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMeasurementField(
                'Inseam',
                _inseamCtrl,
                measurementKey: MeasurementKey.inseam,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Measurements'),
        content: const Text(
          'Are you sure you want to delete these measurements? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMeasurements();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeasurements() async {
    // Route through ClothingRepositoryOffline soft-delete (Req 9.5, 12.1)
    final existingId = widget.existingMeasurements?['id']?.toString();
    if (existingId == null || existingId.isEmpty) return;

    try {
      final repository = ClothingRepositoryOffline(sl(), sl<SessionManager>());
      await repository.initialize();
      await repository.deleteTailoringRecord(existingId);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Measurements deleted'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting measurements: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
