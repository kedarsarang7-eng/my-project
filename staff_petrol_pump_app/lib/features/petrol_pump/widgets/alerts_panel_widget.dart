import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alerts_provider.dart';
import '../theme/fuelpos_theme.dart';

/// Alerts Panel Widget - Station Status & Alerts
class AlertsPanelWidget extends ConsumerWidget {
  const AlertsPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsState = ref.watch(alertsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Station Status & Alerts',
                  style: TextStyle(
                    color: FuelPOSTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (alertsState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (alertsState.error != null)
              _buildError(alertsState.error!)
            else if (alertsState.alerts == null)
              const Center(
                child: Text(
                  'Loading alerts...',
                  style: TextStyle(color: FuelPOSTheme.textMuted),
                ),
              )
            else ...[
              // Inventory section
              _buildSectionTitle('Inventory:'),
              ...alertsState.alerts!.inventory.map(_buildInventoryAlert),
              const SizedBox(height: 12),

              // Active alerts section
              if (alertsState.alerts!.operational.isNotEmpty) ...[
                _buildSectionTitle('Active Alerts:'),
                ...alertsState.alerts!.operational.map(_buildOperationalAlert),
                const SizedBox(height: 12),
              ],

              // Pump status
              _buildPumpStatus(alertsState.alerts!.pumps),
              const SizedBox(height: 12),

              // Employees on duty
              _buildEmployeeStatus(alertsState.alerts!.employeesOnDuty),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: FuelPOSTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInventoryAlert(InventoryAlert alert) {
    Color textColor;
    IconData icon;

    switch (alert.severity) {
      case 'high':
        textColor = FuelPOSTheme.errorRed;
        icon = Icons.warning;
        break;
      case 'medium':
        textColor = FuelPOSTheme.warningYellow;
        icon = Icons.info;
        break;
      default:
        textColor = FuelPOSTheme.textMuted;
        icon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: alert.severity == 'high'
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalAlert(OperationalAlert alert) {
    Color textColor;
    IconData icon;

    switch (alert.severity) {
      case 'high':
        textColor = FuelPOSTheme.errorRed;
        icon = Icons.error;
        break;
      case 'medium':
        textColor = FuelPOSTheme.warningYellow;
        icon = Icons.notifications;
        break;
      default:
        textColor = FuelPOSTheme.infoBlue;
        icon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpStatus(PumpStatus pumps) {
    final percentActive = pumps.activePercent;
    Color progressColor;

    if (percentActive >= 80) {
      progressColor = FuelPOSTheme.successGreen;
    } else if (percentActive >= 50) {
      progressColor = FuelPOSTheme.warningYellow;
    } else {
      progressColor = FuelPOSTheme.errorRed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pumps:'),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: pumps.total > 0 ? pumps.active / pumps.total : 0,
                backgroundColor: FuelPOSTheme.borderDark,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              pumps.statusText,
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (pumps.offline > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${pumps.offline} pump${pumps.offline > 1 ? 's' : ''} offline',
              style: const TextStyle(
                color: FuelPOSTheme.errorRed,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeStatus(int count) {
    return Row(
      children: [
        const Icon(
          Icons.people,
          color: FuelPOSTheme.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'Employees On Duty:',
          style: TextStyle(
            color: FuelPOSTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0
                ? FuelPOSTheme.successGreen.withValues(alpha:0.15)
                : FuelPOSTheme.errorRed.withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: count > 0 ? FuelPOSTheme.successGreen : FuelPOSTheme.errorRed,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: FuelPOSTheme.errorRed,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: FuelPOSTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
