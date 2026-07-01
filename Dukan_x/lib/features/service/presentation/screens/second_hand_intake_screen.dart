/// Second-Hand Intake Screen
/// Captures device identity, condition, grade, and valuation for used-phone
/// buyback. Stores valuation as integer Paise and generates a RID identifier.
///
/// Requirements: 9.1, 9.2, 9.3, 1.1, 1.2, 1.3, 1.4
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/rid_generator.dart';
import '../../data/repositories/imei_serial_repository.dart';
import '../../models/imei_serial.dart';

/// Predefined finite set of device conditions (Requirement 9.1).
const List<String> kSecondHandConditions = [
  'excellent',
  'good',
  'fair',
  'poor',
];

/// Predefined finite set of device grades (Requirement 9.1).
const List<String> kSecondHandGrades = ['A', 'B', 'C', 'D'];

/// Second-Hand Intake Screen — captures device identity, condition, grade,
/// and valuation for a used-phone buyback scoped by Tenant_Id.
///
/// Validation:
///   - All required fields must be non-empty.
///   - Condition must be from [kSecondHandConditions].
///   - Grade must be from [kSecondHandGrades].
///   - Valuation in Rupees is converted to integer Paise (×100) and must be
///     in the inclusive range [1, 99999999999].
///   - On invalid: reject submission, create no record, name the offending field.
///
/// On valid submission:
///   - Generate RID: `{tenantId}-{timestamp_ms}-{uuid_v4_short}` (≥8 chars).
///   - Create an IMEISerial record with status `inStock`, the RID as id,
///     userId from session, and the condition/grade/valuationPaise fields.
///   - Abort with error if tenantId is null/empty.
class SecondHandIntakeScreen extends StatefulWidget {
  const SecondHandIntakeScreen({super.key});

  @override
  State<SecondHandIntakeScreen> createState() => _SecondHandIntakeScreenState();
}

