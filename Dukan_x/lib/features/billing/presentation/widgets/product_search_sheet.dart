// ============================================================================
// PRODUCT SEARCH SHEET - FUTURISTIC UI
// ============================================================================
// Search and select products from local inventory
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_bottom_sheet.dart';

class ProductSearchSheet extends StatefulWidget {
  final Function(Product) onProductSelected;
  final VoidCallback? onManualEntry;

  const ProductSearchSheet({
    super.key,
    required this.onProductSelected,
    this.onManualEntry,
  });

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final _searchController = TextEditingController();
  final _productsRepository = sl<ProductsRepository>();
  final _sessionManager = sl<SessionManager>();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final userId = _sessionManager.ownerId;
    if (userId == null) return;

    final result = await _productsRepository.getAll(userId: userId);
    if (mounted) {
      setState(() {
        _allProducts = result.data ?? [];
        _filteredProducts = _allProducts;
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassBottomSheet(
      height: MediaQuery.of(context).size.height * 0.75,
      title: 'Select Product',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search by name or SKU...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? Colors.black26
                    : Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: FuturisticColors.primary),
                ),
              ),
            ),
          ),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      return _buildProductTile(p, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Product p, bool isDark) {
    final isLowStock = p.stockQuantity <= p.lowStockThreshold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock
              ? Colors.orange.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Text(
            p.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          p.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Row(
          children: [
            Text('Price: ₹${p.sellingPrice}'),
            const SizedBox(width: 12),
            if (p.size != null || p.color != null) ...[
              Text(
                [
                  p.size,
                  p.color,
                ].where((e) => e != null && e.isNotEmpty).join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLowStock
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stock: ${p.stockQuantity} ${p.unit}',
                style: TextStyle(
                  fontSize: 11,
                  color: isLowStock ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
        onTap: () {
          widget.onProductSelected(p);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
                    Colors.purple.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: isDark ? Colors.white54 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              _searchController.text.isNotEmpty
                  ? 'No products match "${_searchController.text}"'
                  : 'No products in catalog',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              'You can add items manually without a product catalog',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Manual Entry Button (Primary Action)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onManualEntry?.call();
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Add Item Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Indigo
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary: Add to catalog (for future)
            TextButton.icon(
              onPressed: () {
                // Navigate to product creation
                Navigator.pop(context);
                context.push('/products/add');
              },
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add to Product Catalog'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
