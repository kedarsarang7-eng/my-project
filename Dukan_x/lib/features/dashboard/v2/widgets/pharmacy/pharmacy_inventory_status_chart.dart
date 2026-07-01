import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyInventoryStatusChart extends ConsumerWidget {
  const PharmacyInventoryStatusChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(pharmacyInventoryStatusProvider);

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
            child: inventoryAsync.when(
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
            color: FuturisticColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: FuturisticColors.warning,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Stock level distribution',
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

  Widget _buildChart(BuildContext context, InventoryStatusData data) {
    if (data.isEmpty) {
      return _buildEmptyChart();
    }

    // Check if all values are zero
    if (data.inStockPercent == 0 && data.lowStockPercent == 0 && data.outOfStockPercent == 0) {
      return _buildEmptyChart();
    }

    return Column(
      children: [
        // Donut Chart
        Expanded(
          flex: 3,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    // Handle touch events if needed
                  },
                ),
                startDegreeOffset: -90,
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: [
                  // In Stock
                  PieChartSectionData(
                    color: FuturisticColors.success,
                    value: data.inStockPercent,
                    title: '${data.inStockPercent.toStringAsFixed(1)}%',
                    radius: 50,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    badgeWidget: _Badge(
                      color: FuturisticColors.success,
                      text: 'In Stock',
                    ),
                    badgePositionPercentageOffset: .98,
                  ),
                  // Low Stock
                  if (data.lowStockPercent > 0)
                    PieChartSectionData(
                      color: FuturisticColors.warning,
                      value: data.lowStockPercent,
                      title: '${data.lowStockPercent.toStringAsFixed(1)}%',
                      radius: 50,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      badgeWidget: _Badge(
                        color: FuturisticColors.warning,
                        text: 'Low Stock',
                      ),
                      badgePositionPercentageOffset: .98,
                    ),
                  // Out of Stock
                  if (data.outOfStockPercent > 0)
                    PieChartSectionData(
                      color: FuturisticColors.error,
                      value: data.outOfStockPercent,
                      title: '${data.outOfStockPercent.toStringAsFixed(1)}%',
                      radius: 50,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      badgeWidget: _Badge(
                        color: FuturisticColors.error,
                        text: 'Out of Stock',
                      ),
                      badgePositionPercentageOffset: .98,
                    ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Legend
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: FuturisticColors.success,
                label: 'In Stock',
                percentage: data.inStockPercent,
              ),
              if (data.lowStockPercent > 0) ...[
                const SizedBox(height: 8),
                _LegendItem(
                  color: FuturisticColors.warning,
                  label: 'Low Stock',
                  percentage: data.lowStockPercent,
                ),
              ],
              if (data.outOfStockPercent > 0) ...[
                const SizedBox(height: 8),
                _LegendItem(
                  color: FuturisticColors.error,
                  label: 'Out of Stock',
                  percentage: data.outOfStockPercent,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingChart() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: FuturisticColors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading inventory data...',
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
          Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load inventory data',
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
            Icons.inventory_2_rounded,
            size: 48,
            color: FuturisticColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No inventory data available',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge Widget for Chart Sections ─────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final Color color;
  final String text;

  const _Badge({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Legend Item Widget ─────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: FuturisticColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
