// ============================================================================
// RESTAURANT SYNC SERVICE
// ============================================================================

import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
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
