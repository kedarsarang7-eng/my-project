import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Low Stock Alerts Screen
///
/// Shows all products that are running low on stock:
/// - Below reorder level
/// - Out of stock
/// - Quick reorder action
class LowStockAlertsScreen extends ConsumerStatefulWidget {
  const LowStockAlertsScreen({super.key});

  @override
  ConsumerState<LowStockAlertsScreen> createState() =>
      _LowStockAlertsScreenState();
}

class _LowStockAlertsScreenState extends ConsumerState<LowStockAlertsScreen> {
  bool _loading = true;
  List<Product> _lowStockProducts = [];
  String _filter = 'All';

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

      // Filter low stock and out of stock
      // Using lowStockThreshold from Product model
      _lowStockProducts = products
          .where(
            (p) =>
                p.stockQuantity <= p.lowStockThreshold || p.stockQuantity <= 0,
          )
          .toList();

      // Sort by urgency (out of stock first, then by how far below limit)
      _lowStockProducts.sort((a, b) {
        if (a.stockQuantity <= 0 && b.stockQuantity > 0) return -1;
        if (b.stockQuantity <= 0 && a.stockQuantity > 0) return 1;

        final aRatio = a.lowStockThreshold > 0
            ? a.stockQuantity / a.lowStockThreshold
            : 1.0;
        final bRatio = b.lowStockThreshold > 0
            ? b.stockQuantity / b.lowStockThreshold
            : 1.0;
        return aRatio.compareTo(bRatio);
      });

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    switch (_filter) {
      case 'Out of Stock':
        return _lowStockProducts.where((p) => p.stockQuantity <= 0).toList();
      case 'Low Stock':
        return _lowStockProducts.where((p) => p.stockQuantity > 0).toList();
      default:
        return _lowStockProducts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Low Stock Alerts',
      subtitle: '${_filtered.length} items need attention',
      actions: [
        // Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filter,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              items: [
                'All',
                'Out of Stock',
                'Low Stock',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) => setState(() => _filter = value ?? 'All'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          _buildSummary(isDark),
          const SizedBox(height: 24),
          Expanded(child: _buildList(isDark)),
        ],
      ),
    );
  }

  // Header removed as DesktopContentContainer handles it

  Widget _buildSummary(bool isDark) {
    final outOfStock = _lowStockProducts
        .where((p) => p.stockQuantity <= 0)
        .length;
    final lowStock = _lowStockProducts.where((p) => p.stockQuantity > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      child: Row(
        children: [
          _buildSummaryChip(
            'Out of Stock',
            '$outOfStock',
            const Color(0xFFEF4444),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            'Low Stock',
            '$lowStock',
            const Color(0xFFF59E0B),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            'Total Items',
            '${_lowStockProducts.length}',
            const Color(0xFF06B6D4),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 40,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All products in stock!',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No low stock alerts',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      itemBuilder: (context, index) =>
          _buildProductCard(_filtered[index], isDark),
    );
  }

  Widget _buildProductCard(Product product, bool isDark) {
    final isOutOfStock = product.stockQuantity <= 0;
    final stockPercent = product.lowStockThreshold > 0
        ? (product.stockQuantity / product.lowStockThreshold * 100).clamp(
            0.0,
            100.0,
          )
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : const Color(0xFFF59E0B).withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    (isOutOfStock
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B))
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOutOfStock ? Icons.error : Icons.warning_amber,
                color: isOutOfStock
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Stock: ${product.stockQuantity.toStringAsFixed(0)} ${product.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isOutOfStock
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Limit: ${product.lowStockThreshold.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stock Level Bar
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: stockPercent / 100,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOutOfStock
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${stockPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Reorder Button
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to stock entry with this product
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reorder ${product.name}')),
                );
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('Reorder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
