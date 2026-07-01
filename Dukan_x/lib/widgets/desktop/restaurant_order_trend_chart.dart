import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class RestaurantOrderTrendChart extends StatefulWidget {
  final Map<int, int> activeOrdersPerHour; // Hour (0-23) -> Count
  final Map<int, int> completedOrdersPerHour; // Hour (0-23) -> Count

  const RestaurantOrderTrendChart({
    super.key,
    required this.activeOrdersPerHour,
    required this.completedOrdersPerHour,
  });

  @override
  State<RestaurantOrderTrendChart> createState() =>
      _RestaurantOrderTrendChartState();
}

class _RestaurantOrderTrendChartState extends State<RestaurantOrderTrendChart> {
  @override
  Widget build(BuildContext context) {
    if (widget.activeOrdersPerHour.isEmpty &&
        widget.completedOrdersPerHour.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Order Data Available",
                style: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine the min and max X (hours) to display
    final allHours = {
      ...widget.activeOrdersPerHour.keys,
      ...widget.completedOrdersPerHour.keys,
    }.toList()..sort();

    final minX = allHours.isNotEmpty ? allHours.first.toDouble() : 0.0;
    final maxX = allHours.isNotEmpty ? allHours.last.toDouble() : 23.0;

    // Find the max Y so we can scale the chart
    final maxActive = widget.activeOrdersPerHour.values.isEmpty
        ? 0
        : widget.activeOrdersPerHour.values.reduce((a, b) => a > b ? a : b);
    final maxCompleted = widget.completedOrdersPerHour.values.isEmpty
        ? 0
        : widget.completedOrdersPerHour.values.reduce((a, b) => a > b ? a : b);
    final maxY =
        (maxActive > maxCompleted ? maxActive : maxCompleted).toDouble() * 1.2;

    // Default to at least 5 for Y axis if mostly empty
    final finalMaxY = maxY < 5 ? 5.0 : maxY;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order Volume Trend",
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildLegendRow(),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX:
                    maxX +
                    ((maxX - minX) * 0.05).clamp(
                      1.0,
                      3.0,
                    ), // Padding on the right
                minY: 0,
                maxY: finalMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        FuturisticColors.surface.withValues(alpha: 0.9),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isCompleted = spot.barIndex == 0;
                        final color = isCompleted
                            ? FuturisticColors.success
                            : FuturisticColors.warning;
                        final label = isCompleted
                            ? 'Completed'
                            : 'Active/Cancelled';

                        return LineTooltipItem(
                          '$label: ${spot.y.toInt()}\n',
                          GoogleFonts.inter(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${spot.x.toInt()}:00',
                              style: GoogleFonts.inter(
                                color: FuturisticColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: FuturisticColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        // Only show every 2nd or 3rd hour if many hours
                        if (value % 2 != 0 && (maxX - minX) > 8) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            '${value.toInt()}:00',
                            style: GoogleFonts.inter(
                              color: FuturisticColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 ||
                            value == finalMaxY ||
                            value % 1 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: GoogleFonts.inter(
                              color: FuturisticColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  _createLineData(
                    widget.completedOrdersPerHour,
                    FuturisticColors.success,
                    minX,
                    maxX,
                  ),
                  _createLineData(
                    widget.activeOrdersPerHour,
                    FuturisticColors.warning,
                    minX,
                    maxX,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _createLineData(
    Map<int, int> data,
    Color color,
    double minX,
    double maxX,
  ) {
    List<FlSpot> spots = [];

    // Fill missing hours with 0 to ensure continuous line
    for (int i = minX.toInt(); i <= maxX.toInt(); i++) {
      spots.add(FlSpot(i.toDouble(), (data[i] ?? 0).toDouble()));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          if (spot.y == 0 && index > 0 && index < spots.length - 1) {
            return FlDotCirclePainter(
              color: Colors.transparent,
              strokeWidth: 0,
            );
          }
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: FuturisticColors.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem("Completed", FuturisticColors.success),
        const SizedBox(width: 16),
        _buildLegendItem("Active", FuturisticColors.warning),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: FuturisticColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          FuturisticColors.surface,
          FuturisticColors.surface.withValues(alpha: 0.85),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FuturisticColors.primary.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
