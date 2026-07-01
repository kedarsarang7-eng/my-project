import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import '../../../models/tank.dart';
import '../../../services/tank_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TankStockReportScreen extends StatelessWidget {
  const TankStockReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tankService = sl<TankService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tank Stock Status')),
      body: StreamBuilder<List<Tank>>(
        stream: tankService.getTanks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tanks configured.'));
          }

          final tanks = snapshot.data!;
          return ListView.builder(
            itemCount: tanks.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final tank = tanks[index];
              final percentage = (tank.currentStock / tank.capacity).clamp(
                0.0,
                1.0,
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tank.tankName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tank.fuelTypeName ?? 'Fuel',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[200],
                        color: percentage < 0.2 ? Colors.red : Colors.green,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${tank.currentStock.toStringAsFixed(1)} L Available',
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(1)}% Full',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      context.isMobile
                          ? SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _detailItem(
                                    'Capacity',
                                    '${tank.capacity.toStringAsFixed(0)} L',
                                  ),
                                  _detailItem(
                                    'Opening Stock',
                                    '${tank.openingStock.toStringAsFixed(1)} L',
                                  ),
                                  _detailItem(
                                    'Purchases',
                                    '+${tank.purchaseQuantity.toStringAsFixed(1)} L',
                                  ),
                                  _detailItem(
                                    'Sold',
                                    '-${tank.salesDeduction.toStringAsFixed(1)} L',
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _detailItem(
                                  'Capacity',
                                  '${tank.capacity.toStringAsFixed(0)} L',
                                ),
                                _detailItem(
                                  'Opening Stock',
                                  '${tank.openingStock.toStringAsFixed(1)} L',
                                ),
                                _detailItem(
                                  'Purchases',
                                  '+${tank.purchaseQuantity.toStringAsFixed(1)} L',
                                ),
                                _detailItem(
                                  'Sold',
                                  '-${tank.salesDeduction.toStringAsFixed(1)} L',
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _detailItem(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
