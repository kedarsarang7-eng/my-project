import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';
import '../../../../../../utils/currency_formatter.dart';

class PharmacySalesPerformanceChart extends ConsumerWidget {
  const PharmacySalesPerformanceChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(pharmacySalesPerformanceProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: salesAsync.when(
              data: (data) => _buildChart(context, data),
              loading: () => _buildLoadingChart(),
              error: (_, _) => _buildErrorChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.show_chart_rounded,
            color: FuturisticColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Daily revenue vs 30-day rolling average',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendItem(color: FuturisticColors.primary, label: 'Daily Revenue'),
        const SizedBox(width: 16),
        _LegendItem(color: FuturisticColors.info, label: '30-Day Average'),
      ],
    );
  }

  Widget _buildChart(BuildContext context, SalesPerformanceData data) {
    if (data.isEmpty || data.dates.isEmpty) {
      return _buildEmptyChart();
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateHorizontalInterval(data),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateBottomInterval(data.dates.length),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.dates.length) {
                  final dateStr = data.dates[value.toInt()];
                  final formattedDate = _formatDate(dateStr);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10,
                        color: FuturisticColors.textSecondary,
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
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    CurrencyFormatter.formatShort(value.toInt()),
                    style: TextStyle(
                      fontSize: 10,
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.dates.length - 1).toDouble(),
        minY: 0,
        maxY: _calculateMaxY(data),
        lineBarsData: [
          // Daily Revenue Line
          LineChartBarData(
            spots: List.generate(
              data.dailyRevenue.length,
              (index) => FlSpot(index.toDouble(), data.dailyRevenue[index]),
            ),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                FuturisticColors.primary.withValues(alpha: 0.8),
                FuturisticColors.primary,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: FuturisticColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  FuturisticColors.primary.withValues(alpha: 0.1),
                  FuturisticColors.primary.withValues(alpha: 0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Rolling Average Line
          LineChartBarData(
            spots: List.generate(
              data.rollingAverage.length,
              (index) => FlSpot(index.toDouble(), data.rollingAverage[index]),
            ),
            isCurved: true,
            color: FuturisticColors.info,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                FuturisticColors.textPrimary.withValues(alpha: 0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final value = CurrencyFormatter.format(spot.y.toInt());
                final date = data.dates[spot.x.toInt()];
                final formattedDate = _formatFullDate(date);

                String label;
                if (spot.barIndex == 0) {
                  label = 'Daily Revenue';
                } else {
                  label = '30-Day Average';
                }

                return LineTooltipItem(
                  '$label\n$formattedDate\n$value',
                  TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
          touchCallback:
              (FlTouchEvent event, LineTouchResponse? touchResponse) {
                // Handle touch events if needed
              },
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildLoadingChart() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: FuturisticColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading sales data...',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorChart() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: FuturisticColors.error),
          const SizedBox(height: 16),
          Text(
            'Unable to load sales data',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No sales data available',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart Helper Methods ─────────────────────────────────────────────────────

  double _calculateMaxY(SalesPerformanceData data) {
    if (data.dailyRevenue.isEmpty && data.rollingAverage.isEmpty) return 1000;

    final allValues = [...data.dailyRevenue, ...data.rollingAverage];
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    return maxValue * 1.2; // Add 20% padding
  }

  double _calculateHorizontalInterval(SalesPerformanceData data) {
    if (data.dailyRevenue.isEmpty && data.rollingAverage.isEmpty) return 1000;

    final allValues = [...data.dailyRevenue, ...data.rollingAverage];
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    return maxValue / 5; // 5 horizontal lines
  }

  double _calculateBottomInterval(int dateCount) {
    if (dateCount <= 7) return 1;
    if (dateCount <= 14) return 2;
    if (dateCount <= 30) return 5;
    return 7;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}';
    } catch (e) {
      return dateStr.substring(5); // Fallback to MM-DD format
    }
  }

  String _formatFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }
}

// ── Legend Item Widget ─────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: FuturisticColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
