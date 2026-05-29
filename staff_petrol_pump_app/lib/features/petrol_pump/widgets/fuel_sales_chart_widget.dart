import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/fuel_chart_provider.dart';
import '../theme/fuelpos_theme.dart';

/// Fuel Sales Chart Widget - Dual line area chart
class FuelSalesChartWidget extends ConsumerWidget {
  final DateTime? selectedDate;
  final Function(DateTime)? onDateChanged;

  const FuelSalesChartWidget({
    super.key,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartState = ref.watch(fuelChartProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and date picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Fuel Sales Performance (Volume/L)',
                  style: TextStyle(
                    color: FuelPOSTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDatePicker(context, ref),
              ],
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              children: [
                _buildLegendItem('Petrol', FuelPOSTheme.petrolBlue),
                const SizedBox(width: 24),
                _buildLegendItem('Diesel', FuelPOSTheme.dieselOrange),
              ],
            ),
            const SizedBox(height: 20),

            // Chart
            SizedBox(
              height: 280,
              child: chartState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chartState.error != null
                      ? _buildError(chartState.error!)
                      : chartState.data == null
                          ? const Center(
                              child: Text(
                                'No data available',
                                style: TextStyle(color: FuelPOSTheme.textMuted),
                              ),
                            )
                          : _buildChart(chartState.data!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, WidgetRef ref) {
    final currentDate = selectedDate ?? DateTime.now();

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: FuelPOSTheme.primaryBlue,
                  surface: FuelPOSTheme.cardDark,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          onDateChanged?.call(picked);
          ref.read(fuelChartProvider.notifier).setDate(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FuelPOSTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FuelPOSTheme.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM dd, yyyy').format(currentDate),
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_drop_down,
              color: FuelPOSTheme.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: FuelPOSTheme.textSecondary,
            fontSize: 13,
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
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: const TextStyle(color: FuelPOSTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChart(FuelChartData data) {
    final petrolSpots = <FlSpot>[];
    final dieselSpots = <FlSpot>[];

    for (int i = 0; i < data.petrol.length; i++) {
      petrolSpots.add(FlSpot(i.toDouble(), data.petrol[i]));
      dieselSpots.add(FlSpot(i.toDouble(), data.diesel[i]));
    }

    final maxY = data.maxValue;
    final interval = maxY / 6;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: FuelPOSTheme.borderDark,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.hours.length) {
                  final hour = data.hours[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      hour,
                      style: const TextStyle(
                        color: FuelPOSTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: FuelPOSTheme.textMuted,
                    fontSize: 11,
                  ),
                );
              },
            ),
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Liters',
                style: TextStyle(
                  color: FuelPOSTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.hours.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          // Petrol line
          LineChartBarData(
            spots: petrolSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: FuelPOSTheme.petrolBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: FuelPOSTheme.petrolBlue.withValues(alpha:0.1),
            ),
          ),
          // Diesel line
          LineChartBarData(
            spots: dieselSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: FuelPOSTheme.dieselOrange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: FuelPOSTheme.dieselOrange.withValues(alpha:0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: FuelPOSTheme.surfaceDark,
            tooltipBorder: BorderSide(color: FuelPOSTheme.borderDark),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isPetrol = spot.barIndex == 0;
                return LineTooltipItem(
                  '${isPetrol ? 'Petrol' : 'Diesel'}\n${spot.y.toStringAsFixed(0)} L',
                  TextStyle(
                    color: isPetrol
                        ? FuelPOSTheme.petrolBlue
                        : FuelPOSTheme.dieselOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
