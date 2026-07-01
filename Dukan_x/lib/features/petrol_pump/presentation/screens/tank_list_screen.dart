import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../models/tank.dart';
import '../../services/tank_service.dart';
import '../dialogs/add_stock_dialog.dart';
import '../dialogs/dip_reading_dialog.dart';
import '../dialogs/add_tank_dialog.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TankListScreen extends StatefulWidget {
  const TankListScreen({super.key});

  @override
  State<TankListScreen> createState() => _TankListScreenState();
}

class _TankListScreenState extends State<TankListScreen> {
  final _tankService = sl<TankService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tank Stocks')),
      body: StreamBuilder<List<Tank>>(
        stream: _tankService.getTanks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tanks = snapshot.data ?? [];

          if (tanks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.propane_tank_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tanks configured',
                    style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ), color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first tank',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: BoundedBox(
              maxWidth: 600,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tanks.length,
                itemBuilder: (context, index) {
                  final tank = tanks[index];
                  final fillPercentage = tank.capacity > 0
                      ? (tank.currentStock / tank.capacity)
                      : 0.0;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tank.tankName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: responsiveValue<double>(context,
                        mobile: 14.0,
                        tablet: 16.0,
                        desktop: 18.0,
                      ),
                                ),
                              ),
                              Text(
                                tank.fuelTypeName ?? 'Fuel',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: fillPercentage,
                            backgroundColor: Colors.grey[200],
                            color: _getColorForLevel(fillPercentage),
                            minHeight: 10,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current: ${tank.currentStock.toStringAsFixed(2)} L',
                              ),
                              Text(
                                'Capacity: ${tank.capacity.toStringAsFixed(0)} L',
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Stock'),
                                onPressed: () => _showAddStockDialog(tank),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.straighten),
                                label: const Text('Dip Reading'),
                                onPressed: () => _showDipReadingDialog(tank),
                              ),
                            ],
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
        onPressed: _showAddTankDialog,
        tooltip: 'Add New Tank',
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getColorForLevel(double level) {
    if (level < 0.2) return FuturisticColors.error;
    if (level < 0.5) return Colors.orange;
    return FuturisticColors.success;
  }

  void _showAddStockDialog(Tank tank) {
    showDialog(
      context: context,
      builder: (context) => AddStockDialog(tank: tank),
    );
  }

  void _showDipReadingDialog(Tank tank) {
    showDialog(
      context: context,
      builder: (context) => DipReadingDialog(tank: tank),
    );
  }

  void _showAddTankDialog() {
    showDialog(context: context, builder: (context) => const AddTankDialog());
  }
}
