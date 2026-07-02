import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/eway_rules.dart';
import '../../domain/validation_result.dart';

/// Callback when the user submits a valid e-Way capture form.
typedef EWayCaptureCallback = void Function(EWayCapture capture);

/// E-Way Bill capture form widget.
///
/// Captures the four required fields for an e-Way bill:
/// - Transporter name
/// - Approximate distance (km)
/// - Vehicle number
/// - Party GSTIN (15-char alphanumeric)
///
/// Shows a clear "BLOCKED" notice since GSP credentials are unavailable
/// (Phase 0 §5: External_Dependency_Gate = GSP_Credentials-unavailable).
/// Does NOT submit to any API — only captures and validates locally.
///
/// (Phase 9, Task 19.2; Requirements 12.3, 12.4)
class EWayCaptureForm extends StatefulWidget {
  /// Called when all fields pass validation.
  final EWayCaptureCallback? onCapture;

  /// The consignment amount in paise (displayed for context).
  final int consignmentPaise;

  /// Whether the movement is inter-state.
  final bool interState;

  const EWayCaptureForm({
    super.key,
    this.onCapture,
    required this.consignmentPaise,
    required this.interState,
  });

  @override
  State<EWayCaptureForm> createState() => _EWayCaptureFormState();
}

class _EWayCaptureFormState extends State<EWayCaptureForm> {
  final _formKey = GlobalKey<FormState>();
  final _transporterController = TextEditingController();
  final _distanceController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _gstinController = TextEditingController();

  final _ewayRules = const EWayRules();

  @override
  void dispose() {
    _transporterController.dispose();
    _distanceController.dispose();
    _vehicleController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final capture = EWayCapture(
      transporterName: _transporterController.text.trim(),
      approxDistanceKm: int.tryParse(_distanceController.text.trim()) ?? 0,
      vehicleNumber: _vehicleController.text.trim(),
      partyGstin: _gstinController.text.trim(),
    );

    // Double-check with domain validation.
    final result = _ewayRules.validateCapture(capture);
    if (result.isInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result as ValidationFailure).reason),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onCapture?.call(capture);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── BLOCKED notice ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.error.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'E-Way generation is BLOCKED (GSP credentials unavailable)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Consignment info ─────────────────────────────────────────
          Text(
            'Consignment: ₹${(widget.consignmentPaise / 100).toStringAsFixed(2)} '
            '(${widget.interState ? "Inter-state" : "Intra-state"})',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Transporter Name ─────────────────────────────────────────
          TextFormField(
            controller: _transporterController,
            decoration: const InputDecoration(
              labelText: 'Transporter Name',
              hintText: 'Enter transporter / transport company name',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Transporter name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ─── Approximate Distance (km) ────────────────────────────────
          TextFormField(
            controller: _distanceController,
            decoration: const InputDecoration(
              labelText: 'Approx. Distance (km)',
              hintText: 'Enter approximate distance in kilometres',
              prefixIcon: Icon(Icons.straighten_outlined),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Distance is required';
              }
              final km = int.tryParse(value.trim());
              if (km == null || km <= 0) {
                return 'Distance must be greater than 0 km';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ─── Vehicle Number ───────────────────────────────────────────
          TextFormField(
            controller: _vehicleController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Number',
              hintText: 'e.g. MH12AB1234',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vehicle number is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // ─── Party GSTIN ──────────────────────────────────────────────
          TextFormField(
            controller: _gstinController,
            decoration: const InputDecoration(
              labelText: 'Party GSTIN',
              hintText: '15-character alphanumeric GSTIN',
              prefixIcon: Icon(Icons.assignment_outlined),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Party GSTIN is required';
              }
              final gstin = value.trim();
              if (gstin.length != 15) {
                return 'GSTIN must be exactly 15 characters';
              }
              if (!RegExp(r'^[A-Za-z0-9]{15}$').hasMatch(gstin)) {
                return 'GSTIN must be alphanumeric only';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ─── Capture button ───────────────────────────────────────────
          FilledButton.icon(
            onPressed: _onSubmit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Capture E-Way Details'),
          ),
        ],
      ),
    );
  }
}
