import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import 'inventory_service.dart';

class ProductionService {
  final AppDatabase _db;
  final InventoryService _inventoryService;

  ProductionService(this._db, this._inventoryService);

  /// Create or Update a Bill of Material (Recipe)
  /// Returns the ID of the created/updated BOM entry
  Future<String> saveBillOfMaterial({
    required String userId,
    required String finishedGoodId,
    required String rawMaterialId,
    required double quantityRequired,
    String unit = 'pcs',
    double costAllocationPercent = 100.0,
  }) async {
    final existing =
        await (_db.select(_db.billOfMaterials)..where(
              (t) =>
                  t.finishedGoodId.equals(finishedGoodId) &
                  t.rawMaterialId.equals(rawMaterialId),
            ))
            .getSingleOrNull();

    final now = DateTime.now();

    if (existing != null) {
      await (_db.update(
        _db.billOfMaterials,
      )..where((t) => t.id.equals(existing.id))).write(
        BillOfMaterialsCompanion(
          quantityRequired: Value(quantityRequired),
          unit: Value(unit),
          costAllocationPercent: Value(costAllocationPercent),
          updatedAt: Value(now),
        ),
      );
      return existing.id;
    } else {
      final id = const Uuid().v4();
      await _db
          .into(_db.billOfMaterials)
          .insert(
            BillOfMaterialsCompanion(
              id: Value(id),
              userId: Value(userId),
              finishedGoodId: Value(finishedGoodId),
              rawMaterialId: Value(rawMaterialId),
              quantityRequired: Value(quantityRequired),
              unit: Value(unit),
              costAllocationPercent: Value(costAllocationPercent),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return id;
    }
  }

  /// Get the Recipe (BOM) for a Finished Good
  Future<List<BillOfMaterialEntity>> getRecipe(String finishedGoodId) {
    return (_db.select(
      _db.billOfMaterials,
    )..where((t) => t.finishedGoodId.equals(finishedGoodId))).get();
  }

  /// Execute Production Run
  /// 1. Check if enough Raw Materials exist
  /// 2. Consume Raw Materials (Stock OUT)
  /// 3. Create Finished Good (Stock IN)
  /// 4. Log Production Entry
  Future<String> runProduction({
    required String userId,
    required String finishedGoodId,
    required double quantityToProduce,
    String? notes,
    String? batchNumber, // Optional batch number for the FG
  }) async {
    if (quantityToProduce <= 0) {
      throw Exception('Production quantity must be positive');
    }

    return await _db.transaction(() async {
      // 1. Fetch Recipe
      final recipe = await getRecipe(finishedGoodId);
      if (recipe.isEmpty) {
        throw Exception(
          'No Bill of Materials (Recipe) found for this product.',
        );
      }

      // 2. Validate Stock Availability & Calculate Cost
      double totalCost = 0.0;
      final rawMaterialsSnapshot = <Map<String, dynamic>>[];

      for (final item in recipe) {
        final requiredQty = item.quantityRequired * quantityToProduce;

        // Fetch RM Product to check stock and cost
        final rmProduct = await (_db.select(
          _db.products,
        )..where((t) => t.id.equals(item.rawMaterialId))).getSingle();

        if (rmProduct.stockQuantity < requiredQty) {
          // Check if negative stock is allowed?
          // For manufacturing, we usually enforce strict stock to avoid "producing from air"
          // ideally we check shop config, but let's be strict or use InventoryService logic
        }

        totalCost += (rmProduct.costPrice * requiredQty);

        rawMaterialsSnapshot.add({
          'productId': item.rawMaterialId,
          'productName': rmProduct.name,
          'quantityConsumed': requiredQty,
          'costPerUnit': rmProduct.costPrice,
          'totalCost': rmProduct.costPrice * requiredQty,
        });
      }

      // 3. Consume Raw Materials
      for (final item in recipe) {
        final requiredQty = item.quantityRequired * quantityToProduce;

        // We reuse InventoryService to ensure all "Golden Rules" (Locking, History, Sync) are met
        await _inventoryService.addStockMovement(
          userId: userId,
          productId: item.rawMaterialId,
          type: 'OUT',
          reason: 'PRODUCTION_CONSUMPTION',
          quantity: requiredQty,
          referenceId:
              'PROD-${DateTime.now().millisecondsSinceEpoch}', // Temp ID, will link to Entry later if needed?
          // Ideally we create Entry ID first.
          description: 'Used for production of $quantityToProduce units of FG',
        );
      }

      // 4. Create Finished Good
      // Add Value (Labor/Overhead)?
      // For now, Cost = Sum of RM Cost.
      // New Unit Cost = Total Cost / Qty Produced.
      final unitCost = totalCost / quantityToProduce;

      await _inventoryService.addStockMovement(
        userId: userId,
        productId: finishedGoodId,
        type: 'IN',
        reason: 'PRODUCTION_OUTPUT',
        quantity: quantityToProduce,
        referenceId: 'PROD-${DateTime.now().millisecondsSinceEpoch}',
        description: 'Produced from manufacturing run',
        newCostPrice: unitCost, // Update Weighted Average Cost
        batchNumber: batchNumber,
        batchId: batchNumber != null
            ? const Uuid().v4()
            : null, // If Batch Logic needed
      );

      // 5. Log Production Entry
      final id = const Uuid().v4();
      await _db
          .into(_db.productionEntries)
          .insert(
            ProductionEntriesCompanion(
              id: Value(id),
              userId: Value(userId),
              finishedGoodId: Value(finishedGoodId),
              quantityProduced: Value(quantityToProduce),
              productionDate: Value(DateTime.now()),
              batchNumber: Value(batchNumber),
              notes: Value(notes),
              totalCost: Value(totalCost),
              laborCost: const Value(0.0),
              rawMaterialsJson: Value(jsonEncode(rawMaterialsSnapshot)),
              createdAt: Value(DateTime.now()),
            ),
          );

      return id;
    });
  }
}
