// ============================================================================
// FOOD ORDER REPOSITORY
// ============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/food_order_model.dart';

import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';

/// Repository for managing food orders
class FoodOrderRepository {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;
  final SyncManager _syncManager;
  static const _uuid = Uuid();

  FoodOrderRepository({
    AppDatabase? db,
    ErrorHandler? errorHandler,
    SyncManager? syncManager,
  }) : _db = db ?? AppDatabase.instance,
       _errorHandler = errorHandler ?? ErrorHandler.instance,
       _syncManager = syncManager ?? SyncManager.instance;

  // ============================================================================
  // ORDER CREATION
  // ============================================================================

  /// Create a new food order (offline-first)
  Future<RepositoryResult<FoodOrder>> createOrder({
    required String vendorId,
    required String customerId,
    required OrderType orderType,
    required List<OrderItem> items,
    String? customerName,
    String? customerPhone,
    String? tableId,
    String? tableNumber,
    String? specialInstructions,
    int? estimatedPrepTime,
  }) async {
    return await _errorHandler.runSafe<FoodOrder>(() async {
      final now = DateTime.now();
      final id = _uuid.v4();

      // Calculate totals
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );
      final itemCount = items.fold<int>(0, (sum, item) => sum + item.quantity);

      // For dine-in, table number is required
      if (orderType == OrderType.dineIn && tableNumber == null) {
        throw Exception('Table number is required for dine-in orders');
      }

      await _db
          .into(_db.foodOrders)
          .insert(
            FoodOrdersCompanion.insert(
              id: id,
              vendorId: vendorId,
              customerId: customerId,
              customerName: Value(customerName),
              customerPhone: Value(customerPhone),
              tableId: Value(tableId),
              tableNumber: Value(tableNumber),
              orderType: orderType.value,
              itemsJson: jsonEncode(items.map((e) => e.toJson()).toList()),
              itemCount: itemCount,
              subtotal: subtotal,
              grandTotal: subtotal, // Will be updated when bill is generated
              specialInstructions: Value(specialInstructions),
              estimatedPrepTime: Value(estimatedPrepTime),
              orderTime: now,
              createdAt: now,
              updatedAt: now,
              isSynced: const Value(false),
            ),
          );

      final entity = await (_db.select(
        _db.foodOrders,
      )..where((t) => t.id.equals(id))).getSingle();

      final order = FoodOrder.fromEntity(entity);

      // CRITICAL: Queue for Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.create,
          targetCollection: 'food_orders',
          documentId: id,
          payload: order.toFirestoreMap(),
        ),
      );

