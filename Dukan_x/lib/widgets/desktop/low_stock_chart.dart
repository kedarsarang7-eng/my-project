import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Donut Chart for Low Stock vs Healthy Stock
class LowStockChart extends StatefulWidget {
  final int lowStockCount;
  final int healthyStockCount;

  const LowStockChart({
    super.key,
    required this.lowStockCount,
    required this.healthyStockCount,
  });

  @override
  State<LowStockChart> createState() => _LowStockChartState();
}

class _LowStockChartState extends State<LowStockChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.lowStockCount + widget.healthyStockCount;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Inventory Data",
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Stock Health",
            style: GoogleFonts.outfit(
              color: FuturisticColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    sections: [
                      // Healthy Stock
                      _buildSection(
                        value: widget.healthyStockCount.toDouble(),
                        color: FuturisticColors.success,
                        title: 'Healthy',
                        isTouched: touchedIndex == 0,
                      ),
                      // Low Stock
                      _buildSection(
                        value: widget.lowStockCount.toDouble(),
                        color: FuturisticColors.error,
                        title: 'Low',
                        isTouched: touchedIndex == 1,
                      ),
                    ],
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total",
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      total.toString(),
                      style: GoogleFonts.outfit(
                        color: FuturisticColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                "Healthy",
                widget.healthyStockCount,
                FuturisticColors.success,
              ),
              const SizedBox(width: 24),
              _buildLegendItem(
                "Low Stock",
                widget.lowStockCount,
                FuturisticColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildSection({
    required double value,
    required Color color,
    required String title,
    required bool isTouched,
  }) {
    final fontSize = isTouched ? 16.0 : 0.0;
    final radius = isTouched ? 60.0 : 50.0;

    return PieChartSectionData(
      color: color,
      value: value,
      title: value
          .toInt()
          .toString(), // Show count instead of % when touched, or hide if not touched if we set showTitle
      showTitle: isTouched,
      radius: radius,
      titleStyle: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
      ),
      badgeWidget: isTouched ? null : null,
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              value.toString(),
              style: GoogleFonts.inter(
                color: FuturisticColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
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
