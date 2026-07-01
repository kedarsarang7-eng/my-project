import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

class AgingBucketBarChartData {
  final String label;
  final double value;

  const AgingBucketBarChartData({required this.label, required this.value});
}

class AgingBucketBarChart extends StatelessWidget {
  final List<AgingBucketBarChartData>? data;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const AgingBucketBarChart({
    super.key,
    this.data,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) return const ShimmerChartArea(height: 280);
    if (error != null) {
      return ErrorRetryWidget(message: error!, onRetry: onRetry ?? () {});
    }

    final items = data ?? const [];
    if (items.isEmpty) {
      return const IllustratedEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No aging data yet',
        subtitle: 'Aging buckets will show overdue balances once invoices are outstanding.',
      );
    }

    final maxY = items.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b) * 1.2;
    final total = items.fold<double>(0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: items[i].value,
                        width: 24,
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(const Color(0xFF10B981), const Color(0xFFF59E0B), i / (items.length - 1 == 0 ? 1 : items.length - 1))!,
                            Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), i / (items.length - 1 == 0 ? 1 : items.length - 1))!,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                    showingTooltipIndicators: const [0],
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= items.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          items[index].label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total: ${total.toStringAsFixed(0)}',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
