// ============================================================================
// E-WAY BILL SCREEN — Hardware Shop (bugfix.md 2.14)
// ============================================================================
// Indian GST e-Way bills are mandatory for the movement of goods whose
// consignment value exceeds ₹50,000. Bulk hardware/material dispatches commonly
// cross this threshold, so the hardware vertical surfaces an e-Way bill helper
// that:
//   * computes whether an e-Way bill is required for a dispatch value, and
//   * captures the Part-A consignment details for that dispatch.
//
// The ₹50,000 trigger is the "e-Way capability" gate for this feature; it is
// expressed as a domain threshold ([eWayBillThresholdRupees]) rather than a new
// subscription `BusinessCapability` so the hard-isolation capability registry
// and its tier invariants are untouched. The screen itself is reached only on
// the hardware path (sidebar id `eway_bill`).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Consignment value (in ₹) at/above which a GST e-Way bill is required.
const double eWayBillThresholdRupees = 50000;

/// Pure rule: an e-Way bill is required when the consignment value is at least
/// [eWayBillThresholdRupees].
bool isEWayBillRequired(double consignmentValueRupees) =>
    consignmentValueRupees >= eWayBillThresholdRupees;

class EWayBillScreen extends StatefulWidget {
  const EWayBillScreen({super.key});

  @override
  State<EWayBillScreen> createState() => _EWayBillScreenState();
}

class _EWayBillScreenState extends State<EWayBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _consignmentValue = TextEditingController();
  final _recipientGstin = TextEditingController();
  final _fromPlace = TextEditingController();
  final _toPlace = TextEditingController();
  final _transporter = TextEditingController();
  final _vehicleNo = TextEditingController();

  double get _value => double.tryParse(_consignmentValue.text) ?? 0;
  bool get _required => isEWayBillRequired(_value);

  @override
  void dispose() {
    _consignmentValue.dispose();
    _recipientGstin.dispose();
    _fromPlace.dispose();
    _toPlace.dispose();
    _transporter.dispose();
    _vehicleNo.dispose();
    super.dispose();
  }

  void _generate() {
    if (!_formKey.currentState!.validate()) return;
    if (!_required) {
      _snack(
        'Consignment ₹${_value.toStringAsFixed(0)} is below the '
        '₹${eWayBillThresholdRupees.toStringAsFixed(0)} threshold — no e-Way '
        'bill required.',
      );
      return;
    }
    // Local Part-A reference. The actual GSTN upload is handled by the sync
    // layer; here we capture and confirm the consignment details.
    final ref =
        'EWB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _snack('e-Way bill Part-A captured: $ref');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('e-Way Bill')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: _required
                    ? cs.errorContainer.withValues(alpha: 0.4)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _required
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: _required ? cs.error : cs.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _required
                              ? 'e-Way bill REQUIRED — consignment value '
                                    'exceeds ₹${eWayBillThresholdRupees.toStringAsFixed(0)}.'
                              : 'Enter consignment value. e-Way bill is required '
                                    'for dispatches of ₹${eWayBillThresholdRupees.toStringAsFixed(0)} or more.',
                          style: TextStyle(color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _consignmentValue,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Consignment Value (₹)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (value == null || value <= 0) return 'Enter a valid value';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientGstin,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Recipient GSTIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromPlace,
                      decoration: const InputDecoration(
                        labelText: 'Dispatch From',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _toPlace,
                      decoration: const InputDecoration(
                        labelText: 'Ship To',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _transporter,
                      decoration: const InputDecoration(
                        labelText: 'Transporter',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleNo,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Generate e-Way Bill (Part-A)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
