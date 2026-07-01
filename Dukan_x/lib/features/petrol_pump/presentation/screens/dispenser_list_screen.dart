import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../models/dispenser.dart';
import '../../models/nozzle.dart';
import '../../services/dispenser_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DispenserListScreen extends StatefulWidget {
  const DispenserListScreen({super.key});

  @override
  State<DispenserListScreen> createState() => _DispenserListScreenState();
}

class _DispenserListScreenState extends State<DispenserListScreen> {
  final _dispenserService = sl<DispenserService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispensers & Nozzles')),
      body: StreamBuilder<List<Dispenser>>(
        stream: _dispenserService.getDispensers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dispensers = snapshot.data ?? [];
          if (dispensers.isEmpty) {
            return const Center(child: Text('No dispensers added.'));
          }

          return Center(
            child: BoundedBox(
              maxWidth: 600,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: dispensers.length,
                itemBuilder: (context, index) {
                  final dispenser = dispensers[index];
                  return _buildDispenserCard(dispenser);
                },
              ),
            ),
          );
        },
      ),
      // FAB removed until Add Dispenser is fully implemented
    );
  }

  Widget _buildDispenserCard(Dispenser dispenser) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(
              Icons.settings_input_component,
              color: Colors.blue,
            ),
            title: Text(
              dispenser.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // Add Nozzle button removed until fully implemented
          ),
          const Divider(),
          // Nozzles List
          StreamBuilder<List<Nozzle>>(
            stream: _dispenserService.getNozzlesByDispenser(
              dispenser.dispenserId,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final nozzles = snapshot.data ?? [];

              if (nozzles.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No nozzles attached',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nozzles.length,
                itemBuilder: (context, i) {
                  final nozzle = nozzles[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_gas_station, size: 20),
                    title: Text('Nozzle: ${nozzle.fuelTypeName ?? "Fuel"}'),
                    subtitle: Text(
                      'Current Reading: ${nozzle.closingReading.toStringAsFixed(2)}',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
