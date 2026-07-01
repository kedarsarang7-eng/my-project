import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../../../core/di/service_locator.dart';

class PetrolPumpDashboardWidgets extends StatelessWidget {
  const PetrolPumpDashboardWidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildShiftStatusCard(context),
        const SizedBox(height: 12),
        _buildFuelRatesTicker(context),
        const SizedBox(height: 12),
        _buildTankStatusSummary(context),
      ],
    );
  }

  Widget _buildShiftStatusCard(BuildContext context) {
    return StreamBuilder<List<Shift>>(
      stream: sl<ShiftService>().getShiftHistory(limit: 1),
      builder: (context, snapshot) {
        final shifts = snapshot.data ?? [];
        final activeShift = shifts.isNotEmpty && shifts.first.status.isOpen
            ? shifts.first
            : null;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: activeShift != null
              ? FuturisticColors.paidBackground
              : FuturisticColors.unpaidBackground,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activeShift != null
                        ? FuturisticColors.success
                        : FuturisticColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activeShift != null
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeShift != null ? 'Active Shift' : 'Shift Closed',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (activeShift != null) ...[
                        Text(
                          '${activeShift.shiftName} • Started ${activeShift.startTime.hour}:${activeShift.startTime.minute}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ] else
                        Text(
                          'Tap to open a new shift',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Shift Management
                    // Navigator.pushNamed(context, '/petrol_pump/shift_management');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeShift != null
                        ? FuturisticColors.success
                        : Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(activeShift != null ? 'Manage' : 'Open Shift'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuelRatesTicker(BuildContext context) {
    return StreamBuilder<List<FuelType>>(
      stream: sl<FuelService>().getFuelTypes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            separatorBuilder: (c, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final fuel = snapshot.data![index];
              return Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fuel.fuelName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${fuel.currentRatePerLitre.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTankStatusSummary(BuildContext context) {
    return StreamBuilder<List<Tank>>(
      stream: sl<TankService>().getTanks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final lowStockTanks = snapshot.data!
            .where((t) => t.isLowStock)
            .toList();

        if (lowStockTanks.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Low Stock Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  Text(
                    '${lowStockTanks.length} tanks running low',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
