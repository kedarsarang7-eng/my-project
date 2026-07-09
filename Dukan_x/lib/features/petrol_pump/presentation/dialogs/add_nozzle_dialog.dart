import 'package:flutter/material.dart';
import '../../models/dispenser.dart';
import '../../models/nozzle.dart';
import '../../models/fuel_type.dart';
import '../../models/tank.dart';
import '../../services/dispenser_service.dart';
import '../../services/fuel_service.dart';
import '../../services/tank_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';

/// Dialog for adding a nozzle to a dispenser
class AddNozzleDialog extends StatefulWidget {
  final Dispenser dispenser;

  const AddNozzleDialog({super.key, required this.dispenser});

  @override
  State<AddNozzleDialog> createState() => _AddNozzleDialogState();
}

class _AddNozzleDialogState extends State<AddNozzleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  List<FuelType> _fuelTypes = [];
  List<Tank> _tanks = [];
  String? _selectedFuelTypeId;
  String? _selectedFuelTypeName;
  String? _selectedTankId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final fuelService = sl<FuelService>();
      final tankService = sl<TankService>();

      await fuelService.initializeDefaultFuels();

      fuelService.getFuelTypes().listen((fuels) {
        if (mounted) {
          setState(() {
            _fuelTypes = fuels.where((f) => f.isActive).toList();
            if (_selectedFuelTypeId == null && _fuelTypes.isNotEmpty) {
              _selectedFuelTypeId = _fuelTypes.first.fuelId;
              _selectedFuelTypeName = _fuelTypes.first.fuelName;
            }
          });
        }
      });

      tankService.getTanks().listen((tanks) {
        if (mounted) {
          setState(() {
            _tanks = tanks.where((t) => t.isActive).toList();
            if (_selectedTankId == null && _tanks.isNotEmpty) {
              _selectedTankId = _tanks.first.tankId;
            }
            _isLoadingData = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
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
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_gas_station, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Nozzle', style: TextStyle(fontSize: 18)),
                Text(
                  widget.dispenser.name,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: _isLoadingData
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

                    // Tank link dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedTankId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Tank',
                        prefixIcon: Icon(Icons.propane_tank),
                        border: OutlineInputBorder(),
                      ),
                      items: _tanks.map((tank) {
                        return DropdownMenuItem<String>(
                          value: tank.tankId,
                          child: Text(tank.tankName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTankId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a tank';
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
          onPressed: _isLoading || _isLoadingData ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Add Nozzle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
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
      final nozzle = Nozzle(
        nozzleId: DateTime.now().millisecondsSinceEpoch.toString(),
        dispenserId: widget.dispenser.dispenserId,
        fuelTypeId: _selectedFuelTypeId!,
        fuelTypeName: _selectedFuelTypeName,
        linkedTankId: _selectedTankId,
        ownerId: ownerId,
      );

      await sl<DispenserService>().saveNozzle(nozzle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nozzle added to "${widget.dispenser.name}"'),
            backgroundColor: FuturisticColors.success,
          ),
        );
        Navigator.pop(context, true);
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
