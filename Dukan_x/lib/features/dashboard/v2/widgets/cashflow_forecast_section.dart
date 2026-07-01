import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../models/dashboard_v2_models.dart';
import '../providers/dashboard_v2_providers.dart';
import '../utils/indian_number_formatter.dart';

class CashflowForecastSection extends ConsumerWidget {
  const CashflowForecastSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflowAsync = ref.watch(dashboardV2CashflowProvider);
    final config = ref.watch(dashboardBusinessConfigProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FuturisticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FuturisticColors.accent1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    color: FuturisticColors.accent1, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.forecastLabel,
                    style: TextStyle(
                      color: FuturisticColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    'Reserve vs Forecast (3 Months)',
                    style: TextStyle(
                      color: FuturisticColors.textSecondary,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Forecast badge
              cashflowAsync.when(
                data: (d) => d.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: d.forecastPercent >= 0
                              ? FuturisticColors.success.withValues(alpha: 0.12)
                              : FuturisticColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              d.forecastPercent >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: d.forecastPercent >= 0
                                  ? FuturisticColors.success
                                  : FuturisticColors.error,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              IndianNumberFormatter.formatPercent(
                                  d.forecastPercent),
                              style: TextStyle(
                                color: d.forecastPercent >= 0
                                    ? FuturisticColors.success
                                    : FuturisticColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Legend
          Row(
            children: [
              _LegendItem(
                  color: FuturisticColors.accent1, label: 'Cash Reserve'),
              const SizedBox(width: 20),
              _LegendItem(
                  color: FuturisticColors.warning, label: 'Forecast'),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          cashflowAsync.when(
            data: (d) => d.isEmpty ? _buildEmpty() : _buildChart(d),
            loading: () => Shimmer.fromColors(
              baseColor: FuturisticColors.surface,
              highlightColor: FuturisticColors.border.withValues(alpha: 0.6),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: FuturisticColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // AUDIT FIX #4: Show error state with retry
            error: (_, _) => _buildErrorState(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(CashFlowForecastData data) {
    if (data.points.isEmpty) return _buildEmpty();

    final allValues = data.points
        .expand((p) => [
              p.cashReserveCents.toDouble(),
              p.forecastCents.toDouble(),
            ])
        .toList();
    final maxVal = allValues.isEmpty
        ? 100000.0
        : allValues.reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal == 0 ? 100000.0 : maxVal * 1.3;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          maxY: ceiling,
          minY: 0,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => FuturisticColors.surface.withValues(alpha: 0.95),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final isReserve = spot.barIndex == 0;
                  return LineTooltipItem(
                    '${isReserve ? "Reserve" : "Forecast"}: ${IndianNumberFormatter.formatCentsToInr(spot.y.toInt())}',
                    TextStyle(
                      color: isReserve
                          ? FuturisticColors.accent1
                          : FuturisticColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceiling / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: FuturisticColors.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data.points[idx].label,
                      style: TextStyle(
                        color: FuturisticColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: ceiling / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    IndianNumberFormatter.formatCentsForAxis(value),
                    style: TextStyle(
                      color: FuturisticColors.textSecondary,
                      fontSize: 10,
                      decoration: TextDecoration.none,
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Cash Reserve line
            LineChartBarData(
              spots: List.generate(data.points.length, (i) {
                return FlSpot(
                    i.toDouble(), data.points[i].cashReserveCents.toDouble());
              }),
              isCurved: true,
              color: FuturisticColors.accent1,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: FuturisticColors.accent1,
                  strokeWidth: 2,
                  strokeColor: FuturisticColors.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: FuturisticColors.accent1.withValues(alpha: 0.08),
              ),
            ),
            // Forecast line (dashed)
            LineChartBarData(
              spots: List.generate(data.points.length, (i) {
                return FlSpot(
                    i.toDouble(), data.points[i].forecastCents.toDouble());
              }),
              isCurved: true,
              color: FuturisticColors.warning,
              barWidth: 2,
              isStrokeCapRound: true,
              dashArray: [6, 4],
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: FuturisticColors.warning,
                  strokeWidth: 2,
                  strokeColor: FuturisticColors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.3),
                size: 42),
            const SizedBox(height: 10),
            Text(
              'No cash flow data yet',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AUDIT FIX #4: Error state with retry
  Widget _buildErrorState(WidgetRef ref) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: FuturisticColors.error.withValues(alpha: 0.4), size: 36),
            const SizedBox(height: 10),
            Text(
              'Failed to load forecast',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(dashboardV2CashflowProvider),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: FuturisticColors.primary,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: FuturisticColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
