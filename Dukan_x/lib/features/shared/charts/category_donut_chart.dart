import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

class CategoryDonutEntry {
  final String category;
  final double value;
  final Color? color;

  const CategoryDonutEntry({
    required this.category,
    required this.value,
    this.color,
  });
}

class CategoryDonutChart extends StatelessWidget {
  final List<CategoryDonutEntry>? data;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onCategoryTapped;

  const CategoryDonutChart({
    super.key,
    this.data,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) return const ShimmerChartArea();
    if (error != null) {
      return ErrorRetryWidget(message: error!, onRetry: onRetry ?? () {});
    }

    final items = data ?? const [];
    if (items.isEmpty || items.every((e) => e.value <= 0)) {
      return const IllustratedEmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No category data yet',
        subtitle: 'Category splits will appear here once sales are recorded.',
      );
    }

    final total = items.fold<double>(0, (sum, e) => sum + e.value);
    final palette = <Color>[
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideLegend = constraints.maxWidth >= 720;
        return Flex(
          direction: sideLegend ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: sideLegend ? constraints.maxWidth * 0.5 : constraints.maxWidth,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 68,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < items.length; i++)
                          PieChartSectionData(
                            value: items[i].value,
                            color: items[i].color ?? palette[i % palette.length],
                            radius: 72,
                            title: '${(items[i].value / total * 100).toStringAsFixed(0)}%',
                            titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final touched = response?.touchedSection;
                          if (event is! FlTapUpEvent || touched == null) return;
                          final index = touched.touchedSectionIndex;
                          if (index >= 0 && index < items.length) {
                            onCategoryTapped?.call(items[index].category);
                          }
                        },
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        total.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: sideLegend ? 20 : 0, height: sideLegend ? 0 : 16),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _LegendPill(
                      label: items[i].category,
                      value: items[i].value,
                      color: items[i].color ?? palette[i % palette.length],
                      onTap: onCategoryTapped == null
                          ? null
                          : () => onCategoryTapped!(items[i].category),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final VoidCallback? onTap;

  const _LegendPill({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            value.toStringAsFixed(0),
            style: textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: child);
  }
}
