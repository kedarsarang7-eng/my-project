// ============================================================================
// FOOD MENU MANAGEMENT SCREEN (VENDOR) - PREMIUM FUTURISTIC UI
// ============================================================================
// All existing functionality preserved:
// - Menu items CRUD, Category management
// - Availability toggle, Filtering
// - Reorder categories
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/models/food_menu_item_model.dart';
import '../../data/models/food_category_model.dart';
import '../../data/repositories/food_menu_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class FoodMenuManagementScreen extends StatefulWidget {
  final String vendorId;

  const FoodMenuManagementScreen({super.key, required this.vendorId});

  @override
  State<FoodMenuManagementScreen> createState() =>
      _FoodMenuManagementScreenState();
}

class _FoodMenuManagementScreenState extends State<FoodMenuManagementScreen>
    with SingleTickerProviderStateMixin {
  final FoodMenuRepository _repository = FoodMenuRepository();
  late TabController _tabController;

  String? _selectedCategoryId;
  bool _isLoading = true;
  List<FoodCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await _repository.getCategoriesByVendor(widget.vendorId);
    if (result.success && result.data != null) {
      setState(() {
        _categories = result.data!;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: _buildPremiumAppBar(context, isDark),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
          controller: _tabController,
          children: [_buildMenuItemsTab(isDark), _buildCategoriesTab(isDark)],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppGradients.accentGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              boxShadow: AppShadows.glowShadow(FuturisticColors.accent1),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Menu Management',
            style: AppTypography.headlineMedium.copyWith(
              color: isDark
                  ? FuturisticColors.darkTextPrimary
                  : FuturisticColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: FuturisticColors.primary,
        labelColor: FuturisticColors.primary,
        unselectedLabelColor: isDark
            ? FuturisticColors.darkTextSecondary
            : FuturisticColors.textSecondary,
        labelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu Items'),
          Tab(icon: Icon(Icons.category), text: 'Categories'),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: FuturisticColors.primary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: FuturisticColors.primary,
            ),
            onPressed: () => _showAddItemDialog(),
            tooltip: 'Add Item',
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsTab(bool isDark) {
    return Column(
      children: [
        // Category filter
        _buildCategoryFilter(isDark),
        // Menu items list
        Expanded(
          child: StreamBuilder<List<FoodMenuItem>>(
            stream: _repository.watchMenuItems(widget.vendorId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FuturisticColors.primary,
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? [];
              final filteredItems = _selectedCategoryId != null
                  ? items
                        .where((i) => i.categoryId == _selectedCategoryId)
                        .toList()
                  : items;

              if (filteredItems.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) =>
                    _buildMenuItemCard(filteredItems[index], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? FuturisticColors.darkSurfaceVariant
            : FuturisticColors.surfaceVariant,
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 18,
            color: isDark
                ? FuturisticColors.darkTextSecondary
                : FuturisticColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', _selectedCategoryId == null, () {
                    setState(() => _selectedCategoryId = null);
                  }, isDark),
                  const SizedBox(width: AppSpacing.sm),
                  ..._categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _buildFilterChip(
                        cat.name,
                        _selectedCategoryId == cat.id,
                        () => setState(() => _selectedCategoryId = cat.id),
                        isDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primaryGradient : null,
          color: selected
              ? null
              : (isDark
                    ? FuturisticColors.darkSurface
                    : FuturisticColors.surface),
          borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? FuturisticColors.darkDivider
                      : FuturisticColors.divider,
                ),
          boxShadow: selected
              ? AppShadows.glowShadow(FuturisticColors.primary)
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected
                ? Colors.white
                : (isDark
                      ? FuturisticColors.darkTextPrimary
                      : FuturisticColors.textPrimary),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(FoodMenuItem item, bool isDark) {
    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      onTap: () => _editItem(item),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Image
          item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  child: Image.network(
                    item.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
                  ),
                )
              : _buildPlaceholder(isDark),
          const SizedBox(width: AppSpacing.md),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextPrimary
                              : FuturisticColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.isVegetarian)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: FuturisticColors.success),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.eco,
                          size: 14,
                          color: FuturisticColors.success,
                        ),
                      ),
                    if (item.isSpicy)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('🌶️'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '₹${item.price.toStringAsFixed(2)}',
                  style: AppTypography.labelMedium.copyWith(
                    color: FuturisticColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.preparationTimeMinutes != null)
                  Text(
                    '${item.preparationTimeMinutes} min prep',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark
                          ? FuturisticColors.darkTextSecondary
                          : FuturisticColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // Availability toggle
          Switch(
            value: item.isAvailable,
            activeColor: FuturisticColors.success,
            onChanged: (value) => _toggleAvailability(item.id, value),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppGradients.glassGradient,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Icon(
        Icons.restaurant,
        color: isDark
            ? FuturisticColors.darkTextSecondary
            : FuturisticColors.textSecondary,
      ),
    );
  }

  Widget _buildCategoriesTab(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(FuturisticColors.primary),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          borderRadius: AppBorderRadius.xxl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppGradients.secondaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glowShadow(FuturisticColors.secondary),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No categories yet',
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextPrimary
                      : FuturisticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassButton(
                label: 'Add Category',
                icon: Icons.add,
                gradient: AppGradients.secondaryGradient,
                onPressed: _showAddCategoryDialog,
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _categories.length,
      onReorder: _reorderCategories,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return ModernCard(
          key: ValueKey(category.id),
          backgroundColor: isDark
              ? FuturisticColors.darkSurface
              : FuturisticColors.surface,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppGradients.secondaryGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: AppTypography.labelLarge.copyWith(
                        color: isDark
                            ? FuturisticColors.darkTextPrimary
                            : FuturisticColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (category.description != null)
                      Text(
                        category.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.drag_handle,
                color: isDark
                    ? FuturisticColors.darkTextSecondary
                    : FuturisticColors.textSecondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        borderRadius: AppBorderRadius.xxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppGradients.accentGradient,
                shape: BoxShape.circle,
                boxShadow: AppShadows.glowShadow(FuturisticColors.accent1),
              ),
              child: const Icon(
                Icons.restaurant_menu_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No menu items yet',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first menu item to get started',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextSecondary
                    : FuturisticColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              label: 'Add Menu Item',
              icon: Icons.add,
              gradient: AppGradients.accentGradient,
              onPressed: _showAddItemDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(String itemId, bool isAvailable) async {
    await _repository.setItemAvailability(itemId, isAvailable);
  }

  void _editItem(FoodMenuItem item) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());
    final descCtrl = TextEditingController(text: item.description ?? '');
    final prepTimeCtrl = TextEditingController(
      text: item.preparationTimeMinutes?.toString() ?? '',
    );
    bool isVeg = item.isVegetarian;
    bool isSpicy = item.isSpicy;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Menu Item'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (₹)'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) {
                        return 'Please enter a valid numeric price';
                      }
                      if (parsed <= 0) {
                        return 'Please enter a valid price greater than ₹0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: prepTimeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time (minutes)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isVeg,
                        onChanged: (v) => setDialogState(() => isVeg = v!),
                      ),
                      const Text('Vegetarian'),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: isSpicy,
                        onChanged: (v) => setDialogState(() => isSpicy = v!),
                      ),
                      const Text('Spicy'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final price = double.parse(priceCtrl.text.trim());
                final prepTime = int.tryParse(prepTimeCtrl.text);
                await _repository.updateMenuItem(
                  id: item.id,
                  name: nameCtrl.text.trim(),
                  price: price,
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  preparationTimeMinutes: prepTime,
                  isVegetarian: isVeg,
                  isSpicy: isSpicy,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final prepTimeCtrl = TextEditingController();
    bool isVeg = false;
    bool isSpicy = false;
    String? selectedCategoryId = _selectedCategoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Menu Item'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Item Name *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (₹) *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) {
                        return 'Please enter a valid numeric price';
                      }
                      if (parsed <= 0) {
                        return 'Please enter a valid price greater than ₹0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: prepTimeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time (minutes)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isVeg,
                        onChanged: (v) => setDialogState(() => isVeg = v!),
                      ),
                      const Text('Vegetarian'),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: isSpicy,
                        onChanged: (v) => setDialogState(() => isSpicy = v!),
                      ),
                      const Text('Spicy'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                final price = double.parse(priceCtrl.text.trim());
                final prepTime = int.tryParse(prepTimeCtrl.text);
                await _repository.createMenuItem(
                  vendorId: widget.vendorId,
                  name: nameCtrl.text.trim(),
                  price: price,
                  categoryId: selectedCategoryId,
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  preparationTimeMinutes: prepTime,
                  isVegetarian: isVeg,
                  isSpicy: isSpicy,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Category name required')),
                );
                return;
              }
              await _repository.createCategory(
                vendorId: widget.vendorId,
                name: nameCtrl.text,
                description: descCtrl.text.isEmpty ? null : descCtrl.text,
                sortOrder: _categories.length,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadCategories(); // Refresh categories
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    // Persist the new sort order to the repository
    _repository.updateCategorySortOrder(_categories);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
