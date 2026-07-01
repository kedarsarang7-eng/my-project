import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

class SalesLineChartData {
  final List<FlSpot> currentPeriod;
  final List<FlSpot> comparisonPeriod;
  final List<String> labels;

  const SalesLineChartData({
    required this.currentPeriod,
    required this.comparisonPeriod,
    required this.labels,
  });

  bool get isEmpty => currentPeriod.isEmpty && comparisonPeriod.isEmpty;
}

class SalesLineChart extends StatefulWidget {
  final SalesLineChartData? data;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const SalesLineChart({
    super.key,
    this.data,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  State<SalesLineChart> createState() => _SalesLineChartState();
}

class _SalesLineChartState extends State<SalesLineChart> {
  int _rangeIndex = 1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isLoading) {
      return const ShimmerChartArea();
    }

    if (widget.error != null) {
      return ErrorRetryWidget(
        message: widget.error!,
        onRetry: widget.onRetry ?? () {},
      );
    }

    final data = widget.data;
    if (data == null || data.isEmpty) {
      return const IllustratedEmptyState(
        icon: Icons.show_chart,
        title: 'No sales data yet',
        subtitle: 'Sales trends will appear here once transactions are recorded.',
      );
    }

    final activeCurrent = data.currentPeriod;
    final activeComparison = data.comparisonPeriod;
    final maxY = [
      ...activeCurrent.map((e) => e.y),
      ...activeComparison.map((e) => e.y),
      0,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Day')),
            ButtonSegment(value: 1, label: Text('Week')),
            ButtonSegment(value: 2, label: Text('Month')),
          ],
          selected: {_rangeIndex},
          onSelectionChanged: (selected) {
            setState(() => _rangeIndex = selected.first);
          },
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1.8,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (data.labels.length - 1).toDouble(),
              minY: 0,
              maxY: maxY == 0 ? 1 : maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY == 0 ? 1 : maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY == 0 ? 1 : maxY / 4,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data.labels[index],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(12),
                  getTooltipColor: (_) => colorScheme.surface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    return LineTooltipItem(
                      spot.y.toStringAsFixed(0),
                      Theme.of(context).textTheme.labelMedium!.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: activeCurrent,
                  isCurved: true,
                  color: colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colorScheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                LineChartBarData(
                  spots: activeComparison,
                  isCurved: true,
                  color: colorScheme.outline,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: const [6, 4],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