class _SecondHandIntakeScreenState extends State<SecondHandIntakeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _deviceNameController = TextEditingController();
  final _imeiSerialController = TextEditingController();
  final _valuationController = TextEditingController();
  final _notesController = TextEditingController();

  // Dropdown values
  String? _selectedCondition;
  String? _selectedGrade;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _deviceNameController.dispose();
    _imeiSerialController.dispose();
    _valuationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Converts a Rupee string to integer Paise.
  /// Returns null if the value is invalid or out of range.
  int? _rupeesToPaise(String rupeesStr) {
    final trimmed = rupeesStr.trim();
    if (trimmed.isEmpty) return null;

    // Parse as a number, handling potential decimal input by converting
    // strictly to integer Paise. We accept integer Rupee values only to
    // avoid floating-point issues (Requirement 1.1, 1.2).
    final rupees = int.tryParse(trimmed);
    if (rupees == null || rupees <= 0) return null;

    final paise = rupees * 100;
    // Inclusive range check: 1 .. 99,999,999,999 (Requirement 9.3)
    if (paise < 1 || paise > 99999999999) return null;
    return paise;
  }

  /// Validates and submits the form, creating an IMEISerial record.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional programmatic validation for dropdowns (belt-and-suspenders
    // beyond the DropdownButtonFormField validator).
    if (_selectedCondition == null ||
        !kSecondHandConditions.contains(_selectedCondition)) {
      _showError(
        'Condition is required and must be one of: '
        '${kSecondHandConditions.join(", ")}',
      );
      return;
    }
    if (_selectedGrade == null || !kSecondHandGrades.contains(_selectedGrade)) {
      _showError(
        'Grade is required and must be one of: ${kSecondHandGrades.join(", ")}',
      );
      return;
    }

    // Resolve tenant
    final session = sl<SessionManager>();
    final tenantId = session.ownerId;
    if (tenantId == null || tenantId.trim().isEmpty) {
      _showError(
        'Cannot create record: Tenant ID is missing or unresolved. '
        'Please log in again.',
      );
      return;
    }

    // Convert valuation to Paise
    final valuationPaise = _rupeesToPaise(_valuationController.text);
    if (valuationPaise == null) {
      // This should be caught by the form validator, but double-check here.
      _showError(
        'Valuation: must be a positive whole-number amount in Rupees '
        'resulting in 1–99,999,999,999 Paise.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Generate RID: {tenantId}-{timestamp_ms}-{uuid_v4_short}
      final rid = RidGenerator.next(tenantId);
      final userId = session.userId ?? tenantId;
      final now = DateTime.now();

      // Build the IMEISerial record for the second-hand intake
      final record = IMEISerial(
        id: rid,
        userId: userId,
        productId: '', // No linked product yet for intake
        imeiOrSerial: _imeiSerialController.text.trim(),
        type: IMEISerialType.imei,
        status: IMEISerialStatus.inStock,
        purchasePrice: valuationPaise.toDouble(), // stored as paise value
        purchaseDate: now,
        productName: _deviceNameController.text.trim(),
        notes: _buildNotes(),
        createdAt: now,
        updatedAt: now,
      );

      // Persist via the existing IMEISerialRepository
      final repo = IMEISerialRepository(sl());
      await repo.createIMEISerial(record);

      if (!mounted) return;

      // Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Second-hand device recorded (RID: $rid)'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
      _deviceNameController.clear();
      _imeiSerialController.clear();
      _valuationController.clear();
      _notesController.clear();
      setState(() {
        _selectedCondition = null;
        _selectedGrade = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save record: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Builds the notes string encoding condition, grade, and valuationPaise
  /// so that they are persisted with the record (the IMEISerial model does not
  /// have dedicated condition/grade/valuationPaise columns until the Mini_Gate
  /// is granted — Task 13.1).
  String _buildNotes() {
    final parts = <String>[];
    if (_selectedCondition != null) {
      parts.add('condition:$_selectedCondition');
    }
    if (_selectedGrade != null) {
      parts.add('grade:$_selectedGrade');
    }
    final paise = _rupeesToPaise(_valuationController.text);
    if (paise != null) {
      parts.add('valuationPaise:$paise');
    }
    final userNotes = _notesController.text.trim();
    if (userNotes.isNotEmpty) {
      parts.add(userNotes);
    }
    return parts.join(' | ');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Second-Hand Intake'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Record Used Device',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture device details for second-hand buyback inventory.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Device Name / Model (required)
                  TextFormField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Device Name / Model *',
                      hintText: 'e.g. iPhone 13, Samsung Galaxy S22',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Device Name is required';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // IMEI / Serial (required for mobileShop)
                  TextFormField(
                    controller: _imeiSerialController,
                    decoration: const InputDecoration(
                      labelText: 'IMEI / Serial Number *',
                      hintText: 'Enter the device IMEI or serial number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fingerprint),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'IMEI/Serial is required';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Condition dropdown (required, from predefined set)
                  DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    decoration: const InputDecoration(
                      labelText: 'Condition *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.health_and_safety),
                    ),
                    items: kSecondHandConditions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c[0].toUpperCase() + c.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCondition = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Condition is required';
                      }
                      if (!kSecondHandConditions.contains(value)) {
                        return 'Condition must be one of: '
                            '${kSecondHandConditions.join(", ")}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Grade dropdown (required, from predefined set)
                  DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grade),
                    ),
                    items: kSecondHandGrades
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text('Grade $g'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedGrade = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Grade is required';
                      }
                      if (!kSecondHandGrades.contains(value)) {
                        return 'Grade must be one of: '
                            '${kSecondHandGrades.join(", ")}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Valuation in Rupees (converted to integer Paise internally)
                  TextFormField(
                    controller: _valuationController,
                    decoration: const InputDecoration(
                      labelText: 'Valuation (₹) *',
                      hintText: 'Enter amount in whole Rupees',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Valuation is required';
                      }
                      final rupees = int.tryParse(value.trim());
                      if (rupees == null || rupees <= 0) {
                        return 'Valuation must be a positive whole number';
                      }
                      final paise = rupees * 100;
                      if (paise < 1 || paise > 99999999999) {
                        return 'Valuation in Paise must be between 1 and '
                            '99,999,999,999 (i.e. ₹0.01–₹99,99,99,999.99)';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Notes (optional)
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Any additional remarks',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSubmitting ? 'Saving...' : 'Record Intake'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: theme.textTheme.titleMedium,
                    ),
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
