import 'package:flutter/material.dart';
import '../../models/nozzle.dart';
import '../../services/dispenser_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Dialog for recording opening/closing meter readings for a nozzle.
/// Requires an employeeId for audit-trail permission enforcement.
class NozzleReadingDialog extends StatefulWidget {
  final Nozzle nozzle;

  const NozzleReadingDialog({super.key, required this.nozzle});

  @override
  State<NozzleReadingDialog> createState() => _NozzleReadingDialogState();
}

class _NozzleReadingDialogState extends State<NozzleReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _openingReadingController = TextEditingController();
  final _closingReadingController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _openingReadingController.text = widget.nozzle.openingReading
        .toStringAsFixed(2);
    _closingReadingController.text = widget.nozzle.closingReading
        .toStringAsFixed(2);
  }

  @override
  void dispose() {
    _openingReadingController.dispose();
    _closingReadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.speed, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nozzle Reading', style: TextStyle(fontSize: 18)),
                Text(
                  widget.nozzle.fuelTypeName ?? 'Nozzle',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current reading info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'Current Opening',
                      widget.nozzle.openingReading.toStringAsFixed(2),
                      Colors.blue,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Current Closing',
                      widget.nozzle.closingReading.toStringAsFixed(2),
                      Colors.green,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Dispensed',
                      widget.nozzle.calculatedSaleLitres.toStringAsFixed(2),
                      Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Opening reading input
              TextFormField(
                controller: _openingReadingController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening Reading',
                  hintText: 'Enter opening meter reading',
                  prefixIcon: Icon(Icons.start),
                  border: OutlineInputBorder(),
                  suffix: Text('L'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter opening reading';
                  }
                  final reading = double.tryParse(value);
                  if (reading == null || reading < 0) {
                    return 'Please enter a valid reading';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Closing reading input
              TextFormField(
                controller: _closingReadingController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Closing Reading',
                  hintText: 'Enter closing meter reading',
                  prefixIcon: Icon(Icons.stop),
                  border: OutlineInputBorder(),
                  suffix: Text('L'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter closing reading';
                  }
                  final reading = double.tryParse(value);
                  if (reading == null || reading < 0) {
                    return 'Please enter a valid reading';
                  }
                  final opening =
                      double.tryParse(_openingReadingController.text) ?? 0;
                  if (reading < opening) {
                    return 'Closing reading cannot be less than opening';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Save Readings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dispenserService = sl<DispenserService>();
      final sessionManager = sl<SessionManager>();
      final employeeId = sessionManager.userId ?? sessionManager.ownerId ?? '';
      final shiftId = widget.nozzle.linkedShiftId ?? '';

      final openingReading = double.parse(_openingReadingController.text);
      final closingReading = double.parse(_closingReadingController.text);

      // Update opening reading
      await dispenserService.updateOpeningReading(
        widget.nozzle.nozzleId,
        openingReading,
        shiftId,
        employeeId: employeeId,
      );

      // Update closing reading
      await dispenserService.updateClosingReading(
        widget.nozzle.nozzleId,
        closingReading,
        employeeId: employeeId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Readings updated: ${openingReading.toStringAsFixed(2)} → ${closingReading.toStringAsFixed(2)}',
            ),
            backgroundColor: FuturisticColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } on PermissionDeniedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
