import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/currency_service.dart';

/// Premium Revenue Analytics Chart with gradient bars and glassmorphism.
/// Shows real sales trend data with enhanced visual effects.
class RevenueAnalyticsChart extends StatefulWidget {
  final Map<String, double> data; // e.g., {"Mon": 5000, "Tue": 7000}

  const RevenueAnalyticsChart({super.key, required this.data});

  @override
  State<RevenueAnalyticsChart> createState() => _RevenueAnalyticsChartState();
}

class _RevenueAnalyticsChartState extends State<RevenueAnalyticsChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    // Empty state with premium styling
    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(context),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 64,
                color: theme.hintColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Data",
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create invoices to see revenue trends",
                style: TextStyle(
                  color: theme.hintColor.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final keys = widget.data.keys.toList();
    final values = widget.data.values.toList();
    final maxY = values.reduce((curr, next) => curr > next ? curr : next);
    final totalRevenue = values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Revenue Analytics",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last ${widget.data.length} Days",
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Total revenue badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      "${sl<CurrencyService>().symbol}${_formatNumber(totalRevenue)}",
                      style: TextStyle(
                        color: isDark ? accentColor : primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Total",
                      style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.spot != null &&
                          event is! PointerUpEvent &&
                          event is! PointerExitEvent) {
                        touchedIndex = response!.spot!.touchedBarGroupIndex;
                      } else {
                        touchedIndex = -1;
                      }
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.dialogBackgroundColor ?? theme.cardColor,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${sl<CurrencyService>().symbol}${_formatNumber(rod.toY)}',
                        TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < keys.length) {
                          final isTouched = value.toInt() == touchedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              keys[value.toInt()],
                              style: TextStyle(
                                color: isTouched
                                    ? primaryColor
                                    : theme.hintColor,
                                fontSize: 11,
                                fontWeight: isTouched
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${sl<CurrencyService>().symbol}${(value / 1000).toStringAsFixed(0)}k',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.dividerColor,
                      strokeWidth: 0.5,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(widget.data.length, (index) {
                  final isTouched = index == touchedIndex;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: isTouched ? values[index] * 1.02 : values[index],
                        gradient: LinearGradient(
                          colors: isTouched
                              ? [
                                  accentColor,
                                  primaryColor,
                                ]
                              : [
                                  primaryColor,
                                  accentColor.withOpacity(0.7),
                                ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: isTouched ? 20 : 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY * 1.25,
                          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
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

  BoxDecoration _buildCardDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.cardColor,
          theme.cardColor.withOpacity(0.95),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? primaryColor.withOpacity(0.2) : theme.dividerColor,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark 
              ? primaryColor.withOpacity(0.08)
              : Colors.black.withOpacity(0.02),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: isDark 
              ? Colors.black.withOpacity(0.2)
              : Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
