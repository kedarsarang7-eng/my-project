import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyPrescriptionsCategoryChart extends ConsumerWidget {
  const PharmacyPrescriptionsCategoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(pharmacyPrescriptionsCategoryProvider);

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
            child: categoryAsync.when(
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
            color: FuturisticColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.medication_rounded,
            color: FuturisticColors.info,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prescriptions by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Weekly breakdown by medication type',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, PrescriptionsByCategoryData data) {
    if (data.isEmpty || data.categories.isEmpty) {
      return _buildEmptyChart();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(data.counts),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                FuturisticColors.textPrimary.withValues(alpha: 0.9),
            // tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = data.categories[group.x.toInt()];
              final count = data.counts[group.x.toInt()];
              return BarTooltipItem(
                '$category\n$count prescriptions',
                TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < data.categories.length) {
                  final category = data.categories[value.toInt()];
                  return SideTitleWidget(
                    meta: meta,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _formatCategoryName(category),
                        style: TextStyle(
                          fontSize: 10,
                          color: FuturisticColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
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
        barGroups: List.generate(
          data.categories.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.counts[index].toDouble(),
                color: _getCategoryColor(data.categories[index]),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateGridInterval(data.counts),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
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
          CircularProgressIndicator(color: FuturisticColors.info),
          const SizedBox(height: 16),
          Text(
            'Loading prescription data...',
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
            'Unable to load prescription data',
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
            Icons.medication_rounded,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No prescription data available',
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

  double _calculateMaxY(List<int> counts) {
    if (counts.isEmpty) return 10;
    final maxValue = counts.reduce((a, b) => a > b ? a : b);
    return maxValue * 1.2; // Add 20% padding
  }

  double _calculateGridInterval(List<int> counts) {
    if (counts.isEmpty) return 5;
    final maxValue = counts.reduce((a, b) => a > b ? a : b);
    return maxValue / 5; // 5 horizontal lines
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'anti-biotics':
      case 'antibiotics':
        return FuturisticColors.primary;
      case 'cardiovascular':
        return FuturisticColors.error;
      case 'analgesics':
        return FuturisticColors.warning;
      case 'otc':
      case 'over the counter':
        return FuturisticColors.success;
      case 'vitamins':
        return FuturisticColors.info;
      case 'diabetes':
        return Colors.purple;
      default:
        return FuturisticColors.textSecondary;
    }
  }

  String _formatCategoryName(String category) {
    // Shorten category names for better display
    switch (category.toLowerCase()) {
      case 'anti-biotics':
      case 'antibiotics':
        return 'Anti-\nBiotics';
      case 'cardiovascular':
        return 'Cardio-\nvascular';
      case 'analgesics':
        return 'Analgesics';
      case 'otc':
      case 'over the counter':
        return 'OTC';
      case 'vitamins':
        return 'Vitamins';
      case 'diabetes':
        return 'Diabetes';
      default:
        // Split long words
        if (category.length > 8) {
          final mid = category.length ~/ 2;
          return '${category.substring(0, mid)}-\n${category.substring(mid)}';
        }
        return category;
    }
  }
}
