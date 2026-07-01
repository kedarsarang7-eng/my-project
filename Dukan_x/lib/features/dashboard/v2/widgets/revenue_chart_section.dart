import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../models/dashboard_v2_models.dart';
import '../providers/dashboard_v2_providers.dart';
import '../utils/indian_number_formatter.dart';

class RevenueChartSection extends ConsumerWidget {
  const RevenueChartSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(dashboardV2RevenueChartProvider);
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
                  color: FuturisticColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: FuturisticColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${config.chartYAxisLabel} Overview',
                    style: TextStyle(
                      color: FuturisticColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    'Billed vs Collected (Last 6 Months)',
                    style: TextStyle(
                      color: FuturisticColors.textSecondary,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Legend
              _LegendDot(color: FuturisticColors.primary, label: 'Billed'),
              const SizedBox(width: 16),
              _LegendDot(color: FuturisticColors.success, label: 'Collected'),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          chartAsync.when(
            data: (data) => data.isEmpty
                ? _buildEmpty()
                : SizedBox(
                    height: 220,
                    child: _buildChart(data),
                  ),
            loading: () => Shimmer.fromColors(
              baseColor: FuturisticColors.surface,
              highlightColor: FuturisticColors.border.withValues(alpha: 0.6),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: FuturisticColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            error: (_, _) => _buildErrorState(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(RevenueChartData data) {
    final maxVal = data.points.fold<double>(0, (prev, p) {
      final vals = [prev, p.billedCents.toDouble(), p.collectedCents.toDouble()];
      return vals.reduce((a, b) => a > b ? a : b);
    });
    final ceiling = maxVal == 0 ? 100000.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        maxY: ceiling.toDouble(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => FuturisticColors.surface.withValues(alpha: 0.95),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = data.points[group.x.toInt()];
              final isBilled = rodIndex == 0;
              return BarTooltipItem(
                '${isBilled ? "Billed" : "Collected"}\n${IndianNumberFormatter.formatCentsToInr(isBilled ? point.billedCents : point.collectedCents)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
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
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceiling / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: FuturisticColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.points.length, (i) {
          final p = data.points[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: p.billedCents.toDouble(),
                color: FuturisticColors.primary,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: p.collectedCents.toDouble(),
                color: FuturisticColors.success,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ],
            barsSpace: 3,
          );
        }),
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.3),
                size: 48),
            const SizedBox(height: 12),
            Text(
              'No revenue data yet',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create your first invoice to see analytics',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 12,
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
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: FuturisticColors.error.withValues(alpha: 0.4), size: 36),
            const SizedBox(height: 10),
            Text(
              'Failed to load chart',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(dashboardV2RevenueChartProvider),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
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
