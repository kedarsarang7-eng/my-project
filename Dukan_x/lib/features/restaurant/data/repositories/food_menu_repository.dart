// ============================================================================
// FOOD MENU REPOSITORY
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/food_menu_item_model.dart';
import '../models/food_category_model.dart';

/// Repository for managing food menu items and categories
class FoodMenuRepository {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;
  static const _uuid = Uuid();

  FoodMenuRepository({AppDatabase? db, ErrorHandler? errorHandler})
    : _db = db ?? AppDatabase.instance,
      _errorHandler = errorHandler ?? ErrorHandler.instance;

  // ============================================================================
  // CATEGORY OPERATIONS
  // ============================================================================

  /// Create a new food category
  Future<RepositoryResult<FoodCategory>> createCategory({
    required String vendorId,
    required String name,
    String? description,
    String? imageUrl,
    int sortOrder = 0,
  }) async {
    return await _errorHandler.runSafe<FoodCategory>(() async {
      final now = DateTime.now();
      final id = _uuid.v4();

      await _db
          .into(_db.foodCategories)
          .insert(
            FoodCategoriesCompanion.insert(
              id: id,
              vendorId: vendorId,
              name: name,
              description: Value(description),
              imageUrl: Value(imageUrl),
              sortOrder: Value(sortOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.foodCategories,
      )..where((t) => t.id.equals(id))).getSingle();

      return FoodCategory.fromEntity(entity);
    }, 'createCategory');
  }

  /// Get all categories for a vendor
  Future<RepositoryResult<List<FoodCategory>>> getCategoriesByVendor(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<FoodCategory>>(() async {
      final entities =
          await (_db.select(_db.foodCategories)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();

      return entities.map((e) => FoodCategory.fromEntity(e)).toList();
    }, 'getCategoriesByVendor');
  }

  /// Watch categories for a vendor
  Stream<List<FoodCategory>> watchCategories(String vendorId) {
    return (_db.select(_db.foodCategories)
          ..where(
            (t) =>
                t.vendorId.equals(vendorId) &
                t.isActive.equals(true) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map((e) => FoodCategory.fromEntity(e)).toList());
  }

  // ============================================================================
  // MENU ITEM OPERATIONS
  // ============================================================================

  /// Create a new menu item
  Future<RepositoryResult<FoodMenuItem>> createMenuItem({
    required String vendorId,
    required String name,
    required double price,
    String? categoryId,
    String? description,
    String? imageUrl,
    int? preparationTimeMinutes,
    bool isVegetarian = false,
    bool isVegan = false,
    bool isSpicy = false,
    List<String> allergens = const [],
    int sortOrder = 0,
  }) async {
    return await _errorHandler.runSafe<FoodMenuItem>(() async {
      final now = DateTime.now();
      final id = _uuid.v4();

      await _db
          .into(_db.foodMenuItems)
          .insert(
            FoodMenuItemsCompanion.insert(
              id: id,
              vendorId: vendorId,
              categoryId: Value(categoryId),
              name: name,
              description: Value(description),
              price: price,
              imageUrl: Value(imageUrl),
              preparationTimeMinutes: Value(preparationTimeMinutes),
              isVegetarian: Value(isVegetarian),
              isVegan: Value(isVegan),
              isSpicy: Value(isSpicy),
              allergensJson: Value(
                allergens.isNotEmpty ? jsonEncode(allergens) : null,
              ),
              sortOrder: Value(sortOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(id))).getSingle();

      return FoodMenuItem.fromEntity(entity);
    }, 'createMenuItem');
  }

  /// Update a menu item
  Future<RepositoryResult<FoodMenuItem>> updateMenuItem({
    required String id,
    String? name,
    double? price,
    String? categoryId,
    String? description,
    String? imageUrl,
    bool? isAvailable,
    int? preparationTimeMinutes,
    bool? isVegetarian,
    bool? isVegan,
    bool? isSpicy,
    List<String>? allergens,
    int? sortOrder,
  }) async {
    return await _errorHandler.runSafe<FoodMenuItem>(() async {
      final now = DateTime.now();

      await (_db.update(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(id))).write(
        FoodMenuItemsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          price: price != null ? Value(price) : const Value.absent(),
          categoryId: categoryId != null
              ? Value(categoryId)
              : const Value.absent(),
          description: description != null
              ? Value(description)
              : const Value.absent(),
          imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
          isAvailable: isAvailable != null
              ? Value(isAvailable)
              : const Value.absent(),
          preparationTimeMinutes: preparationTimeMinutes != null
              ? Value(preparationTimeMinutes)
              : const Value.absent(),
          isVegetarian: isVegetarian != null
              ? Value(isVegetarian)
              : const Value.absent(),
          isVegan: isVegan != null ? Value(isVegan) : const Value.absent(),
          isSpicy: isSpicy != null ? Value(isSpicy) : const Value.absent(),
          allergensJson: allergens != null
              ? Value(jsonEncode(allergens))
              : const Value.absent(),
          sortOrder: sortOrder != null
              ? Value(sortOrder)
              : const Value.absent(),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      final entity = await (_db.select(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(id))).getSingle();

      return FoodMenuItem.fromEntity(entity);
    }, 'updateMenuItem');
  }

  /// Set item availability (quick toggle)
  Future<RepositoryResult<void>> setItemAvailability(
    String itemId,
    bool isAvailable,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(itemId))).write(
        FoodMenuItemsCompanion(
          isAvailable: Value(isAvailable),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'setItemAvailability');
  }

  /// Soft delete a menu item
  Future<RepositoryResult<void>> deleteMenuItem(String id) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(id))).write(
        FoodMenuItemsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'deleteMenuItem');
  }

  /// Get menu item by ID
  Future<RepositoryResult<FoodMenuItem?>> getMenuItemById(String id) async {
    return await _errorHandler.runSafe<FoodMenuItem?>(() async {
      final entity = await (_db.select(
        _db.foodMenuItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      return entity != null ? FoodMenuItem.fromEntity(entity) : null;
    }, 'getMenuItemById');
  }

  /// Get all menu items for a vendor
  Future<RepositoryResult<List<FoodMenuItem>>> getMenuByVendor(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<FoodMenuItem>>(() async {
      final entities =
          await (_db.select(_db.foodMenuItems)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.name),
                ]))
              .get();

      return entities.map((e) => FoodMenuItem.fromEntity(e)).toList();
    }, 'getMenuByVendor');
  }

