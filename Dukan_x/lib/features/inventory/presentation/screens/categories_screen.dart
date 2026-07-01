import 'package:flutter/material.dart';
import 'category_products_screen.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sessionManager.userId ?? '';

    return DesktopContentContainer(
      title: 'Category Management',
      actions: [
        DesktopActionButton(
          icon: Icons.add,
          label: 'Add Category',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("To add a category, assign it to a product."),
              ),
            );
          },
        ),
      ],
      child: userId.isEmpty
          ? const Center(child: Text("User not logged in"))
          : StreamBuilder<List<String>>(
              stream: sl<ProductsRepository>().watchUniqueCategories(
                userId: userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final categories = snapshot.data ?? [];

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 64,
                          color: FuturisticColors.textSecondary.withOpacity(
                            0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No categories found',
                          style: TextStyle(
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Categories are created automatically when adding products.',
                          style: TextStyle(
                            color: FuturisticColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      color: FuturisticColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: FuturisticColors.accent1.withOpacity(
                            0.2,
                          ),
                          child: Text(
                            category.isNotEmpty
                                ? category[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: FuturisticColors.accent1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: FuturisticColors.textSecondary,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryProductsScreen(category: category),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
