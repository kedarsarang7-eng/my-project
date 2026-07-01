import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Bar Chart for Nozzle Performance
class NozzlePerformanceChart extends StatefulWidget {
  final Map<String, double> nozzleData; // {"N1": 1500, "N2": 800}

  const NozzlePerformanceChart({super.key, required this.nozzleData});

  @override
  State<NozzlePerformanceChart> createState() => _NozzlePerformanceChartState();
}

class _NozzlePerformanceChartState extends State<NozzlePerformanceChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.nozzleData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.speed_outlined,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Nozzle Data",
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

    // Sort to show top 5 performing nozzles
    final entries = widget.nozzleData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topNozzles = entries.take(6).toList();
    final double maxY = topNozzles.isNotEmpty
        ? topNozzles.first.value * 1.2
        : 100;

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
                "Nozzle Performance (Sales ₹)",
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        FuturisticColors.surface.withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final nozzle = topNozzles[group.x].key;
                      return BarTooltipItem(
                        'Nozzle $nozzle\n',
                        GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '₹${_formatNumber(rod.toY)}',
                            style: GoogleFonts.inter(
                              color: FuturisticColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= topNozzles.length) {
                          return const SizedBox.shrink();
                        }

                        String title = topNozzles[value.toInt()].key;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              color: FuturisticColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _formatYAxis(value),
                          style: GoogleFonts.inter(
                            color: FuturisticColors.textSecondary,
                            fontSize: 10,
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
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: FuturisticColors.border,
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(topNozzles.length, (i) {
                  final isTouched = i == touchedIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: topNozzles[i].value,
                        color: isTouched
                            ? FuturisticColors.success
                            : FuturisticColors.success.withValues(alpha: 0.6),
                        width: 22,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: FuturisticColors.surfaceHigh.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
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

  String _formatNumber(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _formatYAxis(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(0)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}
