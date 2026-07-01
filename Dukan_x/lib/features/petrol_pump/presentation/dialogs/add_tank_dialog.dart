import 'package:flutter/material.dart';
import '../../models/tank.dart';
import '../../models/fuel_type.dart';
import '../../services/tank_service.dart';
import '../../services/fuel_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Dialog for adding a new fuel storage tank
class AddTankDialog extends StatefulWidget {
  const AddTankDialog({super.key});

  @override
  State<AddTankDialog> createState() => _AddTankDialogState();
}

class _AddTankDialogState extends State<AddTankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tankNameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _initialStockController = TextEditingController();

  String? _selectedFuelTypeId;
  String? _selectedFuelTypeName;
  List<FuelType> _fuelTypes = [];
  bool _isLoading = false;
  bool _isLoadingFuelTypes = true;

  @override
  void initState() {
    super.initState();
    _loadFuelTypes();
  }

  @override
  void dispose() {
    _tankNameController.dispose();
    _capacityController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _loadFuelTypes() async {
    try {
      final fuelService = sl<FuelService>();
      // Initialize defaults if needed
      await fuelService.initializeDefaultFuels();
      fuelService.getFuelTypes().listen((fuels) {
        if (mounted) {
          setState(() {
            _fuelTypes = fuels.where((f) => f.isActive).toList();
            _isLoadingFuelTypes = false;
            // Auto-select first fuel type if none selected
            if (_selectedFuelTypeId == null && _fuelTypes.isNotEmpty) {
              _selectedFuelTypeId = _fuelTypes.first.fuelId;
              _selectedFuelTypeName = _fuelTypes.first.fuelName;
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFuelTypes = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_circle, color: Colors.purple),
          ),
          const SizedBox(width: 12),
          const Text('Add New Tank', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: _isLoadingFuelTypes
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tank name input
                    TextFormField(
                      controller: _tankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tank Name',
                        hintText: 'e.g., Tank 1, Underground Tank A',
                        prefixIcon: Icon(Icons.propane_tank),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter tank name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fuel type dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedFuelTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Type',
                        prefixIcon: Icon(Icons.local_gas_station),
                        border: OutlineInputBorder(),
                      ),
                      items: _fuelTypes.map((fuel) {
                        return DropdownMenuItem<String>(
                          value: fuel.fuelId,
                          child: Text(fuel.fuelName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFuelTypeId = value;
                          _selectedFuelTypeName = _fuelTypes
                              .firstWhere((f) => f.fuelId == value)
                              .fuelName;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select fuel type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Capacity input
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tank Capacity',
                        hintText: 'Maximum storage capacity',
                        prefixIcon: Icon(Icons.storage),
                        border: OutlineInputBorder(),
                        suffix: Text('L'),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter capacity';
                        }
                        final capacity = double.tryParse(value);
                        if (capacity == null || capacity <= 0) {
                          return 'Please enter a valid capacity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Initial stock input
                    TextFormField(
                      controller: _initialStockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock (Optional)',
                        hintText: 'Current stock level',
                        prefixIcon: Icon(Icons.inventory),
                        border: OutlineInputBorder(),
                        suffix: Text('L'),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final stock = double.tryParse(value);
                          if (stock == null || stock < 0) {
                            return 'Please enter a valid stock level';
                          }
                          final capacity =
                              double.tryParse(_capacityController.text) ?? 0;
                          if (stock > capacity) {
                            return 'Cannot exceed capacity';
                          }
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
          onPressed: _isLoading || _isLoadingFuelTypes ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Create Tank'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      final capacity = double.parse(_capacityController.text);
      final initialStock = _initialStockController.text.isNotEmpty
          ? double.parse(_initialStockController.text)
          : 0.0;

      final tank = Tank(
        tankId: DateTime.now().millisecondsSinceEpoch.toString(),
        tankName: _tankNameController.text.trim(),
        fuelTypeId: _selectedFuelTypeId!,
        fuelTypeName: _selectedFuelTypeName,
        capacity: capacity,
        openingStock: initialStock,
        currentStock: initialStock,
        ownerId: ownerId,
      );

      await sl<TankService>().saveTank(tank);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tank "${tank.tankName}" created successfully'),
            backgroundColor: FuturisticColors.success,
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
