import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Donut Chart for Petrol vs Diesel Sales
class FuelSalesChart extends StatefulWidget {
  final Map<String, double> fuelData; // {"Petrol": 500, "Diesel": 800}

  const FuelSalesChart({super.key, required this.fuelData});

  @override
  State<FuelSalesChart> createState() => _FuelSalesChartState();
}

class _FuelSalesChartState extends State<FuelSalesChart> {
  int touchedIndex = -1;

  Color _getColorForFuel(String type) {
    switch (type.toLowerCase()) {
      case 'petrol':
        return FuturisticColors.warning; // Orange/Yellow
      case 'diesel':
        return FuturisticColors.premiumBlue; // Blue
      case 'cng':
        return FuturisticColors.success; // Green
      default:
        return FuturisticColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fuelData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_gas_station_outlined,
                size: 64,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Fuel Data",
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

    final total = widget.fuelData.values.fold(0.0, (s, e) => s + e);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Fuel Sales (Litres)",
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
                    sections: List.generate(widget.fuelData.length, (i) {
                      final key = widget.fuelData.keys.elementAt(i);
                      final val = widget.fuelData.values.elementAt(i);
                      final isTouched = i == touchedIndex;
                      final radius = isTouched ? 60.0 : 50.0;
                      final fontSize = isTouched ? 16.0 : 0.0;

                      return PieChartSectionData(
                        color: _getColorForFuel(key),
                        value: val,
                        title: val.toStringAsFixed(1),
                        showTitle: isTouched,
                        radius: radius,
                        titleStyle: GoogleFonts.inter(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            const Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      );
                    }),
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
                    Flexible(
                      child: Text(
                        total.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          color: FuturisticColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: widget.fuelData.entries.map((e) {
              return _buildLegendItem(e.key, e.value, _getColorForFuel(e.key));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
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
