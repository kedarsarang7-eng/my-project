import 'package:flutter/material.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fuel_rates_screen.dart';
import 'dispenser_list_screen.dart';
import 'shift_history_screen.dart';
import 'tank_list_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PetrolPumpManagementScreen extends ConsumerWidget {
  const PetrolPumpManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Petrol Pump Management'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      body: Center(
        child: BoundedBox(
          maxWidth: 600,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMenuTile(
                context,
                'Fuel Configuration',
                'Manage fuel types and daily rates',
                Icons.local_gas_station,
                Colors.red,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FuelRatesScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _buildMenuTile(
                context,
                'Dispenser & Nozzles',
                'Configure dispensers and assign nozzles',
                Icons.settings_input_component,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DispenserListScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _buildMenuTile(
                context,
                'Shift Management',
                'Open/Close shifts and view history',
                Icons.access_time_filled,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _buildMenuTile(
                context,
                'Tank & Stock',
                'Manage tank levels and purchases',
                Icons.water_drop,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TankListScreen()),
                ),
              ),
              // Employee Management removed until fully implemented
              // Features must work or not exist per production policy
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
