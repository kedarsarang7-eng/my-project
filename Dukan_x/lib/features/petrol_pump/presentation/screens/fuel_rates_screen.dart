import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../models/fuel_type.dart';
import '../../services/fuel_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class FuelRatesScreen extends StatefulWidget {
  const FuelRatesScreen({super.key});

  @override
  State<FuelRatesScreen> createState() => _FuelRatesScreenState();
}

class _FuelRatesScreenState extends State<FuelRatesScreen> {
  final _fuelService = sl<FuelService>();

  @override
  void initState() {
    super.initState();
    // Initialize defaults if empty (silent check)
    _fuelService.initializeDefaultFuels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Configuration')),
      body: StreamBuilder<List<FuelType>>(
        stream: _fuelService.getFuelTypes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final fuels = snapshot.data ?? [];
          if (fuels.isEmpty) {
            return const Center(child: Text('No fuel types found.'));
          }

          return Center(
            child: BoundedBox(
              maxWidth: 600,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fuels.length,
                itemBuilder: (context, index) {
                  final fuel = fuels[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_gas_station, size: 32),
                      title: Text(
                        fuel.fuelName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('GST: ${fuel.linkedGSTRate}%'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${fuel.currentRatePerLitre.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: responsiveValue<double>(context,
                        mobile: 14.0,
                        tablet: 16.0,
                        desktop: 18.0,
                      ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'per litre',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showUpdateRateDialog(context, fuel),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add custom fuel type logic
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showUpdateRateDialog(
    BuildContext context,
    FuelType fuel,
  ) async {
    final controller = TextEditingController(
      text: fuel.currentRatePerLitre.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${fuel.fuelName} Rate'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Rate (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(controller.text);
              if (newRate != null) {
                await _fuelService.updateFuelRate(fuel.fuelId, newRate);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