  /// Get available items only (for customer view)
  Future<RepositoryResult<List<FoodMenuItem>>> getAvailableItems(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<FoodMenuItem>>(() async {
      final entities =
          await (_db.select(_db.foodMenuItems)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.isActive.equals(true) &
                      t.isAvailable.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.name),
                ]))
              .get();

      return entities.map((e) => FoodMenuItem.fromEntity(e)).toList();
    }, 'getAvailableItems');
  }

  /// Get items by category
  Future<RepositoryResult<List<FoodMenuItem>>> getItemsByCategory(
    String vendorId,
    String categoryId,
  ) async {
    return await _errorHandler.runSafe<List<FoodMenuItem>>(() async {
      final entities =
          await (_db.select(_db.foodMenuItems)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.categoryId.equals(categoryId) &
                      t.isActive.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();

      return entities.map((e) => FoodMenuItem.fromEntity(e)).toList();
    }, 'getItemsByCategory');
  }

  /// Get popular items
  Future<RepositoryResult<List<FoodMenuItem>>> getPopularItems(
    String vendorId, {
    int limit = 5,
  }) async {
    return await _errorHandler.runSafe<List<FoodMenuItem>>(() async {
      final entities =
          await (_db.select(_db.foodMenuItems)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.isActive.equals(true) &
                      t.isAvailable.equals(true) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.popularityCount)])
                ..limit(limit))
              .get();

      return entities.map((e) => FoodMenuItem.fromEntity(e)).toList();
    }, 'getPopularItems');
  }

  /// Watch menu items for a vendor (real-time updates)
  Stream<List<FoodMenuItem>> watchMenuItems(String vendorId) {
    return (_db.select(_db.foodMenuItems)
          ..where(
            (t) =>
                t.vendorId.equals(vendorId) &
                t.isActive.equals(true) &
                t.deletedAt.isNull(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch()
        .map((rows) => rows.map((e) => FoodMenuItem.fromEntity(e)).toList());
  }

  /// Increment popularity count (called when item is ordered)
  Future<void> incrementPopularity(String itemId) async {
    await _db.customStatement(
      '''
      UPDATE food_menu_items 
      SET popularity_count = popularity_count + 1,
          updated_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), itemId],
    );
  }

  /// Update popularity badge based on order count
  Future<void> updatePopularityBadges(
    String vendorId, {
    int threshold = 10,
  }) async {
    final items = await (_db.select(
      _db.foodMenuItems,
    )..where((t) => t.vendorId.equals(vendorId) & t.deletedAt.isNull())).get();

    for (final item in items) {
      final shouldBePopular = item.popularityCount >= threshold;
      if (item.isPopular != shouldBePopular) {
        await (_db.update(
          _db.foodMenuItems,
        )..where((t) => t.id.equals(item.id))).write(
          FoodMenuItemsCompanion(
            isPopular: Value(shouldBePopular),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  /// Get unsynced menu items
  Future<List<FoodMenuItem>> getUnsyncedItems(String vendorId) async {
    final entities =
        await (_db.select(_db.foodMenuItems)..where(
              (t) => t.vendorId.equals(vendorId) & t.isSynced.equals(false),
            ))
            .get();

    return entities.map((e) => FoodMenuItem.fromEntity(e)).toList();
  }

  /// Mark item as synced
  Future<void> markItemSynced(String itemId) async {
    await (_db.update(_db.foodMenuItems)..where((t) => t.id.equals(itemId)))
        .write(const FoodMenuItemsCompanion(isSynced: Value(true)));
  }

  // ============================================================================
  // CATEGORY SORT ORDER
  // ============================================================================

  /// Persist new sort order for categories after drag-and-drop reorder.
  /// [orderedCategories] is the list of categories in their new display order.
  Future<RepositoryResult<void>> updateCategorySortOrder(
    List<FoodCategory> orderedCategories,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await _db.transaction(() async {
        for (int i = 0; i < orderedCategories.length; i++) {
          await (_db.update(
            _db.foodCategories,
          )..where((t) => t.id.equals(orderedCategories[i].id))).write(
            FoodCategoriesCompanion(
              sortOrder: Value(i),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
        }
      });
    }, 'updateCategorySortOrder');
  }
}
