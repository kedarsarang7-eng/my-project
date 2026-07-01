import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Bar Chart for Stock Value distribution by Category
class StockValueCategoryChart extends StatefulWidget {
  final Map<String, double> categoryValues;

  const StockValueCategoryChart({super.key, required this.categoryValues});

  @override
  State<StockValueCategoryChart> createState() =>
      _StockValueCategoryChartState();
}

class _StockValueCategoryChartState extends State<StockValueCategoryChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categoryValues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Category Data",
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

    // Sort to show top 5 categories
    final entries = widget.categoryValues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = entries.take(5).toList();
    final double maxY = topCategories.isNotEmpty
        ? topCategories.first.value * 1.2
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
                "Stock Value by Category",
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
                      final category = topCategories[group.x].key;
                      return BarTooltipItem(
                        '$category\n',
                        GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: '₹${_formatNumber(rod.toY)}',
                            style: GoogleFonts.inter(
                              color: FuturisticColors.primary,
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
                        if (value.toInt() >= topCategories.length) {
                          return const SizedBox.shrink();
                        }

                        String title = topCategories[value.toInt()].key;
                        if (title.length > 8) {
                          title = '${title.substring(0, 7)}.';
                        }

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
                barGroups: List.generate(topCategories.length, (i) {
                  final isTouched = i == touchedIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: topCategories[i].value,
                        color: isTouched
                            ? FuturisticColors.primary
                            : FuturisticColors.primary.withValues(alpha: 0.6),
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
