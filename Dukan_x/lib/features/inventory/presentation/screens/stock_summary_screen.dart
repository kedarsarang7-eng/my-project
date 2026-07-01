import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Stock Summary Screen
///
/// Overview of entire inventory:
/// - Total stock value
/// - Category breakdown
/// - Stock health indicators
class StockSummaryScreen extends ConsumerStatefulWidget {
  const StockSummaryScreen({super.key});

  @override
  ConsumerState<StockSummaryScreen> createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends ConsumerState<StockSummaryScreen> {
  bool _loading = true;

  // Metrics
  double _totalStockValue = 0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  Map<String, double> _categoryValues = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final repo = sl<ProductsRepository>();
      final result = await repo.getAll(userId: userId);
      final products = result.data ?? [];

      _totalProducts = products.length;
      _totalStockValue = 0;
      _lowStockCount = 0;
      _outOfStockCount = 0;
      _categoryValues = {};

      for (final product in products) {
        final value = product.stockQuantity * product.costPrice;
        _totalStockValue += value;

        if (product.stockQuantity <= 0) {
          _outOfStockCount++;
        } else if (product.isLowStock) {
          _lowStockCount++;
        }

        // Category breakdown
        final category = product.category ?? 'Uncategorized';
        _categoryValues[category] = (_categoryValues[category] ?? 0) + value;
      }

      // Sort categories by value
      final sortedEntries = _categoryValues.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _categoryValues = Map.fromEntries(sortedEntries.take(10));

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Stock Summary',
      subtitle: '$_totalProducts products in inventory',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ), // Padding handled by container usually, but extra safe
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header removed
                  const SizedBox(height: 12),
                  _buildMainMetric(isDark),
                  const SizedBox(height: 24),
                  _buildHealthIndicators(isDark),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdown(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildMainMetric(bool isDark) {
    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 20, // Fixed: double
      child: Container(
        padding: const EdgeInsets.all(32),
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Stock Value',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_formatAmount(_totalStockValue)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on cost price',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ModernCard(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 32,
                            color: FuturisticColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Total Products",
                            style: TextStyle(color: FuturisticColors.textSecondary),
                          ),
                          Text(
                            "$_totalProducts",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: FuturisticColors.textPrimary,
                            ),
                          ),
                          Text(
                            "items in stock",
                            style: TextStyle(
                              fontSize: 12,
                              color: FuturisticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Stock Value',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_formatAmount(_totalStockValue)}',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on cost price',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ModernCard(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 32,
                          color: FuturisticColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Total Products",
                          style: TextStyle(color: FuturisticColors.textSecondary),
                        ),
                        Text(
                          "$_totalProducts",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                        Text(
                          "items in stock",
                          style: TextStyle(
                            fontSize: 12,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHealthIndicators(bool isDark) {
    if (context.isMobile) {
      return Column(
        children: [
          _buildIndicatorCard(
            'Low Stock',
            _lowStockCount,
            const Color(0xFFF59E0B),
            Icons.warning_amber,
            isDark,
          ),
          const SizedBox(height: 16),
          _buildIndicatorCard(
            'Out of Stock',
            _outOfStockCount,
            const Color(0xFFEF4444),
            Icons.remove_circle,
            isDark,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildIndicatorCard(
            'Low Stock',
            _lowStockCount,
            const Color(0xFFF59E0B),
            Icons.warning_amber,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildIndicatorCard(
            'Out of Stock',
            _outOfStockCount,
            const Color(0xFFEF4444),
            Icons.remove_circle,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorCard(
    String label,
    int count,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0
              ? color.withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: count > 0
                  ? color
                  : (isDark ? Colors.white38 : Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: _categoryValues.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No category data',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: _categoryValues.entries
                      .map((e) => _buildCategoryRow(e.key, e.value, isDark))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String category, double value, bool isDark) {
    final percent = _totalStockValue > 0
        ? (value / _totalStockValue * 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
              Text(
                '₹${_formatAmount(value)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
          ),
          const SizedBox(height: 4),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
