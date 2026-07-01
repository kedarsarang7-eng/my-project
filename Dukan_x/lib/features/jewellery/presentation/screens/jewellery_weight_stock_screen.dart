import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Jewellery Weight Stock Screen (Requirement 13.5)
///
/// Presents stock by metal weight (grams) rather than quantity only.
/// Groups products by metal type and displays total weight per group,
/// alongside individual item weights. This is the jewellery-specific
/// replacement for the generic StockSummaryScreen when business type
/// is jewellery.
///
/// Blast radius: NONE — only rendered for BusinessType.jewellery via
/// the navigation handler's gated branch. Other business types continue
/// to receive the generic StockSummaryScreen unchanged.
class JewelleryWeightStockScreen extends StatefulWidget {
  const JewelleryWeightStockScreen({super.key});

  @override
  State<JewelleryWeightStockScreen> createState() =>
      _JewelleryWeightStockScreenState();
}

class _JewelleryWeightStockScreenState
    extends State<JewelleryWeightStockScreen> {
  bool _loading = true;
  String? _error;

  // Aggregated weight data by metal type
  final Map<MetalType, _MetalStockGroup> _metalGroups = {};
  double _totalWeightGrams = 0;
  int _totalItems = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = JewelleryRepositoryOffline(sl(), sl<SessionManager>());
      final products = await repo.getProducts();

      _metalGroups.clear();
      _totalWeightGrams = 0;
      _totalItems = 0;
      _lowStockCount = 0;
      _outOfStockCount = 0;

      for (final product in products) {
        _totalItems++;

        if (product.isOutOfStock) {
          _outOfStockCount++;
        } else if (product.isLowStock) {
          _lowStockCount++;
        }

        // Use gross weight as the primary weight metric for stock
        final weightPerItem = product.grossWeightGrams > 0
            ? product.grossWeightGrams
            : product.metalWeightGrams;
        final totalWeight = weightPerItem * product.stockQuantity;

        _totalWeightGrams += totalWeight;

        final group = _metalGroups.putIfAbsent(
          product.metalType,
          () => _MetalStockGroup(metalType: product.metalType),
        );
        group.totalWeightGrams += totalWeight;
        group.totalItems += product.stockQuantity;
        group.productCount++;
        group.products.add(product);
      }

      // Sort groups by total weight descending
      final sorted = _metalGroups.entries.toList()
        ..sort(
          (a, b) =>
              b.value.totalWeightGrams.compareTo(a.value.totalWeightGrams),
        );
      _metalGroups
        ..clear()
        ..addEntries(sorted);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load stock data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Stock by Weight',
      subtitle: 'Metal weight summary across inventory',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: FuturisticColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: FuturisticColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildTotalWeightCard(isDark),
                  const SizedBox(height: 24),
                  _buildHealthIndicators(isDark),
                  const SizedBox(height: 24),
                  _buildMetalBreakdown(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalWeightCard(bool isDark) {
    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 20,
      child: Container(
        padding: const EdgeInsets.all(32),
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalWeightInfo(isDark, fontSize: 32),
                  const SizedBox(height: 24),
                  _buildTotalItemsCard(isDark),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _buildTotalWeightInfo(isDark, fontSize: 40)),
                  _buildTotalItemsCard(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildTotalWeightInfo(bool isDark, {required double fontSize}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Metal Weight',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_totalWeightGrams.toStringAsFixed(2)} g',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Across ${_metalGroups.length} metal types',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalItemsCard(bool isDark) {
    return ModernCard(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.scale, size: 32, color: FuturisticColors.primary),
          const SizedBox(height: 8),
          Text(
            'Total Items',
            style: TextStyle(color: FuturisticColors.textSecondary),
          ),
          Text(
            '$_totalItems',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          Text(
            'products in stock',
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
            ),
          ),
        ],
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

  Widget _buildMetalBreakdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metal Weight Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (_metalGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[200]!,
              ),
            ),
            child: Center(
              child: Text(
                'No stock data available',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          ..._metalGroups.entries.map(
            (e) => _buildMetalGroupCard(e.value, isDark),
          ),
      ],
    );
  }

  Widget _buildMetalGroupCard(_MetalStockGroup group, bool isDark) {
    final percent = _totalWeightGrams > 0
        ? (group.totalWeightGrams / _totalWeightGrams * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _metalColor(group.metalType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _metalIcon(group.metalType),
                  color: _metalColor(group.metalType),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.metalType.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${group.productCount} products • ${group.totalItems} pcs',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${group.totalWeightGrams.toStringAsFixed(2)} g',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _metalColor(group.metalType),
            ),
          ),
        ],
      ),
    );
  }

  Color _metalColor(MetalType type) {
    switch (type) {
      case MetalType.gold24k:
        return const Color(0xFFFFD700);
      case MetalType.gold22k:
        return const Color(0xFFDAA520);
      case MetalType.gold18k:
        return const Color(0xFFB8860B);
      case MetalType.gold14k:
        return const Color(0xFFCD853F);
      case MetalType.gold9k:
        return const Color(0xFFD2691E);
      case MetalType.silver:
        return const Color(0xFFC0C0C0);
      case MetalType.platinum:
        return const Color(0xFFE5E4E2);
      case MetalType.diamond:
        return const Color(0xFFB9F2FF);
      case MetalType.other:
        return const Color(0xFF78909C);
    }
  }

  IconData _metalIcon(MetalType type) {
    switch (type) {
      case MetalType.gold24k:
      case MetalType.gold22k:
      case MetalType.gold18k:
      case MetalType.gold14k:
      case MetalType.gold9k:
        return Icons.circle;
      case MetalType.silver:
        return Icons.circle_outlined;
      case MetalType.platinum:
        return Icons.diamond_outlined;
      case MetalType.diamond:
        return Icons.diamond;
      case MetalType.other:
        return Icons.category;
    }
  }
}

/// Internal model grouping stock data by metal type
class _MetalStockGroup {
  final MetalType metalType;
  double totalWeightGrams = 0;
  int totalItems = 0;
  int productCount = 0;
  final List<JewelleryProduct> products = [];

  _MetalStockGroup({required this.metalType});
}
