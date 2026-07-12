// ============================================================================
// FOOD ITEM VARIATION REPOSITORY
// ============================================================================

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/food_item_variation_model.dart';

/// Repository for querying food item variations (modifiers/add-ons).
///
/// Backs the modifier picker in the restaurant bill flow by providing
/// variation data for a given menu item.
class FoodItemVariationRepository {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;

  FoodItemVariationRepository({AppDatabase? db, ErrorHandler? errorHandler})
    : _db = db ?? AppDatabase.instance,
      _errorHandler = errorHandler ?? ErrorHandler.instance;

  /// Get all active variations for a specific menu item.
  ///
  /// Returns variations sorted by [sortOrder] for consistent display
  /// in the modifier picker UI.
  Future<RepositoryResult<List<FoodItemVariation>>> getVariationsForItem(
    String itemId,
  ) async {
    return await _errorHandler.runSafe<List<FoodItemVariation>>(() async {
      final results = await _db
          .customSelect(
            'SELECT * FROM food_item_variations '
            'WHERE menu_item_id = ? AND is_active = 1 '
            'ORDER BY sort_order ASC',
            variables: [Variable.withString(itemId)],
          )
          .get();

      return results.map((row) {
        return FoodItemVariation(
          id: row.read<String>('id'),
          menuItemId: row.read<String>('menu_item_id'),
          vendorId: row.read<String>('vendor_id'),
          name: row.read<String>('name'),
          price: row.read<double>('price'),
          isActive: row.read<bool>('is_active'),
          sortOrder: row.read<int>('sort_order'),
          createdAt: DateTime.parse(row.read<String>('created_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
        );
      }).toList();
    }, 'getVariationsForItem');
  }
}
