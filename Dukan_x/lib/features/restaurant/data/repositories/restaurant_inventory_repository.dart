// ============================================================================
// RESTAURANT INVENTORY REPOSITORY
// ============================================================================
// Handles raw material management and recipe-based auto-deduction.
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../models/restaurant_inventory_model.dart';

class RestaurantInventoryRepository {
  final AppDatabase _db = AppDatabase.instance;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // Inventory Items
  // ---------------------------------------------------------------------------

  Stream<List<RestaurantInventoryItem>> watchInventoryItems(String vendorId) {
    return (_db.select(_db.restaurantInventoryItems)
          ..where((t) => t.vendorId.equals(vendorId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(RestaurantInventoryItem.fromEntity).toList());
  }

  Future<List<RestaurantInventoryItem>> getLowStockItems(
    String vendorId,
  ) async {
    final all =
        await (_db.select(_db.restaurantInventoryItems)..where(
              (t) => t.vendorId.equals(vendorId) & t.isActive.equals(true),
            ))
            .get();
    return all
        .map(RestaurantInventoryItem.fromEntity)
        .where((item) => item.isLowStock)
        .toList();
  }

  // MEDIUM FIX: Get visible stock items (qty > 0)
  Future<List<RestaurantInventoryItem>> getVisibleStockItems(
    String vendorId,
  ) async {
    final items = await (_db.select(_db.restaurantInventoryItems)
          ..where(
            (t) => t.vendorId.equals(vendorId) &
                t.isActive.equals(true) &
                t.currentStock.isBiggerThanValue(0),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return items.map(RestaurantInventoryItem.fromEntity).toList();
  }

  // MEDIUM FIX: Get dead stock items (qty = 0)
  Future<List<RestaurantInventoryItem>> getDeadStockItems(
    String vendorId,
  ) async {
    final items = await (_db.select(_db.restaurantInventoryItems)
          ..where(
            (t) => t.vendorId.equals(vendorId) &
                t.isActive.equals(true) &
                t.currentStock.equals(0),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return items.map(RestaurantInventoryItem.fromEntity).toList();
  }

  Future<RestaurantInventoryItem> createInventoryItem({
    required String vendorId,
    required String name,
    InventoryUnit unit = InventoryUnit.pcs,
    double currentStock = 0,
    double minStockAlert = 0,
    double costPerUnit = 0,
    String? supplierName,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();

    await _db
        .into(_db.restaurantInventoryItems)
        .insert(
          RestaurantInventoryItemsCompanion.insert(
            id: id,
            vendorId: vendorId,
            name: name,
            unit: unit.value,
            currentStock: currentStock,
            minStockAlert: minStockAlert,
            costPerUnit: costPerUnit,
            supplierName: Value(supplierName),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return RestaurantInventoryItem(
      id: id,
      vendorId: vendorId,
      name: name,
      unit: unit,
      currentStock: currentStock,
      minStockAlert: minStockAlert,
      costPerUnit: costPerUnit,
      supplierName: supplierName,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateStock(String itemId, double newStock) async {
    await (_db.update(
      _db.restaurantInventoryItems,
    )..where((t) => t.id.equals(itemId))).write(
      RestaurantInventoryItemsCompanion(
        currentStock: Value(newStock),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> adjustStock(String itemId, double delta) async {
    final item = await (_db.select(
      _db.restaurantInventoryItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;
    final newStock = (item.currentStock + delta).clamp(0.0, double.infinity);
    await updateStock(itemId, newStock);
  }

  // ---------------------------------------------------------------------------
  // Recipes
  // ---------------------------------------------------------------------------

  Future<List<ItemRecipe>> getRecipesForItem(String menuItemId) async {
    final rows = await (_db.select(
      _db.itemRecipes,
    )..where((t) => t.menuItemId.equals(menuItemId))).get();
    return rows.map(ItemRecipe.fromEntity).toList();
  }

  Future<void> upsertRecipe({
    required String menuItemId,
    required String inventoryItemId,
    required double quantityPerUnit,
    String? variationId,
  }) async {
    final now = DateTime.now();
    await _db
        .into(_db.itemRecipes)
        .insertOnConflictUpdate(
          ItemRecipesCompanion.insert(
            id: _uuid.v4(),
            menuItemId: menuItemId,
            inventoryItemId: inventoryItemId,
            quantityPerUnit: quantityPerUnit,
            variationId: Value(variationId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> deleteRecipe(String recipeId) async {
    await (_db.delete(
      _db.itemRecipes,
    )..where((t) => t.id.equals(recipeId))).go();
  }

  // ---------------------------------------------------------------------------
  // Auto-Deduction: called when a KOT is punched or an order is completed
  // ---------------------------------------------------------------------------

  /// Deducts raw materials based on item recipes.
  /// [soldItems] is a map of {menuItemId → (qty, variationId?)}
  Future<void> deductFromRecipes(
    Map<String, ({int qty, String? variationId})> soldItems,
  ) async {
    for (final entry in soldItems.entries) {
      final menuItemId = entry.key;
      final qty = entry.value.qty;
      final variationId = entry.value.variationId;

      final recipes = await getRecipesForItem(menuItemId);

      // Filter recipes relevant to this variation
      final applicableRecipes = recipes.where((r) {
        if (variationId != null) {
          // Specific variation recipe takes priority; fall back to base (null)
          return r.variationId == variationId || r.variationId == null;
        }
        return r.variationId == null;
      }).toList();

      // Deduplicate: if both variation-specific and base exist, prefer specific
      final Map<String, ItemRecipe> deduped = {};
      for (final r in applicableRecipes) {
        if (!deduped.containsKey(r.inventoryItemId) ||
            (r.variationId != null)) {
          deduped[r.inventoryItemId] = r;
        }
      }

      for (final recipe in deduped.values) {
        final totalDeduction = recipe.quantityPerUnit * qty;
        await adjustStock(recipe.inventoryItemId, -totalDeduction);
      }
    }
  }
}
