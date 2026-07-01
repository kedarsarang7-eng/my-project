import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/currency_service.dart';

/// Premium Expense Breakdown Donut Chart with glassmorphism.
/// Shows expense category distribution with enhanced visual effects.
class ExpenseBreakdownChart extends StatefulWidget {
  final Map<String, double> data; // e.g. {"Rent": 2000, "Stock": 5000}

  const ExpenseBreakdownChart({super.key, required this.data});

  @override
  State<ExpenseBreakdownChart> createState() => _ExpenseBreakdownChartState();
}

class _ExpenseBreakdownChartState extends State<ExpenseBreakdownChart> {
  int touchedIndex = -1;

  // Premium color palette for chart sections
  static const List<Color> _chartColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // Premium empty state
    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _buildCardDecoration(context),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: theme.hintColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                "No Expenses",
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Add expenses to see breakdown",
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
    final total = values.fold(0.0, (sum, item) => sum + item);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _buildCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Expense Overview",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  "This Month",
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Chart and Legend
          Expanded(
            child: Row(
              children: [
                // Donut Chart with center label
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
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
                          sections: List.generate(widget.data.length, (i) {
                            final isTouched = i == touchedIndex;
                            final fontSize = isTouched ? 14.0 : 11.0;
                            final radius = isTouched ? 60.0 : 50.0;
                            final percentage = (values[i] / total) * 100;
                            final color = _chartColors[i % _chartColors.length];

                            return PieChartSectionData(
                              color: color,
                              value: values[i],
                              title: '${percentage.toStringAsFixed(0)}%',
                              radius: radius,
                              titleStyle: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                              badgePositionPercentageOffset: isTouched
                                  ? 1.1
                                  : 0.98,
                            );
                          }),
                        ),
                      ),
                      // Center label with total
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.cardColor.withOpacity(0.9),
                          border: Border.all(
                            color: theme.dividerColor,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${sl<CurrencyService>().symbol}${_formatNumber(total)}",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Total",
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Legend with amounts
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(widget.data.length, (i) {
                        final color = _chartColors[i % _chartColors.length];
                        final isTouched = i == touchedIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isTouched
                                ? color.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isTouched
                                ? Border.all(color: color.withOpacity(0.3))
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Color indicator
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Category name and amount
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      keys[i],
                                      style: TextStyle(
                                        color: isTouched
                                            ? theme.colorScheme.onSurface
                                            : theme.hintColor,
                                        fontSize: 12,
                                        fontWeight: isTouched
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${sl<CurrencyService>().symbol}${values[i].toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: isTouched
                                            ? color
                                            : theme.hintColor
                                                  .withOpacity(0.7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
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
