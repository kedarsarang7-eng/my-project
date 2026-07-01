// ============================================================================
// RECIPE MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/restaurant_inventory_model.dart';
import '../../data/models/food_menu_item_model.dart';
import '../../data/repositories/food_menu_repository.dart';
import '../../data/repositories/restaurant_inventory_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RecipeManagementScreen extends StatefulWidget {
  final String vendorId;
  const RecipeManagementScreen({super.key, this.vendorId = 'SYSTEM'});
  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  final FoodMenuRepository _menuRepo = FoodMenuRepository();
  final RestaurantInventoryRepository _invRepo =
      RestaurantInventoryRepository();
  final _orange = const Color(0xFFEA580C);
  String get _vendorId => widget.vendorId;

  List<FoodMenuItem> _menuItems = [];
  List<RestaurantInventoryItem> _inventoryItems = [];
  FoodMenuItem? _selectedItem;
  List<ItemRecipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final menuItems = await _menuRepo.watchMenuItems(_vendorId).first;
    final invItems = await _invRepo.watchInventoryItems(_vendorId).first;
    if (mounted) {
      setState(() {
        _menuItems = menuItems;
        _inventoryItems = invItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecipes(String menuItemId) async {
    final recipes = await _invRepo.getRecipesForItem(menuItemId);
    if (mounted) setState(() => _recipes = recipes);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _orange),
    ),
  );

  void _showAddRecipeDialog() {
    if (_selectedItem == null) return;
    RestaurantInventoryItem? selectedInv;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: FuturisticColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Ingredient — ${_selectedItem!.name}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<RestaurantInventoryItem>(
                  value: selectedInv,
                  dropdownColor: FuturisticColors.darkSurfaceVariant,
                  style: const TextStyle(color: Colors.white),
                  hint: const Text(
                    'Select Ingredient',
                    style: TextStyle(color: Colors.grey),
                  ),
                  decoration: _dec('Ingredient'),
                  items: _inventoryItems
                      .map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('${i.name} (${i.unit.displayName})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDS(() => selectedInv = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec(
                    selectedInv != null
                        ? 'Qty per serving (${selectedInv!.unit.displayName})'
                        : 'Qty per serving',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () async {
                if (selectedInv == null || qtyCtrl.text.isEmpty) return;
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                await _invRepo.upsertRecipe(
                  menuItemId: _selectedItem!.id,
                  inventoryItemId: selectedInv!.id,
                  quantityPerUnit: qty,
                );
                await _loadRecipes(_selectedItem!.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.science_outlined, color: _orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Recipe → Ingredient Mapping',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedItem != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ingredient'),
                onPressed: _showAddRecipeDialog,
              ),
            ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? Center(child: CircularProgressIndicator(color: _orange))
          : Row(
              children: [
                SizedBox(
                  width: 260,
                  child: Container(
                    color: isDark
                        ? FuturisticColors.darkSurface
                        : FuturisticColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'MENU ITEMS',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _menuItems.length,
                            itemBuilder: (ctx, i) {
                              final item = _menuItems[i];
                              final selected = _selectedItem?.id == item.id;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor: _orange.withValues(alpha: 0.1),
                                leading: Icon(
                                  Icons.fastfood_outlined,
                                  color: selected ? _orange : Colors.grey,
                                  size: 18,
                                ),
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    color: selected
                                        ? _orange
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '₹${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                onTap: () async {
                                  setState(() => _selectedItem = item);
                                  await _loadRecipes(item.id);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedItem == null
                      ? Center(
                          child: Text(
                            'Select a menu item to view ingredients',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : Column(
                          children: [
                            if (_recipes.isNotEmpty) _buildCostBanner(isDark),
                            Expanded(
                              child: _recipes.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.science_outlined,
                                            size: 52,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No ingredients mapped',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _orange,
                                            ),
                                            icon: const Icon(
                                              Icons.add,
                                              size: 18,
                                            ),
                                            label: const Text('Add Ingredient'),
                                            onPressed: _showAddRecipeDialog,
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _recipes.length,
                                      itemBuilder: (ctx, i) =>
                                          _buildRecipeRow(_recipes[i], isDark),
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

  Widget _buildCostBanner(bool isDark) {
    double total = 0;
    for (final r in _recipes) {
      final inv = _inventoryItems
          .where((i) => i.id == r.inventoryItemId)
          .firstOrNull;
      if (inv != null) total += inv.costPerUnit * r.quantityPerUnit;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: _orange, size: 16),
          const SizedBox(width: 8),
          Text(
            'Est. Material Cost:',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '₹${total.toStringAsFixed(2)} per serving',
            style: TextStyle(
              color: _orange,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeRow(ItemRecipe recipe, bool isDark) {
    final inv = _inventoryItems
        .where((i) => i.id == recipe.inventoryItemId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.grass_outlined, color: _orange, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv?.name ?? 'Unknown',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${recipe.quantityPerUnit} ${inv?.unit.displayName ?? ''} per serving'
                    '${inv != null ? '  •  ₹${(inv.costPerUnit * recipe.quantityPerUnit).toStringAsFixed(2)}' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
              onPressed: () async {
                await _invRepo.deleteRecipe(recipe.id);
                await _loadRecipes(_selectedItem!.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