      return order;
    }, 'createOrder');
  }

  // ============================================================================
  // ORDER QUERIES
  // ============================================================================

  /// Get order by ID
  Future<RepositoryResult<FoodOrder?>> getOrderById(String id) async {
    return await _errorHandler.runSafe<FoodOrder?>(() async {
      final entity = await (_db.select(
        _db.foodOrders,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      return entity != null ? FoodOrder.fromEntity(entity) : null;
    }, 'getOrderById');
  }

  /// Get all orders for a vendor
  Future<RepositoryResult<List<FoodOrder>>> getVendorOrders(
    String vendorId, {
    FoodOrderStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      var query = _db.select(_db.foodOrders)
        ..where((t) => t.vendorId.equals(vendorId));

      if (status != null) {
        query = query..where((t) => t.orderStatus.equals(status.value));
      }
      if (fromDate != null) {
        query = query..where((t) => t.orderTime.isBiggerOrEqualValue(fromDate));
      }
      if (toDate != null) {
        query = query..where((t) => t.orderTime.isSmallerOrEqualValue(toDate));
      }

      final entities =
          await (query..orderBy([(t) => OrderingTerm.desc(t.orderTime)])).get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getVendorOrders');
  }

  /// Get customer's order history
  Future<RepositoryResult<List<FoodOrder>>> getCustomerOrders(
    String customerId,
  ) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      final entities =
          await (_db.select(_db.foodOrders)
                ..where((t) => t.customerId.equals(customerId))
                ..orderBy([(t) => OrderingTerm.desc(t.orderTime)]))
              .get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getCustomerOrders');
  }

  /// Get pending orders for vendor (kitchen view)
  Future<RepositoryResult<List<FoodOrder>>> getPendingOrders(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      final entities =
          await (_db.select(_db.foodOrders)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.orderStatus.isIn([
                        FoodOrderStatus.pending.value,
                        FoodOrderStatus.accepted.value,
                        FoodOrderStatus.cooking.value,
                        FoodOrderStatus.ready.value,
                      ]),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.orderTime)]))
              .get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getPendingOrders');
  }

  /// Get orders for a specific table
  Future<RepositoryResult<List<FoodOrder>>> getTableOrders(
    String tableId,
  ) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      final entities =
          await (_db.select(_db.foodOrders)
                ..where(
                  (t) =>
                      t.tableId.equals(tableId) &
                      t.orderStatus.isNotIn([
                        FoodOrderStatus.completed.value,
                        FoodOrderStatus.cancelled.value,
                      ]),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.orderTime)]))
              .get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getTableOrders');
  }

  // ============================================================================
  // REAL-TIME STREAMS
  // ============================================================================

  /// Watch orders for vendor (real-time updates)
  Stream<List<FoodOrder>> watchVendorOrders(String vendorId) {
    return (_db.select(_db.foodOrders)
          ..where((t) => t.vendorId.equals(vendorId))
          ..orderBy([(t) => OrderingTerm.desc(t.orderTime)]))
        .watch()
        .map((rows) => rows.map((e) => FoodOrder.fromEntity(e)).toList());
  }

  /// Watch pending orders (kitchen view)
  Stream<List<FoodOrder>> watchPendingOrders(String vendorId) {
    return (_db.select(_db.foodOrders)
          ..where(
            (t) =>
                t.vendorId.equals(vendorId) &
                t.orderStatus.isIn([
                  FoodOrderStatus.pending.value,
                  FoodOrderStatus.accepted.value,
                  FoodOrderStatus.cooking.value,
                  FoodOrderStatus.ready.value,
                ]),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.orderTime)]))
        .watch()
        .map((rows) => rows.map((e) => FoodOrder.fromEntity(e)).toList());
  }

  /// Watch a single order (for customer tracking)
  Stream<FoodOrder?> watchOrder(String orderId) {
    return (_db.select(_db.foodOrders)..where((t) => t.id.equals(orderId)))
        .watchSingleOrNull()
        .map((e) => e != null ? FoodOrder.fromEntity(e) : null);
  }

  // ============================================================================
  // ORDER STATUS UPDATES
  // ============================================================================

  /// Update order status
  Future<RepositoryResult<void>> updateOrderStatus(
    String orderId,
    FoodOrderStatus status,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      final companion = FoodOrdersCompanion(
        orderStatus: Value(status.value),
        updatedAt: Value(now),
        isSynced: const Value(false),
      );

      // Set appropriate timestamp based on status
      switch (status) {
        case FoodOrderStatus.accepted:
          await (_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId)))
              .write(companion.copyWith(acceptedAt: Value(now)));
          break;
        case FoodOrderStatus.cooking:
          await (_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId)))
              .write(companion.copyWith(cookingStartedAt: Value(now)));
          break;
        case FoodOrderStatus.ready:
          await (_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId)))
              .write(companion.copyWith(readyAt: Value(now)));
          break;
        case FoodOrderStatus.served:
          await (_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId)))
              .write(companion.copyWith(servedAt: Value(now)));
          break;
        case FoodOrderStatus.completed:
          await (_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId)))
              .write(companion.copyWith(completedAt: Value(now)));
          break;
        default:
          await (_db.update(
            _db.foodOrders,
          )..where((t) => t.id.equals(orderId))).write(companion);
      }

      // CRITICAL: Queue for Sync
      final entity = await (_db.select(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).getSingle();

      // ignore: unused_local_variable
      final order = FoodOrder.fromEntity(entity);

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: entity.vendorId, // Assuming we have vendorId in entity
          operationType: SyncOperationType.update,
          targetCollection: 'food_orders',
          documentId: orderId,
          payload: {
            'orderStatus': status.value,
            'updatedAt': now.toIso8601String(),
            if (status == FoodOrderStatus.accepted)
              'acceptedAt': now.toIso8601String(),
            if (status == FoodOrderStatus.cooking)
              'cookingStartedAt': now.toIso8601String(),
            if (status == FoodOrderStatus.ready)
              'readyAt': now.toIso8601String(),
            if (status == FoodOrderStatus.served)
              'servedAt': now.toIso8601String(),
            if (status == FoodOrderStatus.completed)
              'completedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'updateOrderStatus');
  }

  /// Accept order
  Future<RepositoryResult<void>> acceptOrder(String orderId) async {
    return updateOrderStatus(orderId, FoodOrderStatus.accepted);
  }

  /// Start cooking
  Future<RepositoryResult<void>> startCooking(String orderId) async {
    return updateOrderStatus(orderId, FoodOrderStatus.cooking);
  }

  /// Mark order as ready
  Future<RepositoryResult<void>> markReady(String orderId) async {
    return updateOrderStatus(orderId, FoodOrderStatus.ready);
  }

  /// Mark order as served
  Future<RepositoryResult<void>> markServed(String orderId) async {
    return updateOrderStatus(orderId, FoodOrderStatus.served);
  }

  /// Complete order
  Future<RepositoryResult<void>> completeOrder(String orderId) async {
    return updateOrderStatus(orderId, FoodOrderStatus.completed);
  }

  /// Cancel order
  Future<RepositoryResult<void>> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    return await _errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (_db.update(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).write(
        FoodOrdersCompanion(
          orderStatus: Value(FoodOrderStatus.cancelled.value),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Fetch for sync
      final entity = await (_db.select(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).getSingle();

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: entity.vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'food_orders',
          documentId: orderId,
          payload: {
            'orderStatus': FoodOrderStatus.cancelled.value,
            'cancelledAt': now.toIso8601String(),
            'cancellationReason': reason,
            'updatedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'cancelOrder');
  }

  // ============================================================================
  // BILL REQUEST
  // ============================================================================

  /// Customer requests bill
  Future<RepositoryResult<void>> requestBill(String orderId) async {
    return await _errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (_db.update(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).write(
        FoodOrdersCompanion(
          billRequested: const Value(true),
          billRequestedAt: Value(now),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }, 'requestBill');
  }

  /// Get orders with bill requested (for vendor)
  Future<RepositoryResult<List<FoodOrder>>> getBillRequestedOrders(
    String vendorId,
  ) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      final entities =
          await (_db.select(_db.foodOrders)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.billRequested.equals(true) &
                      t.billId.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.billRequestedAt)]))
              .get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getBillRequestedOrders');
  }

  /// Link bill to order
  Future<RepositoryResult<void>> linkBillToOrder(
    String orderId,
    String billId,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).write(
        FoodOrdersCompanion(
          billId: Value(billId),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
    }, 'linkBillToOrder');
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Get unsynced orders
  Future<List<FoodOrder>> getUnsyncedOrders(String vendorId) async {
    final entities =
        await (_db.select(_db.foodOrders)..where(
              (t) => t.vendorId.equals(vendorId) & t.isSynced.equals(false),
            ))
            .get();

    return entities.map((e) => FoodOrder.fromEntity(e)).toList();
  }

  /// Mark order as synced
  Future<void> markOrderSynced(
    String orderId, {
    String? syncOperationId,
  }) async {
    await (_db.update(
      _db.foodOrders,
    )..where((t) => t.id.equals(orderId))).write(
      FoodOrdersCompanion(
        isSynced: const Value(true),
        syncOperationId: Value(syncOperationId),
      ),
    );
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Get today's order count
  Future<int> getTodayOrderCount(String vendorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final orders =
        await (_db.select(_db.foodOrders)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.orderTime.isBiggerOrEqualValue(startOfDay) &
                  t.orderStatus.isNotIn([FoodOrderStatus.cancelled.value]),
            ))
            .get();

    return orders.length;
  }

  /// Get today's revenue
  Future<double> getTodayRevenue(String vendorId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final orders =
        await (_db.select(_db.foodOrders)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.orderTime.isBiggerOrEqualValue(startOfDay) &
                  t.orderStatus.equals(FoodOrderStatus.completed.value),
            ))
            .get();

    return orders.fold<double>(0, (sum, order) => sum + order.grandTotal);
  }

  /// Get orders for a specific date
  Future<RepositoryResult<List<FoodOrder>>> getOrdersByDate(
    String vendorId,
    DateTime date,
  ) async {
    return await _errorHandler.runSafe<List<FoodOrder>>(() async {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final entities =
          await (_db.select(_db.foodOrders)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.orderTime.isBiggerOrEqualValue(startOfDay) &
                      t.orderTime.isSmallerThanValue(endOfDay),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.orderTime)]))
              .get();

      return entities.map((e) => FoodOrder.fromEntity(e)).toList();
    }, 'getOrdersByDate');
  }

  /// Submit order review
  Future<RepositoryResult<void>> submitOrderReview(
    String orderId,
    Map<String, dynamic> review,
  ) async {
    return await _errorHandler.runSafe<void>(() async {
      await (_db.update(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).write(
        FoodOrdersCompanion(
          reviewRating: Value((review['overallRating'] as num?)?.toInt()),
          reviewText: Value(() {
            final tags = (review['tags'] as List?)?.join(', ');
            final text = review['reviewText'] as String? ?? '';
            if (tags != null && tags.isNotEmpty) {
              return text.isNotEmpty ? '$text\n\nTags: $tags' : 'Tags: $tags';
            }
            return text;
          }()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Fetch for sync
      final entity = await (_db.select(
        _db.foodOrders,
      )..where((t) => t.id.equals(orderId))).getSingle();

      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: entity.vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'food_orders',
          documentId: orderId,
          payload: {
            'reviewRating': (review['overallRating'] as num?)?.toInt(),
            'reviewText': entity.reviewText, // Use the processed text
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
    }, 'submitOrderReview');
  }
}

// Extension for FoodOrdersCompanion
extension FoodOrdersCompanionCopyWith on FoodOrdersCompanion {
  FoodOrdersCompanion copyWith({
    Value<DateTime?>? acceptedAt,
    Value<DateTime?>? cookingStartedAt,
    Value<DateTime?>? readyAt,
    Value<DateTime?>? servedAt,
    Value<DateTime?>? completedAt,
  }) {
    return FoodOrdersCompanion(
      orderStatus: orderStatus,
      updatedAt: updatedAt,
      isSynced: isSynced,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      cookingStartedAt: cookingStartedAt ?? this.cookingStartedAt,
      readyAt: readyAt ?? this.readyAt,
      servedAt: servedAt ?? this.servedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
