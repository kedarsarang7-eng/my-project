// ============================================================================
// PRODUCTS REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages product/item data with Drift as source of truth
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../data/data_guard.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import '../services/event_dispatcher.dart';

import '../../models/reorder_prediction.dart';

enum ProductType { goods, service }

/// Product entity
class Product {
  final String id;
  final String userId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? category;
  final String unit;
  final double sellingPrice;
  final double costPrice;
  final double taxRate;
  final double stockQuantity;
  final double lowStockThreshold;
  final String? size;
  final String? color;
  final String? brand;
  final String? hsnCode;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<String>
  altBarcodes; // For multiple barcodes pointing to same product

  Product({
    required this.id,
    required this.userId,
    required this.name,
    this.sku,
    this.barcode,
    this.category,
    this.unit = 'pcs',
    required this.sellingPrice,
    this.costPrice = 0,
    this.taxRate = 0,
    this.stockQuantity = 0,
    this.lowStockThreshold = 10,
    this.size,
    this.color,
    this.brand,
    this.hsnCode,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.altBarcodes = const [],
    this.drugSchedule,
    this.groupId,
    this.variantAttributes,
  });

  final String? groupId;
  final Map<String, String>? variantAttributes;

  final String? drugSchedule;

  bool get isLowStock => stockQuantity <= lowStockThreshold;

  /// Derived Product Type based on Category Convention
  /// Needed to avoid Schema Migration (build_runner) for adding strict 'type' column
  ProductType get type {
    final cat = category?.toLowerCase() ?? '';
    if (cat.startsWith('service') ||
        cat == 'consultation' ||
        cat == 'lab test' ||
        cat == 'opd') {
      return ProductType.service;
    }
    return ProductType.goods;
  }

  Product copyWith({
    String? id,
    String? userId,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? sellingPrice,
    double? costPrice,
    double? taxRate,
    double? stockQuantity,
    double? lowStockThreshold,
    String? size,
    String? color,
    String? brand,
    String? hsnCode,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<String>? altBarcodes,
    String? drugSchedule,
    String? groupId,
    Map<String, String>? variantAttributes,
  }) {
    return Product(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      taxRate: taxRate ?? this.taxRate,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      size: size ?? this.size,
      color: color ?? this.color,
      brand: brand ?? this.brand,
      hsnCode: hsnCode ?? this.hsnCode,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      altBarcodes: altBarcodes ?? this.altBarcodes,
      drugSchedule: drugSchedule ?? this.drugSchedule,
      groupId: groupId ?? this.groupId,
      variantAttributes: variantAttributes ?? this.variantAttributes,
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'category': category,
    'unit': unit,
    'sellingPrice': sellingPrice,
    'costPrice': costPrice,
    'taxRate': taxRate,
    'stockQuantity': stockQuantity,
    'lowStockThreshold': lowStockThreshold,
    'size': size,
    'color': color,
    'brand': brand,
    'hsnCode': hsnCode,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'altBarcodes': altBarcodes,
    'drugSchedule': drugSchedule,
    'groupId': groupId,
    'variantAttributes': variantAttributes,
  };
}

/// Products Repository
class ProductsRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final EventDispatcher eventDispatcher;

  ProductsRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    EventDispatcher? eventDispatcher,
  }) : eventDispatcher = eventDispatcher ?? EventDispatcher.instance;

  String get collectionName => 'products';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a new product
  Future<RepositoryResult<Product>> createProduct({
    required String userId,
    required String name,
    String? sku,
    String? barcode,
    String? category,
    String unit = 'pcs',
    required double sellingPrice,
    double costPrice = 0,
    double taxRate = 0,
    double stockQuantity = 0,
    double lowStockThreshold = 10,
    String? size,
    String? color,
    String? brand,
    String? hsnCode,
    List<String>? altBarcodes,
    String? drugSchedule,
    String? groupId,
    Map<String, String>? variantAttributes,
    // Phase 3: Strict Add Item Support
    List<Map<String, dynamic>>? initialBatches,
    List<String>? initialImeis,
  }) async {
    return await errorHandler.runSafe<Product>(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      // VALIDATION: Enforce Stock Integrity
      if (initialBatches != null && initialBatches.isNotEmpty) {
        // For Pharmacy, stock MUST sum of batches
        double batchSum = 0;
        for (var b in initialBatches) {
          batchSum += (b['quantity'] as num? ?? 0).toDouble();
        }
        if (stockQuantity != batchSum) {
          // Auto-correct or throw? Let's auto-correct to trust the explicit batch list
          stockQuantity = batchSum;
        }
      } else if (initialImeis != null && initialImeis.isNotEmpty) {
        // For Electronics, stock MUST be count of IMEIs
        stockQuantity = initialImeis.length.toDouble();
      }

      final product = Product(
        id: id,
        userId: userId,
        name: name,
        sku: sku,
        barcode: barcode,
        category: category,
        unit: unit,
        sellingPrice: sellingPrice,
        costPrice: costPrice,
        taxRate: taxRate,
        stockQuantity: stockQuantity,
        lowStockThreshold: lowStockThreshold,
        size: size,
        color: color,
        brand: brand,
        hsnCode: hsnCode,
        altBarcodes: altBarcodes ?? [],
        drugSchedule: drugSchedule,
        createdAt: now,
        updatedAt: now,
      );

      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              sku: Value(sku),
              barcode: Value(barcode),
              category: Value(category),
              unit: Value(unit),
              sellingPrice: sellingPrice,
              costPrice: Value(costPrice),
              taxRate: Value(taxRate),
              stockQuantity: Value(stockQuantity),
              lowStockThreshold: Value(lowStockThreshold),
              size: Value(size),
              color: Value(color),
              brand: Value(brand),
              hsnCode: Value(hsnCode),
              isActive: const Value(true),
              isSynced: const Value(false),
              createdAt: now,
              updatedAt: now,
              altBarcodes: Value(altBarcodes?.join(',') ?? ''),
              drugSchedule: Value(drugSchedule),
              groupId: Value(groupId),
              variantAttributes: Value(
                variantAttributes != null
                    ? jsonEncode(variantAttributes)
                    : null,
              ),
            ),
          );

      // PHASE 3: INSERT BATCHES (Pharmacy)
      if (initialBatches != null) {
        for (final batch in initialBatches) {
          await database
              .into(database.productBatches)
              .insert(
                ProductBatchesCompanion.insert(
                  id: const Uuid().v4(),
                  productId: id,
                  userId: userId,
                  batchNumber: batch['batchNumber'],
                  expiryDate: Value(batch['expiryDate']),
                  stockQuantity: Value((batch['quantity'] as num).toDouble()),
                  openingQuantity: Value((batch['quantity'] as num).toDouble()),
                  mrp: Value((batch['mrp'] as num? ?? sellingPrice).toDouble()),
                  purchaseRate: Value(
                    (batch['purchaseRate'] as num? ?? costPrice).toDouble(),
                  ),
                  status: const Value('ACTIVE'),
                  isSynced: const Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }

      // PHASE 3: INSERT IMEIS (Electronics)
      if (initialImeis != null) {
        for (final imei in initialImeis) {
          await database
              .into(database.iMEISerials)
              .insert(
                IMEISerialsCompanion.insert(
                  id: const Uuid().v4(),
                  productId: id,
                  userId: userId,
                  imeiOrSerial: imei,
                  type: const Value('IMEI'),
                  status: const Value('IN_STOCK'),
                  purchasePrice: Value(costPrice),
                  isSynced: const Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }

      // GOLDEN RULE: Create Movement for Opening Stock
      if (stockQuantity > 0) {
        final movementId = const Uuid().v4();
        await database
            .into(database.stockMovements)
            .insert(
              StockMovementEntity(
                id: movementId,
                userId: userId,
                productId: id,
                type: 'IN', // Opening stock is IN
                reason: 'OPENING_STOCK',
                quantity: stockQuantity,
                stockBefore: 0,
                stockAfter: stockQuantity,
                referenceId: 'OPENING_${now.millisecondsSinceEpoch}',
                description: 'Initial Stock on Product Creation',
                date: now,
                createdAt: now,
                createdBy: 'SYSTEM',
                isSynced: false,
              ),
            );

        // Queue sync for movement
        final movementPayload = {
          'id': movementId,
          'userId': userId,
          'productId': id,
          'type': 'IN',
          'reason': 'OPENING_STOCK',
          'quantity': stockQuantity,
          'stockBefore': 0,
          'stockAfter': stockQuantity,
          'referenceId': 'OPENING_${now.millisecondsSinceEpoch}',
          'description': 'Initial Stock on Product Creation',
          'date': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'createdBy': 'SYSTEM',
        };
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.create,
            targetCollection: 'stock_movements',
            documentId: movementId,
            payload: movementPayload,
          ),
        );
      }

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: id,
        payload: product.toFirestoreMap(),
      );
      await syncManager.enqueue(item);

      return product;
    }, 'createProduct');
  }

  /// Get product by ID
  Future<RepositoryResult<Product?>> getById(String id) async {
    return await errorHandler.runSafe<Product?>(() async {
      final result =
          await (database.select(database.products)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();

      if (result == null) return null;
      return _entityToProduct(result);
    }, 'getById');
  }

  /// Get all products for user
  Future<RepositoryResult<List<Product>>> getAll({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<Product>>(() async {
      final results =
          await (database.select(database.products)
                ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();

      return results.map(_entityToProduct).toList();
    }, 'getAll');
  }

  /// Watch all products
  Stream<List<Product>> watchAll({required String userId}) {
    return (database.select(database.products)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_entityToProduct).toList());
  }

  /// Watch unique categories
  Stream<List<String>> watchUniqueCategories({required String userId}) {
    return (database.select(database.products)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.category)]))
        .watch()
        .map((rows) {
          final categories = rows
              .map((row) => row.category)
              .where((c) => c != null && c.isNotEmpty)
              .cast<String>()
              .toSet()
              .toList();
          categories.sort();
          return categories;
        });
  }

  /// Update product
  Future<RepositoryResult<Product>> updateProduct(
    Product product, {
    required String userId,
  }) async {
    return await errorHandler.runSafe<Product>(() async {
      // 1. Fetch OLD product to detect stock changes
      final oldProductEntity = await (database.select(
        database.products,
      )..where((t) => t.id.equals(product.id))).getSingleOrNull();

      final updated = product.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await (database.update(
        database.products,
      )..where((t) => t.id.equals(product.id))).write(
        ProductsCompanion(
          name: Value(updated.name),
          sku: Value(updated.sku),
          barcode: Value(updated.barcode),
          category: Value(updated.category),
          unit: Value(updated.unit),
          sellingPrice: Value(updated.sellingPrice),
          costPrice: Value(updated.costPrice),
          taxRate: Value(updated.taxRate),
          stockQuantity: Value(updated.stockQuantity),
          lowStockThreshold: Value(updated.lowStockThreshold),
          size: Value(updated.size),
          color: Value(updated.color),
          brand: Value(updated.brand),
          hsnCode: Value(updated.hsnCode),
          isActive: Value(updated.isActive),
          isSynced: const Value(false),
          updatedAt: Value(updated.updatedAt),
          altBarcodes: Value(updated.altBarcodes.join(',')),
          drugSchedule: Value(updated.drugSchedule),
          groupId: Value(updated.groupId),
          variantAttributes: Value(
            updated.variantAttributes != null
                ? jsonEncode(updated.variantAttributes)
                : null,
          ),
        ),
      );

      // GOLDEN RULE: Create Movement if Stock Changed manually
      if (oldProductEntity != null &&
          oldProductEntity.stockQuantity != updated.stockQuantity) {
        final double diff =
            updated.stockQuantity - oldProductEntity.stockQuantity;
        final String type = diff > 0 ? 'IN' : 'OUT';
        final double qty = diff.abs();
        final now = DateTime.now();
        final movementId = const Uuid().v4();

        await database
            .into(database.stockMovements)
            .insert(
              StockMovementEntity(
                id: movementId,
                userId: userId,
                productId: product.id,
                type: type,
                reason: 'MANUAL_ADJUSTMENT',
                quantity: qty,
                stockBefore: oldProductEntity.stockQuantity,
                stockAfter: updated.stockQuantity,
                referenceId: 'EDIT_${now.millisecondsSinceEpoch}',
                description: 'Stock updated via Edit Product',
                date: now,
                createdAt: now,
                createdBy: 'USER',
                isSynced: false,
              ),
            );

        // Queue sync for movement
        final movementPayload = {
          'id': movementId,
          'userId': userId,
          'productId': product.id,
          'type': type,
          'reason': 'MANUAL_ADJUSTMENT',
          'quantity': qty,
          'stockBefore': oldProductEntity.stockQuantity,
          'stockAfter': updated.stockQuantity,
          'referenceId': 'EDIT_${now.millisecondsSinceEpoch}',
          'description': 'Stock updated via Edit Product',
          'date': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'createdBy': 'USER',
        };
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.create,
            targetCollection: 'stock_movements',
            documentId: movementId,
            payload: movementPayload,
          ),
        );

        // EVENT: Stock Changed
        eventDispatcher.stockChanged(
          productId: product.id,
          oldQty: oldProductEntity.stockQuantity,
          newQty: updated.stockQuantity,
          reason: 'MANUAL_ADJUSTMENT',
          userId: userId,
        );

        // EVENT: Low Stock Alert
        if (updated.stockQuantity <= updated.lowStockThreshold) {
          eventDispatcher.stockLow(
            productId: product.id,
            productName: updated.name,
            currentQty: updated.stockQuantity,
            lowStockLimit: updated.lowStockThreshold,
            userId: userId,
          );
        }
      }

      // Queue for sync (Product Update)
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: product.id,
        payload: updated.toFirestoreMap(),
      );
      await syncManager.enqueue(item);

      return updated;
    }, 'updateProduct');
  }

  /// Delete product (soft delete)
  Future<RepositoryResult<bool>> deleteProduct(
    String id, {
    required String userId,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      await (database.update(
        database.products,
      )..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          deletedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.delete,
        targetCollection: collectionName,
        documentId: id,
        payload: {},
      );
      await syncManager.enqueue(item);

      return true;
    }, 'deleteProduct');
  }

  // ============================================
  // STOCK OPERATIONS
  // ============================================

  /// Adjust stock quantity
  Future<RepositoryResult<Product>> adjustStock({
    required String productId,
    required double quantity,
    required String userId,
  }) async {
    return await errorHandler.runSafe<Product>(() async {
      final current = await (database.select(
        database.products,
      )..where((t) => t.id.equals(productId))).getSingleOrNull();

      if (current == null) {
        throw Exception('Product not found');
      }

      final newStock = current.stockQuantity + quantity;
      if (newStock < 0) {
        throw Exception('Insufficient stock');
      }

      await (database.update(
        database.products,
      )..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Queue for sync
      final item = SyncQueueItem.create(
        userId: userId,
        operationType: SyncOperationType.update,
        targetCollection: collectionName,
        documentId: productId,
        payload: {
          'stockQuantity': newStock,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      await syncManager.enqueue(item);

      // EVENT: Stock Changed
      eventDispatcher.stockChanged(
        productId: productId,
        oldQty: current.stockQuantity,
        newQty: newStock,
        reason: 'ADJUSTMENT',
        userId: userId,
      );

      // EVENT: Low Stock Alert
      if (newStock <= current.lowStockThreshold) {
        eventDispatcher.stockLow(
          productId: productId,
          productName: current.name,
          currentQty: newStock,
          lowStockLimit: current.lowStockThreshold,
          userId: userId,
        );
      }

      return _entityToProduct(current).copyWith(stockQuantity: newStock);
    }, 'adjustStock');
  }

  /// Get low stock products
  Future<RepositoryResult<List<Product>>> getLowStockProducts({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<Product>>(() async {
      final results = await (database.select(
        database.products,
      )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

      return results
          .where((p) => p.stockQuantity <= p.lowStockThreshold)
          .map(_entityToProduct)
          .toList();
    }, 'getLowStockProducts');
  }

  /// Get dead stock products (unsold since cutoff)
  Future<RepositoryResult<List<Product>>> getDeadStock({
    required String userId,
    required int daysUnsold,
  }) async {
    return await errorHandler.runSafe<List<Product>>(() async {
      final cutoff = DateTime.now().subtract(Duration(days: daysUnsold));
      final results = await database.getDeadStockProducts(userId, cutoff);
      return results.map(_entityToProduct).toList();
    }, 'getDeadStock');
  }

  /// Get smart reorder suggestions
  Future<RepositoryResult<List<ReorderPrediction>>> getSmartReorderSuggestions({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<ReorderPrediction>>(() async {
      // 1. Get all active products
      final productsResult = await getAll(userId: userId);
      final products = productsResult.data ?? [];

      if (products.isEmpty) return [];

      // 2. Get sales history for last 30 days
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final salesHistory = await database.getProductSalesHistory(
        userId,
        cutoff,
      );

      final predictions = <ReorderPrediction>[];

      for (final product in products) {
        // Skip if stock is plenty or product is inactive
        if (product.stockQuantity < 0) {
          continue;
        }

        final totalSold30Days = salesHistory[product.id] ?? 0.0;

        // Skip items with no sales velocity (dead stock handles these)
        if (totalSold30Days <= 0) continue;

        final dailyVelocity = totalSold30Days / 30.0;

        // Avoid division by zero, though checked above
        final daysUntilEmpty = dailyVelocity > 0
            ? (product.stockQuantity / dailyVelocity).floor()
            : 999;

        // Suggest if running out in 2 weeks or less
        if (daysUntilEmpty <= 14) {
          predictions.add(
            ReorderPrediction(
              product: product,
              dailyVelocity: dailyVelocity,
              daysUntilEmpty: daysUntilEmpty,
              estimatedStockoutDate: DateTime.now().add(
                Duration(days: daysUntilEmpty),
              ),
            ),
          );
        }
      }

      // Sort by urgency (lowest days remaining first)
      predictions.sort((a, b) => a.daysUntilEmpty.compareTo(b.daysUntilEmpty));

      return predictions;
    }, 'getSmartReorderSuggestions');
  }

  /// Search products
  Future<RepositoryResult<List<Product>>> search(
    String query, {
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<Product>>(() async {
      final results = await (database.select(
        database.products,
      )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

      final lowerQuery = query.toLowerCase();
      return results
          .where(
            (p) =>
                p.name.toLowerCase().contains(lowerQuery) ||
                (p.sku?.toLowerCase().contains(lowerQuery) ?? false) ||
                (p.barcode?.contains(query) ?? false) ||
                (p.altBarcodes?.contains(query) ?? false),
          )
          .map(_entityToProduct)
          .toList();
    }, 'search');
  }

  // ============================================
  // ANALYTICS (LOCAL)
  // ============================================

  /// Get stock status summary (In, Low, Out)
  Future<RepositoryResult<Map<String, dynamic>>> getStockStatusSummary(
    String userId,
  ) async {
    return await errorHandler.runSafe<Map<String, dynamic>>(() async {
      final allProducts = (await getAll(userId: userId)).data ?? [];

      int inStock = 0;
      int lowStock = 0;
      int outStock = 0;
      List<Map<String, dynamic>> outItems = [];
      List<Map<String, dynamic>> lowItems = [];

      for (final p in allProducts) {
        if (p.stockQuantity <= 0) {
          outStock++;
          if (outItems.length < 5) {
            outItems.add({'name': p.name, 'quantity': 0});
          }
        } else if (p.isLowStock) {
          lowStock++;
          if (lowItems.length < 5) {
            lowItems.add({'name': p.name, 'quantity': p.stockQuantity.toInt()});
          }
        } else {
          inStock++;
        }
      }

      return {
        'in_stock_count': inStock,
        'low_stock_count': lowStock,
        'out_of_stock_count': outStock,
        'low_stock_items': lowItems,
        'out_of_stock_items': outItems,
      };
    }, 'getStockStatusSummary');
  }

  // / Get sales performance (Top Selling & Slow Moving)
  Future<RepositoryResult<Map<String, dynamic>>> getSalesPerformance(
    String userId,
  ) async {
    return await errorHandler.runSafe<Map<String, dynamic>>(() async {
      // 1. Get Sales History (30 days)
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final salesMap = await database.getProductSalesHistory(userId, cutoff);

      // 2. Get All Products to map names
      final allProducts = (await getAll(userId: userId)).data ?? [];
      final productMap = {for (var p in allProducts) p.id: p};

      // 3. Sort Top Selling
      final sortedKeys = salesMap.keys.toList()
        ..sort((a, b) => (salesMap[b] ?? 0).compareTo(salesMap[a] ?? 0));

      final topSelling = sortedKeys.take(20).map((id) {
        final p = productMap[id];
        final qty = salesMap[id]?.toInt() ?? 0;
        final revenue = (p?.sellingPrice ?? 0) * qty;
        final cost = (p?.costPrice ?? 0) * qty;
        final margin = revenue > 0 ? ((revenue - cost) / revenue) * 100 : 0.0;

        return {
          'id': id,
          'name': p?.name ?? 'Unknown',
          'category': p?.category ?? 'General',
          'sold_qty': qty,
          'revenue': revenue,
          'margin': margin,
          'trend':
              'up', // Placeholder for actual trend based on previous period
        };
      }).toList();

      // 4. Slow Moving (Zero sales in 30 days but have stock)
      final slowMoving = allProducts
          .where((p) => !salesMap.containsKey(p.id) && p.stockQuantity > 0)
          .take(20)
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'category': p.category ?? 'General',
              'sold_qty': 0,
              'revenue': 0.0,
              'margin': 0.0,
              'trend': 'down',
            },
          )
          .toList();

      // 5. High Margin (Sorted by margin %)
      final highMargin =
          [
            ...topSelling,
            ...slowMoving,
          ].where((i) => (i['revenue'] as double) > 0).toList()..sort(
            (a, b) => (b['margin'] as double).compareTo(a['margin'] as double),
          );

      return {
        'top_selling': topSelling,
        'low_moving': slowMoving, // Renamed key to match UI filter
        'high_margin': highMargin.take(20).toList(), // New key for UI filter
      };
    }, 'getSalesPerformance');
  }

  // ============================================
  // BATCH OPERATIONS
  // ============================================

  /// Get batches for a product
  Future<RepositoryResult<List<ProductBatchEntity>>> getBatchesForProduct(
    String productId,
  ) async {
    return await errorHandler.runSafe<List<ProductBatchEntity>>(() async {
      return await (database.select(database.productBatches)
            ..where(
              (t) => t.productId.equals(productId) & t.status.equals('ACTIVE'),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
          .get();
    }, 'getBatchesForProduct');
  }

  /// Get all active batches
  Future<RepositoryResult<List<ProductBatchEntity>>> getAllBatches(
    String userId,
  ) async {
    return await errorHandler.runSafe<List<ProductBatchEntity>>(() async {
      return await (database.select(database.productBatches)
            ..where((t) => t.userId.equals(userId) & t.status.equals('ACTIVE'))
            ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
          .get();
    }, 'getAllBatches');
  }

  /// Get damage logs
  Future<RepositoryResult<List<StockMovementEntity>>> getDamageLogs(
    String userId,
  ) async {
    return await errorHandler.runSafe<List<StockMovementEntity>>(() async {
      return await (database.select(database.stockMovements)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.type.equals('OUT') &
                  t.reason.isIn(['DAMAGE', 'EXPIRED', 'THEFT', 'LOST']),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();
    }, 'getDamageLogs');
  }

  Product _entityToProduct(ProductEntity e) => Product(
    id: e.id,
    userId: e.userId,
    name: e.name,
    sku: e.sku,
    barcode: e.barcode,
    category: e.category,
    unit: e.unit,
    sellingPrice: e.sellingPrice,
    costPrice: e.costPrice,
    taxRate: e.taxRate,
    stockQuantity: e.stockQuantity,
    lowStockThreshold: e.lowStockThreshold,
    size: e.size,
    color: e.color,
    brand: e.brand,
    hsnCode: e.hsnCode,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deletedAt: e.deletedAt,
    altBarcodes:
        e.altBarcodes?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    drugSchedule: e.drugSchedule,
    groupId: e.groupId,
    variantAttributes: DataGuard.safeJsonMap(
      e.variantAttributes,
    ).cast<String, String>(),
  );
}
