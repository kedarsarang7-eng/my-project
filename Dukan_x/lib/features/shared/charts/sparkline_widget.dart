import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SparklineWidget extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color? lineColor;
  final Color? fillColor;

  const SparklineWidget({
    super.key,
    required this.values,
    this.height = 42,
    this.lineColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final line = lineColor ?? colorScheme.primary;
    final fill = fillColor ?? line.withValues(alpha: 0.14);

    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Icon(Icons.trending_flat, color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: values.reduce((a, b) => a < b ? a : b),
          maxY: values.reduce((a, b) => a > b ? a : b),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: line,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: fill),
            ),
          ],
        ),
      ),
    );
  }
}
