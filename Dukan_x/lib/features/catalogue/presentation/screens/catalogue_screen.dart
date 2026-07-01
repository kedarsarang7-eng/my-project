import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/empty_state.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Catalogue Screen - Redesigned for Desktop
///
/// Features:
/// - No standalone Scaffold - integrates with EnterpriseDesktopShell
/// - Grid layout for product selection
/// - Premium selection cards with glow effect
/// - Share to WhatsApp functionality
class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _db = sl<AppDatabase>();
  final _session = sl<SessionManager>();

  List<ProductEntity> _allProducts = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final userId = _session.ownerId;
    if (userId == null) return;

    final products = await _db.getAllProducts(userId);

    if (mounted) {
      setState(() {
        _allProducts = products.where((p) => p.stockQuantity > 0).toList();
        _isLoading = false;
      });
    }
  }

  List<ProductEntity> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    return _allProducts
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredProducts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredProducts.map((p) => p.id));
      }
    });
  }

  void _shareCatalogue() async {
    if (_selectedIds.isEmpty) return;

    final selectedProducts = _allProducts
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    if (selectedProducts.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("🌟 *Fresh Stock Update* 🌟");
    buffer.writeln("Check out our latest arrivals:\n");

    for (var i = 0; i < selectedProducts.length; i++) {
      final p = selectedProducts[i];
      buffer.writeln("${i + 1}. *${p.name}*");
      buffer.writeln("   💰 ₹${p.sellingPrice}/${p.unit}");
      buffer.writeln("");
    }

    buffer.writeln("\n📞 *Order Reply to this message!*");
    buffer.writeln("Powered by DukanX");

    await Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Share Catalogue',
      subtitle: 'Select items to share with your customers',
      actions: [
        if (_selectedIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FuturisticColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(
                color: FuturisticColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        DesktopIconButton(
          icon: Icons.select_all_rounded,
          tooltip: 'Select All',
          onPressed: _selectAll,
        ),
        // On mobile, show icon-only share button; on desktop show full label
        if (context.isMobile)
          DesktopIconButton(
            icon: Icons.share_rounded,
            tooltip: 'Share to WhatsApp',
            onPressed: _selectedIds.isNotEmpty ? _shareCatalogue : null,
            color: FuturisticColors.success,
          )
        else
          DesktopActionButton(
            icon: Icons.share_rounded,
            label: 'Share to WhatsApp',
            onPressed: _selectedIds.isNotEmpty ? _shareCatalogue : null,
            isPrimary: true,
            color: FuturisticColors.success,
          ),
      ],
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.only(bottom: 20),
            margin: EdgeInsets.symmetric(
              horizontal: responsiveValue<double>(
                context,
                mobile: 12,
                desktop: 0,
              ),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: FuturisticColors.textSecondary),
                prefixIcon: Icon(
                  Icons.search,
                  color: FuturisticColors.textSecondary,
                ),
                filled: true,
                fillColor: FuturisticColors.surface.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FuturisticColors.border.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FuturisticColors.border.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FuturisticColors.premiumBlue.withOpacity(0.5),
                  ),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Products Grid
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: FuturisticColors.premiumBlue,
                    ),
                  )
                : _filteredProducts.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Products Found',
                    description:
                        'Your inventory is empty or all items are out of stock.',
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: responsiveValue<int>(
                        context,
                        mobile: 1,
                        tablet: 2,
                        desktop:
                            4, // PRESERVED: Desktop uses exactly 4 as before
                      ),
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final isSelected = _selectedIds.contains(product.id);
                      return _buildProductCard(product, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductEntity product, bool isSelected) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _toggleSelection(product.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? FuturisticColors.success.withOpacity(0.15)
                : FuturisticColors.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? FuturisticColors.success.withOpacity(0.5)
                  : FuturisticColors.border.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: FuturisticColors.success.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header with checkbox
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FuturisticColors.success.withOpacity(0.2)
                          : FuturisticColors.premiumBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        product.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? FuturisticColors.success
                              : FuturisticColors.premiumBlue,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FuturisticColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? FuturisticColors.success
                            : FuturisticColors.textSecondary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),

              // Product Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.sellingPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FuturisticColors.success,
                        ),
                      ),
                      Text(
                        ' / ${product.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: FuturisticColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FuturisticColors.premiumBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Stock: ${product.stockQuantity}',
                          style: TextStyle(
                            fontSize: 10,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
