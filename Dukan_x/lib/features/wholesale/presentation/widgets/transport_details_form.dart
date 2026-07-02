// ============================================================================
// TRANSPORT DETAILS FORM — WHOLESALE DISPATCH/CHALLAN SURFACE
// ============================================================================
// Surfaces vehicle number, LR number, and transporter name for delivery
// challan / dispatch when `useTransportDetails` capability is granted.
//
// Validates required fields (vehicleNumber, transporterName) on submit.
// Emits the validated TransportDetails on success.
//
// Author: DukanX Engineering
// Requirements: 8.2, 8.5, 8.6
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../domain/transport_details.dart';
import '../../domain/transport_validator.dart';
import '../../domain/validation_result.dart';

/// A form widget that captures Transport_Details for a delivery challan.
///
/// Only surfaced when the `useTransportDetails` capability is granted.
/// The caller is responsible for gating visibility.
///
/// On submit:
/// - Validates that vehicleNumber and transporterName are non-empty.
/// - If valid, calls [onSubmit] with a partial [TransportDetails] (id and
///   tenantId are assigned by the repository on save).
/// - If invalid, shows inline validation errors and persists nothing.
class TransportDetailsForm extends StatefulWidget {
  /// Called when the form passes validation with the entered details.
  ///
  /// The [TransportDetails] passed here will have placeholder id/tenantId —
  /// the repository assigns the real RID and tenant scope on save.
  final ValueChanged<TransportDetails>? onSubmit;

  /// The linked challan id for this transport record.
  final String linkedChallanId;

  /// Optional initial values for editing an existing transport record.
  final TransportDetails? initialValue;

  const TransportDetailsForm({
    super.key,
    this.onSubmit,
    required this.linkedChallanId,
    this.initialValue,
  });

  @override
  State<TransportDetailsForm> createState() => _TransportDetailsFormState();
}

class _TransportDetailsFormState extends State<TransportDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  static const _validator = TransportValidator();

  late final TextEditingController _vehicleController;
  late final TextEditingController _lrController;
  late final TextEditingController _transporterController;

  @override
  void initState() {
    super.initState();
    _vehicleController = TextEditingController(
      text: widget.initialValue?.vehicleNumber ?? '',
    );
    _lrController = TextEditingController(
      text: widget.initialValue?.lrNumber ?? '',
    );
    _transporterController = TextEditingController(
      text: widget.initialValue?.transporterName ?? '',
    );
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _lrController.dispose();
    _transporterController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    // Run domain validation.
    final result = _validator.validate(
      vehicleNumber: _vehicleController.text,
      transporterName: _transporterController.text,
      lrNumber: _lrController.text,
    );

    if (result.isInvalid) {
      // Trigger Flutter form-level validation to show inline errors.
      _formKey.currentState?.validate();
      return;
    }

    // Also trigger Flutter validation (should pass since domain passed).
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Emit a TransportDetails with placeholder id/tenantId — the repository
    // will assign the real values on save.
    final details = TransportDetails(
      id: '', // assigned by repository via RidGenerator
      tenantId: '', // assigned by repository via withTenant
      vehicleNumber: _vehicleController.text.trim(),
      lrNumber: _lrController.text.trim(),
      transporterName: _transporterController.text.trim(),
      linkedChallanId: widget.linkedChallanId,
      createdAt: DateTime.now(),
    );

    widget.onSubmit?.call(details);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.primary.withOpacity(0.08)
            : FuturisticColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.primary.withOpacity(0.2)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: FuturisticColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Transport Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle Number (required)
            TextFormField(
              controller: _vehicleController,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: _buildInputDecoration(
                'Vehicle Number *',
                Icons.directions_car_outlined,
                isDark,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vehicle number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Transporter Name (required)
            TextFormField(
              controller: _transporterController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: _buildInputDecoration(
                'Transporter Name *',
                Icons.business_outlined,
                isDark,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Transporter name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // LR Number (optional)
            TextFormField(
              controller: _lrController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: _buildInputDecoration(
                'LR Number (optional)',
                Icons.receipt_long_outlined,
                isDark,
              ),
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Transport Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    bool isDark,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: FuturisticColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
