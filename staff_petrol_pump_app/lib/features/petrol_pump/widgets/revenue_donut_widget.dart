import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/revenue_provider.dart';
import '../theme/fuelpos_theme.dart';

/// Revenue Donut Chart Widget
class RevenueDonutWidget extends ConsumerWidget {
  const RevenueDonutWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueState = ref.watch(revenueProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Breakdown (Today)',
              style: TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: revenueState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : revenueState.error != null
                      ? _buildError(revenueState.error!)
                      : revenueState.breakdown == null
                          ? const Center(
                              child: Text(
                                'No data available',
                                style: TextStyle(color: FuelPOSTheme.textMuted),
                              ),
                            )
                          : _buildDonutChart(revenueState.breakdown!),
            ),
            const SizedBox(height: 16),
            if (revenueState.breakdown != null)
              _buildLegend(revenueState.breakdown!.segments),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: FuelPOSTheme.errorRed,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: FuelPOSTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(RevenueBreakdown breakdown) {
    final segments = breakdown.segments;

    if (segments.isEmpty || breakdown.totalRevenue == 0) {
      return const Center(
        child: Text(
          'No revenue data',
          style: TextStyle(color: FuelPOSTheme.textMuted),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 50,
            sections: segments.map((segment) {
              return PieChartSectionData(
                color: Color(segment.colorValue),
                value: segment.percent.toDouble(),
                title: '',
                radius: 40,
                showTitle: false,
              );
            }).toList(),
            pieTouchData: PieTouchData(enabled: false),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Total:',
              style: TextStyle(
                color: FuelPOSTheme.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              breakdown.formattedTotal,
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(List<RevenueSegment> segments) {
    return Column(
      children: segments.map((segment) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(segment.colorValue),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  segment.label,
                  style: const TextStyle(
                    color: FuelPOSTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${segment.percent}%',
                style: const TextStyle(
                  color: FuelPOSTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                segment.formattedValue,
                style: const TextStyle(
                  color: FuelPOSTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
