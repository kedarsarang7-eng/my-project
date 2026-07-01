import 'package:flutter/material.dart';
import '../../models/tank.dart';
import '../../services/tank_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Dialog for recording manual dip reading of fuel tank
/// Compares actual stock with system stock and logs variance
class DipReadingDialog extends StatefulWidget {
  final Tank tank;

  const DipReadingDialog({super.key, required this.tank});

  @override
  State<DipReadingDialog> createState() => _DipReadingDialogState();
}

class _DipReadingDialogState extends State<DipReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dipQuantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _dipQuantityController.dispose();
    super.dispose();
  }

  double get _enteredQuantity =>
      double.tryParse(_dipQuantityController.text) ?? 0;

  double get _variance => _enteredQuantity - widget.tank.currentStock;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.straighten, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dip Reading', style: TextStyle(fontSize: 18)),
                Text(
                  widget.tank.tankName,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System stock info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'System Stock',
                      '${widget.tank.currentStock.toStringAsFixed(2)} L',
                      Colors.blue,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Calculated Stock',
                      '${widget.tank.calculatedStock.toStringAsFixed(2)} L',
                      Colors.grey.shade700,
                    ),
                    const Divider(height: 16),
                    _buildInfoRow(
                      'Last Dip Reading',
                      widget.tank.lastDipReading != null
                          ? _formatDate(widget.tank.lastDipReading!)
                          : 'Never',
                      Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dip reading input
              TextFormField(
                controller: _dipQuantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Measured Dip Quantity',
                  hintText: 'Enter actual stock level',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                  suffix: Text('L'),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dip reading';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity < 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (quantity > widget.tank.capacity) {
                    return 'Cannot exceed tank capacity (${widget.tank.capacity.toStringAsFixed(0)} L)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Variance display
              if (_dipQuantityController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _variance < 0
                        ? FuturisticColors.error.withOpacity(0.1)
                        : _variance > 0
                        ? FuturisticColors.success.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _variance < 0
                          ? FuturisticColors.error.withOpacity(0.3)
                          : _variance > 0
                          ? FuturisticColors.success.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _variance < 0
                            ? Icons.trending_down
                            : _variance > 0
                            ? Icons.trending_up
                            : Icons.check_circle,
                        color: _variance < 0
                            ? FuturisticColors.error
                            : _variance > 0
                            ? FuturisticColors.success
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _variance < 0
                                  ? 'Stock Loss'
                                  : _variance > 0
                                  ? 'Stock Gain'
                                  : 'No Variance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _variance < 0
                                    ? FuturisticColors.error
                                    : _variance > 0
                                    ? FuturisticColors.success
                                    : Colors.grey,
                              ),
                            ),
                            Text(
                              '${_variance.abs().toStringAsFixed(2)} L',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _variance < 0
                                    ? FuturisticColors.error
                                    : _variance > 0
                                    ? FuturisticColors.success
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
          label: const Text('Record Reading'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actualStock = double.parse(_dipQuantityController.text);
      await sl<TankService>().recordDipReading(widget.tank.tankId, actualStock);

      if (mounted) {
        final varianceText = _variance < 0
            ? 'Loss: ${_variance.abs().toStringAsFixed(2)} L'
            : _variance > 0
            ? 'Gain: ${_variance.toStringAsFixed(2)} L'
            : 'No variance';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dip reading recorded. $varianceText'),
            backgroundColor: _variance < 0
                ? Colors.orange
                : FuturisticColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: \$e'),
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
