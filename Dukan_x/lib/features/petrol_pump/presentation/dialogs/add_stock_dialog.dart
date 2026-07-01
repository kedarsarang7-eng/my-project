import 'package:flutter/material.dart';
import '../../models/tank.dart';
import '../../services/tank_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Dialog for adding stock (purchase) to a fuel tank
class AddStockDialog extends StatefulWidget {
  final Tank tank;

  const AddStockDialog({super.key, required this.tank});

  @override
  State<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<AddStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
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
              color: FuturisticColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add, color: FuturisticColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Stock', style: TextStyle(fontSize: 18)),
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
              // Current stock info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${widget.tank.currentStock.toStringAsFixed(2)} L',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Available Capacity',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${widget.tank.availableCapacity.toStringAsFixed(2)} L',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: FuturisticColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantity input
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantity (Litres)',
                  hintText: 'Enter quantity to add',
                  prefixIcon: Icon(Icons.local_gas_station),
                  border: OutlineInputBorder(),
                  suffix: Text('L'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (quantity > widget.tank.availableCapacity) {
                    return 'Exceeds available capacity (${widget.tank.availableCapacity.toStringAsFixed(0)} L)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Purchase price input
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Purchase Price per Litre (Optional)',
                  hintText: 'Enter price',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                  prefix: Text('₹ '),
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Purchase Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
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
              : const Icon(Icons.add),
          label: const Text('Add Stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FuturisticColors.success,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final quantity = double.parse(_quantityController.text);
      await sl<TankService>().addPurchase(widget.tank.tankId, quantity);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${quantity.toStringAsFixed(2)} L to ${widget.tank.tankName}',
            ),
            backgroundColor: FuturisticColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
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
