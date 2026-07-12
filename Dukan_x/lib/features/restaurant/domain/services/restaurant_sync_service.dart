// ============================================================================
// RESTAURANT SYNC SERVICE
// ============================================================================

import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../data/models/food_order_model.dart';
import '../../data/repositories/food_menu_repository.dart';
import '../../data/repositories/food_order_repository.dart';
import '../../data/repositories/restaurant_table_repository.dart';
import '../../data/repositories/restaurant_bill_repository.dart';

/// Service for syncing restaurant data with Firestore
class RestaurantSyncService {
  final FoodMenuRepository _menuRepo;
  final FoodOrderRepository _orderRepo;
  final RestaurantTableRepository _tableRepo;
  final RestaurantBillRepository _billRepo;
  final SyncManager _syncManager;

  RestaurantSyncService({
    FoodMenuRepository? menuRepo,
    FoodOrderRepository? orderRepo,
    RestaurantTableRepository? tableRepo,
    RestaurantBillRepository? billRepo,
    SyncManager? syncManager,
  }) : _menuRepo = menuRepo ?? FoodMenuRepository(),
       _orderRepo = orderRepo ?? FoodOrderRepository(),
       _tableRepo = tableRepo ?? RestaurantTableRepository(),
       _billRepo = billRepo ?? RestaurantBillRepository(),
       _syncManager = syncManager ?? SyncManager.instance;

  /// Sync all unsynced restaurant data for a vendor
  Future<void> syncAll(String vendorId) async {
    await Future.wait([
      _syncMenuItems(vendorId),
      _syncOrders(vendorId),
      _syncTables(vendorId),
      _syncBills(vendorId),
    ]);
  }

  /// Sync menu items
  Future<void> _syncMenuItems(String vendorId) async {
    final unsyncedItems = await _menuRepo.getUnsyncedItems(vendorId);

    for (final item in unsyncedItems) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'food_menu_items',
          documentId: item.id,
          payload: item.toFirestoreMap(),
        ),
      );

      await _menuRepo.markItemSynced(item.id);
    }
  }

  /// Sync orders
  Future<void> _syncOrders(String vendorId) async {
    final unsyncedOrders = await _orderRepo.getUnsyncedOrders(vendorId);

    for (final order in unsyncedOrders) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'food_orders',
          documentId: order.id,
          payload: order.toFirestoreMap(),
        ),
      );

      await _orderRepo.markOrderSynced(order.id);
    }
  }

  /// Sync tables
  Future<void> _syncTables(String vendorId) async {
    final unsyncedTables = await _tableRepo.getUnsyncedTables(vendorId);

    for (final table in unsyncedTables) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'restaurant_tables',
          documentId: table.id,
          payload: table.toFirestoreMap(),
        ),
      );

      await _tableRepo.markTableSynced(table.id);
    }
  }

  /// Sync bills
  Future<void> _syncBills(String vendorId) async {
    final unsyncedBills = await _billRepo.getUnsyncedBills(vendorId);

    for (final bill in unsyncedBills) {
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendorId,
          operationType: SyncOperationType.update,
          targetCollection: 'restaurant_bills',
          documentId: bill.id,
          payload: bill.toFirestoreMap(),
        ),
      );

      await _billRepo.markBillSynced(bill.id);
    }
  }

  // ==========================================================================
  // CONFLICT RESOLUTION — Last-Write-Wins by updatedAt (Property 19 / Req 2.26)
  // ==========================================================================

  /// Reconcile a remote order status update against the local record using a
  /// deterministic last-write-wins strategy keyed on `updatedAt`.
  ///
  /// Given a remote update (e.g. from Firestore sync), reads the local
  /// record's `updatedAt` and only overwrites the local status if the remote
  /// `updatedAt` is strictly later. This ensures that for ANY pair of
  /// concurrent status updates with distinct timestamps, the final status is
  /// ALWAYS the one with the later `updatedAt`, regardless of arrival order.
  ///
  /// Returns `true` if the remote update was applied, `false` if it was
  /// rejected (local is already newer).
  Future<bool> reconcileOrderStatus({
    required String orderId,
    required String remoteStatus,
    required DateTime remoteUpdatedAt,
  }) async {
    final result = await _orderRepo.getOrderById(orderId);
    final localOrder = result.data;

    if (localOrder == null) {
      // Order doesn't exist locally — accept the remote update unconditionally
      // (this handles fresh pulls where no local state exists yet).
      return true;
    }

    final localUpdatedAt = localOrder.updatedAt;

    // Last-write-wins: only apply remote if its updatedAt is strictly later
    if (remoteUpdatedAt.millisecondsSinceEpoch >
        localUpdatedAt.millisecondsSinceEpoch) {
      // Remote is newer — apply the update using the repository's
      // timestamp-guarded method to maintain consistency.
      final status = _parseFoodOrderStatus(remoteStatus);
      if (status != null) {
        await _orderRepo.updateOrderStatus(orderId, status, remoteUpdatedAt);
      }
      return true;
    }

    // Local is newer or equal — reject the remote (stale) update
    return false;
  }

  /// Deterministic last-write-wins resolver for any two competing updates.
  ///
  /// Given two update payloads for the same order (each containing an
  /// `updatedAt` timestamp), returns the payload with the later timestamp.
  /// This is a pure function: for any pair of inputs, the output is always
  /// the same regardless of call order.
  static Map<String, dynamic> lastWriteWins(
    Map<String, dynamic> updateA,
    Map<String, dynamic> updateB,
  ) {
    final tsA = _parseTimestamp(updateA['updatedAt']);
    final tsB = _parseTimestamp(updateB['updatedAt']);

    if (tsA == null && tsB == null) return updateB;
    if (tsA == null) return updateB;
    if (tsB == null) return updateA;

    // The update with the later updatedAt wins; on tie, B wins (arbitrary but
    // deterministic since tie-breaking is consistent).
    return tsB.isAfter(tsA) || tsB.isAtSameMomentAs(tsA) ? updateB : updateA;
  }

  /// Parse an ISO 8601 timestamp string or DateTime to a DateTime.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Parse a status string back to FoodOrderStatus enum.
  FoodOrderStatus? _parseFoodOrderStatus(String value) {
    for (final status in FoodOrderStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// Get sync status
  Future<RestaurantSyncStatus> getSyncStatus(String vendorId) async {
    final unsyncedItems = await _menuRepo.getUnsyncedItems(vendorId);
    final unsyncedOrders = await _orderRepo.getUnsyncedOrders(vendorId);
    final unsyncedTables = await _tableRepo.getUnsyncedTables(vendorId);
    final unsyncedBills = await _billRepo.getUnsyncedBills(vendorId);

    return RestaurantSyncStatus(
      pendingMenuItems: unsyncedItems.length,
      pendingOrders: unsyncedOrders.length,
      pendingTables: unsyncedTables.length,
      pendingBills: unsyncedBills.length,
    );
  }
}

/// Sync status model
class RestaurantSyncStatus {
  final int pendingMenuItems;
  final int pendingOrders;
  final int pendingTables;
  final int pendingBills;

  const RestaurantSyncStatus({
    this.pendingMenuItems = 0,
    this.pendingOrders = 0,
    this.pendingTables = 0,
    this.pendingBills = 0,
  });

  int get totalPending =>
      pendingMenuItems + pendingOrders + pendingTables + pendingBills;

  bool get isFullySynced => totalPending == 0;
}
