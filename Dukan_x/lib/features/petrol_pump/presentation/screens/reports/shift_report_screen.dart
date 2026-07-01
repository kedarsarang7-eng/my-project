import 'package:flutter/material.dart';
import '../../../../../../core/di/service_locator.dart';
import 'package:intl/intl.dart';
import '../../../models/shift.dart';
import '../../../services/shift_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ShiftReportScreen extends StatelessWidget {
  const ShiftReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shiftService = sl<ShiftService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Shift Summary Reports')),
      body: StreamBuilder<List<Shift>>(
        stream: shiftService.getShiftHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No closed shifts found.'));
          }

          final shifts = snapshot.data!;
          return ListView.builder(
            itemCount: shifts.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            shift.shiftName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: shift.status == ShiftStatus.open
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              shift.status == ShiftStatus.open
                                  ? 'Active'
                                  : 'Closed',
                              style: TextStyle(
                                color: shift.status == ShiftStatus.open
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(shift.startTime)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'Time: ${DateFormat('hh:mm a').format(shift.startTime)} - ${shift.endTime != null ? DateFormat('hh:mm a').format(shift.endTime!) : 'Now'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStat(
                            'Total Sales',
                            'â‚¹${shift.totalSaleAmount.toStringAsFixed(2)}',
                          ),
                          _buildStat(
                            'Litres Sold',
                            '${shift.totalLitresSold.toStringAsFixed(2)} L',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Collected:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      context.isMobile
                          ? SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMiniStat('Cash', shift.paymentBreakup.cash),
                                  _buildMiniStat('Online', shift.paymentBreakup.upi),
                                  _buildMiniStat('Card', shift.paymentBreakup.card),
                                  _buildMiniStat('Credit', shift.paymentBreakup.credit),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniStat('Cash', shift.paymentBreakup.cash),
                                _buildMiniStat('Online', shift.paymentBreakup.upi),
                                _buildMiniStat('Card', shift.paymentBreakup.card),
                                _buildMiniStat('Credit', shift.paymentBreakup.credit),
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

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, double val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          'â‚¹${val.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
