import 'package:flutter/material.dart';

import '../widgets/error_retry_widget.dart';
import '../widgets/illustrated_empty_state.dart';
import '../widgets/shimmer_loading.dart';

class StockHeatmapGrid extends StatelessWidget {
  final List<String> rowLabels;
  final List<String> columnLabels;
  final List<List<double>> values;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<(int row, int col)>? onCellTapped;

  const StockHeatmapGrid({
    super.key,
    required this.rowLabels,
    required this.columnLabels,
    required this.values,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onCellTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ShimmerChartArea(height: 300);
    if (error != null) {
      return ErrorRetryWidget(message: error!, onRetry: onRetry ?? () {});
    }
    if (rowLabels.isEmpty || columnLabels.isEmpty || values.isEmpty) {
      return const IllustratedEmptyState(
        icon: Icons.grid_4x4_outlined,
        title: 'No heatmap data yet',
        subtitle: 'A stock heatmap will appear once size/category counts are available.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.35)),
                  children: [
                    _HeaderCell(label: ''),
                    for (final col in columnLabels) _HeaderCell(label: col),
                  ],
                ),
                for (var r = 0; r < rowLabels.length; r++)
                  TableRow(
                    children: [
                      _HeaderCell(label: rowLabels[r], alignLeft: true),
                      for (var c = 0; c < columnLabels.length; c++)
                        _HeatCell(
                          value: values[r][c],
                          maxWidth: width,
                          onTap: onCellTapped == null ? null : () => onCellTapped!((r, c)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool alignLeft;

  const _HeaderCell({required this.label, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double value;
  final double maxWidth;
  final VoidCallback? onTap;

  const _HeatCell({required this.value, required this.maxWidth, this.onTap});

  Color _colorForValue(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = value.clamp(0, 1);
    if (t < 0.5) {
      final localT = t / 0.5;
      return Color.lerp(const Color(0xFF10B981), const Color(0xFFF59E0B), localT)!;
    }
    final localT = (t - 0.5) / 0.5;
    return Color.lerp(const Color(0xFFF59E0B), cs.error, localT)!;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForValue(context);
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: (maxWidth / 10).clamp(56.0, 100.0),
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
        ),
        alignment: Alignment.center,
        child: Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
