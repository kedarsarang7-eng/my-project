import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../models/dashboard_v2_models.dart';
import '../providers/dashboard_v2_providers.dart';

class InvoiceDistributionChart extends ConsumerWidget {
  const InvoiceDistributionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(dashboardV2InvoiceDistributionProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                  color: FuturisticColors.accent2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.donut_large_rounded,
                    color: FuturisticColors.accent2, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Invoice Distribution',
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          distAsync.when(
            data: (d) => d.isEmpty ? _buildEmpty() : _buildDonut(d),
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: FuturisticColors.accent2),
              ),
            ),
            // AUDIT FIX #4: Show error state with retry
            error: (_, _) => _buildErrorState(ref),
          ),
        ],
      ),
    );
  }

  Widget _buildDonut(InvoiceDistribution d) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: d.paid.toDouble(),
                      color: FuturisticColors.success,
                      radius: 28,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: d.pending.toDouble(),
                      color: FuturisticColors.warning,
                      radius: 28,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: d.overdue.toDouble(),
                      color: FuturisticColors.error,
                      radius: 28,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.totalInvoices.toString(),
                    style: TextStyle(
                      color: FuturisticColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DonutLegend(
              color: FuturisticColors.success,
              label: 'Paid',
              count: d.paid,
              percent: d.paidPercent,
            ),
            _DonutLegend(
              color: FuturisticColors.warning,
              label: 'Pending',
              count: d.pending,
              percent: d.pendingPercent,
            ),
            _DonutLegend(
              color: FuturisticColors.error,
              label: 'Overdue',
              count: d.overdue,
              percent: d.overduePercent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.donut_large_rounded,
                color: FuturisticColors.textSecondary.withValues(alpha: 0.3),
                size: 48),
            const SizedBox(height: 12),
            Text(
              'No invoices yet',
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
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: FuturisticColors.error.withValues(alpha: 0.4), size: 36),
            const SizedBox(height: 10),
            Text(
              'Failed to load distribution',
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(dashboardV2InvoiceDistributionProvider),
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

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int percent;

  const _DonutLegend({
    required this.color,
    required this.label,
    required this.count,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
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
        ),
        const SizedBox(height: 4),
        Text(
          '$count ($percent%)',
          style: TextStyle(
            color: FuturisticColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
