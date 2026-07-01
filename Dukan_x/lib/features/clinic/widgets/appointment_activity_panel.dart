// ============================================================================
// APPOINTMENT ACTIVITY PANEL
// ============================================================================
// Line chart showing weekly appointment trends
// This Week vs Last Week comparison
// "Schedule New" button
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';

class AppointmentActivityPanel extends StatelessWidget {
  final WeeklyAppointmentTrends trends;

  const AppointmentActivityPanel({
    super.key,
    required this.trends,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Weekly Appointment Trends',
                    style: TextStyle(
                      fontSize: 13,
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to schedule new appointment
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Legend
          Row(
            children: [
              _LegendItem(
                color: FuturisticColors.primary,
                label: 'Current',
              ),
              const SizedBox(width: 24),
              _LegendItem(
                color: const Color(0xFF90A4AE),
                label: 'Last Week',
                isDashed: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 200,
            child: trends.isEmpty || trends.data.isEmpty
                ? _buildEmptyChart()
                : _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No appointment data available',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final maxY = trends.maxValue > 0 ? (trends.maxValue * 1.2).ceilToDouble() : 10.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < trends.data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      trends.data[index].day,
                      style: TextStyle(
                        fontSize: 11,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                );
              },
              reservedSize: 30,
              interval: maxY / 4,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: trends.data.length.toDouble() - 1,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          // Current Week Line
          LineChartBarData(
            spots: trends.data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.thisWeek.toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: FuturisticColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: FuturisticColors.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: FuturisticColors.primary.withValues(alpha: 0.1),
            ),
          ),
          // Last Week Line (dashed)
          LineChartBarData(
            spots: trends.data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.lastWeek.toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF90A4AE),
            barWidth: 2,
            dashArray: [5, 5],
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.white,
            tooltipBorder: BorderSide(color: Colors.grey.shade300),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final day = trends.data[barSpot.x.toInt()].day;
                final isCurrent = barSpot.barIndex == 0;
                return LineTooltipItem(
                  '$day\n${barSpot.y.toInt()} ${isCurrent ? "(Current)" : "(Last Week)"}',
                  TextStyle(
                    fontSize: 12,
                    color: isCurrent ? FuturisticColors.primary : const Color(0xFF90A4AE),
                    fontWeight: FontWeight.w500,
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 2,
                      height: 3,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: FuturisticColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
