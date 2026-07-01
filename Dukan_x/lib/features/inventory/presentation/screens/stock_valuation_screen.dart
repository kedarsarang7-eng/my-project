import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Stock Valuation Screen
///
/// Shows inventory valuation:
/// - Total value at cost
/// - Total value at selling price
/// - Profit margin
/// - Category breakdown
class StockValuationScreen extends ConsumerStatefulWidget {
  const StockValuationScreen({super.key});

  @override
  ConsumerState<StockValuationScreen> createState() =>
      _StockValuationScreenState();
}

class _StockValuationScreenState extends ConsumerState<StockValuationScreen> {
  bool _loading = true;

  double _totalCostValue = 0;
  double _totalSellingValue = 0;
  double _potentialProfit = 0;
  double _marginPercent = 0;
  int _productCount = 0;
  List<_ProductValuation> _topProducts = [];

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

      _productCount = products.where((p) => p.stockQuantity > 0).length;
      _totalCostValue = 0;
      _totalSellingValue = 0;

      final valuations = <_ProductValuation>[];

      for (final product in products) {
        if (product.stockQuantity > 0) {
          final costValue = product.stockQuantity * product.costPrice;
          final sellValue = product.stockQuantity * product.sellingPrice;

          _totalCostValue += costValue;
          _totalSellingValue += sellValue;

          valuations.add(
            _ProductValuation(
              name: product.name,
              quantity: product.stockQuantity,
              unit: product.unit,
              costValue: costValue,
              sellValue: sellValue,
              margin: sellValue > 0
                  ? ((sellValue - costValue) / sellValue * 100)
                  : 0,
            ),
          );
        }
      }

      _potentialProfit = _totalSellingValue - _totalCostValue;
      _marginPercent = _totalSellingValue > 0
          ? (_potentialProfit / _totalSellingValue * 100)
          : 0;

      // Sort by value and take top 10
      valuations.sort((a, b) => b.sellValue.compareTo(a.sellValue));
      _topProducts = valuations.take(10).toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Stock Valuation',
      subtitle: '$_productCount products with stock',
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildValuationCards(isDark),
                  const SizedBox(height: 24),
                  _buildTopProducts(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildValuationCards(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCard(
                'Cost Value',
                '₹${_formatAmount(_totalCostValue)}',
                'At purchase price',
                const Color(0xFF06B6D4),
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCard(
                'Selling Value',
                '₹${_formatAmount(_totalSellingValue)}',
                'At MRP',
                const Color(0xFF10B981),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildCard(
                'Potential Profit',
                '₹${_formatAmount(_potentialProfit)}',
                'If sold at MRP',
                _potentialProfit >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCard(
                'Gross Margin',
                '${_marginPercent.toStringAsFixed(1)}%',
                'Profit margin',
                const Color(0xFF8B5CF6),
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(
    String title,
    String value,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 16, // Fixed: double
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 22, tablet: 24, desktop: 28),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Products by Value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: _topProducts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: ModernCard(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 48,
                          color: FuturisticColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Total Valuation",
                          style: TextStyle(
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                        Text(
                          "${sl<CurrencyService>().symbol}${_totalSellingValue.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                        Text(
                          "$_productCount items in inventory",
                          style: TextStyle(
                            fontSize: 12,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _topProducts.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[200],
                  ),
                  itemBuilder: (context, index) =>
                      _buildProductRow(_topProducts[index], index + 1, isDark),
                ),
        ),
      ],
    );
  }

  Widget _buildProductRow(_ProductValuation product, int rank, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF06B6D4),
            ),
          ),
        ),
      ),
      title: Text(
        product.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        '${product.quantity.toStringAsFixed(0)} ${product.unit} • Margin: ${product.margin.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.grey[600],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${_formatAmount(product.sellValue)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            'Cost: ₹${_formatAmount(product.costValue)}',
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

class _ProductValuation {
  final String name;
  final double quantity;
  final String unit;
  final double costValue;
  final double sellValue;
  final double margin;

  _ProductValuation({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.costValue,
    required this.sellValue,
    required this.margin,
  });
}
