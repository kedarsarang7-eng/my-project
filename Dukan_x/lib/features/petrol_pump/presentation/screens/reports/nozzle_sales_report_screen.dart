import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../models/nozzle.dart';
import '../../../services/dispenser_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class NozzleSalesReportScreen extends StatelessWidget {
  const NozzleSalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = sl<DispenserService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Nozzle Sales (Current)')),
      body: StreamBuilder<List<Nozzle>>(
        stream: service.getAllNozzles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No Nozzles Found'));
          }

          final nozzles = snapshot.data!;
          return ListView.builder(
            itemCount: nozzles.length,
            itemBuilder: (ctx, idx) {
              final n = nozzles[idx];
              return ListTile(
                title: Text('Nozzle: ${n.nozzleId}'),
                subtitle: Text(
                  'Sales: ${n.calculatedSaleLitres.toStringAsFixed(2)} L',
                ),
                trailing: Text(n.fuelTypeName ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
