import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userId = sl<SessionManager>().ownerId ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        title: Text('${widget.category} Products'),
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<Product>>(
        stream: sl<ProductsRepository>().watchAll(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allProducts = snapshot.data ?? [];
          final products = allProducts
              .where(
                (p) =>
                    (p.category ?? '').toLowerCase() ==
                    widget.category.toLowerCase(),
              )
              .toList();

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No products found in ${widget.category}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product, isDark);
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildProductCard(Product p, bool isDark) {
    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₹${p.sellingPrice} | Stock: ${p.stockQuantity} ${p.unit}',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
