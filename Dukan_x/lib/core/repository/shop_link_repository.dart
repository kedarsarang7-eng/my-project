// ============================================================================
// SHOP LINK REPOSITORY
// ============================================================================
// Manages customer-shop associations for the multi-tenant linking system.
// Tracks which shops a customer has linked to via QR scanning.
//
// Used by customer app to display "My Linked Shops" dashboard.
// Author: DukanX Engineering
// ============================================================================

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

class ShopLinkRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  ShopLinkRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'shop_links';

  /// Create a new shop link after successful QR validation
  Future<RepositoryResult<ShopLinkEntity>> createLink({
    required String customerId,
    required String shopId,
    required String customerProfileId,
    required String shopName,
    String? businessType,
    String? shopPhone,
  }) async {
    return await errorHandler.runSafe<ShopLinkEntity>(() async {
      final now = DateTime.now();
      // DETERMINISTIC ID for Security Rules (customerId_shopId)
      final linkId = '${customerId}_$shopId';

      final companion = ShopLinksCompanion(
        id: Value(linkId),
        customerId: Value(customerId),
        shopId: Value(shopId),
        customerProfileId: Value(customerProfileId),
        shopName: Value(shopName),
        businessType: Value(businessType),
        shopPhone: Value(shopPhone),
        status: const Value('ACTIVE'),
        totalBilled: const Value(0.0),
        totalPaid: const Value(0.0),
        outstandingBalance: const Value(0.0),
        linkedAt: Value(now),
        updatedAt: Value(now),
        isSynced: const Value(false),
      );

      await database.into(database.shopLinks).insert(companion);

      final link = await (database.select(
        database.shopLinks,
      )..where((t) => t.id.equals(linkId))).getSingle();

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: customerId, // Customer owns this link
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: linkId,
          payload: _entityToMap(link),
        ),
      );

      return link;
    }, 'createLink');
  }

  /// Get link by ID
  Future<RepositoryResult<ShopLinkEntity?>> getLinkById(String linkId) async {
    return await errorHandler.runSafe<ShopLinkEntity?>(() async {
      return await (database.select(
        database.shopLinks,
      )..where((t) => t.id.equals(linkId))).getSingleOrNull();
    }, 'getLinkById');
  }

  /// Get link for a specific customer-shop combination
  Future<RepositoryResult<ShopLinkEntity?>> getLinkForCustomerShop({
    required String customerId,
    required String shopId,
  }) async {
    return await errorHandler.runSafe<ShopLinkEntity?>(() async {
      return await (database.select(database.shopLinks)..where(
            (t) => t.customerId.equals(customerId) & t.shopId.equals(shopId),
          ))
          .getSingleOrNull();
    }, 'getLinkForCustomerShop');
  }

  /// Get all active links for a customer
  Future<RepositoryResult<List<ShopLinkEntity>>> getActiveLinksForCustomer(
    String customerId,
  ) async {
    return await errorHandler.runSafe<List<ShopLinkEntity>>(() async {
      return await (database.select(database.shopLinks)
            ..where(
              (t) =>
                  t.customerId.equals(customerId) & t.status.equals('ACTIVE'),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.linkedAt)]))
          .get();
    }, 'getActiveLinksForCustomer');
  }

  /// Watch active links for customer (reactive for dashboard)
  Stream<List<ShopLinkEntity>> watchActiveLinksForCustomer(String customerId) {
    return (database.select(database.shopLinks)
          ..where(
            (t) => t.customerId.equals(customerId) & t.status.equals('ACTIVE'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.linkedAt)]))
        .watch();
  }

  /// Get all links for a shop (shows linked customers)
  Future<RepositoryResult<List<ShopLinkEntity>>> getLinksForShop(
    String shopId,
  ) async {
    return await errorHandler.runSafe<List<ShopLinkEntity>>(() async {
      return await (database.select(database.shopLinks)
            ..where((t) => t.shopId.equals(shopId) & t.status.equals('ACTIVE'))
            ..orderBy([(t) => OrderingTerm.desc(t.linkedAt)]))
          .get();
    }, 'getLinksForShop');
  }

  /// Watch links for a shop (reactive)
  Stream<List<ShopLinkEntity>> watchLinksForShop(String shopId) {
    return (database.select(database.shopLinks)
          ..where((t) => t.shopId.equals(shopId) & t.status.equals('ACTIVE'))
          ..orderBy([(t) => OrderingTerm.desc(t.linkedAt)]))
        .watch();
  }

  /// Unlink a shop (soft delete - customer action)
  Future<RepositoryResult<void>> unlinkShop({
    required String customerId,
    required String shopId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(database.shopLinks)..where(
            (t) => t.customerId.equals(customerId) & t.shopId.equals(shopId),
          ))
          .write(
            ShopLinksCompanion(
              status: const Value('UNLINKED'),
              unlinkedAt: Value(now),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );

      // Queue for sync
      final link =
          await (database.select(database.shopLinks)..where(
                (t) =>
                    t.customerId.equals(customerId) & t.shopId.equals(shopId),
              ))
              .getSingleOrNull();
      if (link != null) {
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: customerId,
            operationType: SyncOperationType.update,
            targetCollection: collectionName,
            documentId: link.id,
            payload: {
              'status': 'UNLINKED',
              'unlinkedAt': now.toIso8601String(),
            },
          ),
        );
      }
    }, 'unlinkShop');
  }

  /// Block a customer (shop-side action)
  Future<RepositoryResult<void>> blockCustomerLink({
    required String shopId,
    required String customerProfileId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(database.shopLinks)..where(
            (t) =>
                t.shopId.equals(shopId) &
                t.customerProfileId.equals(customerProfileId),
          ))
          .write(
            ShopLinksCompanion(
              status: const Value('BLOCKED'),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
    }, 'blockCustomerLink');
  }

  /// Update billing summary (called after bill creation/payment)
  Future<RepositoryResult<void>> updateBillingSummary({
    required String customerId,
    required String shopId,
    required double totalBilled,
    required double totalPaid,
    required double outstandingBalance,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();
      await (database.update(database.shopLinks)..where(
            (t) => t.customerId.equals(customerId) & t.shopId.equals(shopId),
          ))
          .write(
            ShopLinksCompanion(
              totalBilled: Value(totalBilled),
              totalPaid: Value(totalPaid),
              outstandingBalance: Value(outstandingBalance),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );
    }, 'updateBillingSummary');
  }

  /// Check if customer is linked to shop
  Future<bool> isLinked({
    required String customerId,
    required String shopId,
  }) async {
    final link =
        await (database.select(database.shopLinks)..where(
              (t) =>
                  t.customerId.equals(customerId) &
                  t.shopId.equals(shopId) &
                  t.status.equals('ACTIVE'),
            ))
            .getSingleOrNull();
    return link != null;
  }

  Map<String, dynamic> _entityToMap(ShopLinkEntity e) {
    return {
      'id': e.id,
      'customerId': e.customerId,
      'shopId': e.shopId,
      'customerProfileId': e.customerProfileId,
      'shopName': e.shopName,
      'businessType': e.businessType,
      'shopPhone': e.shopPhone,
      'status': e.status,
      'totalBilled': e.totalBilled,
      'totalPaid': e.totalPaid,
      'outstandingBalance': e.outstandingBalance,
      'linkedAt': e.linkedAt.toIso8601String(),
      'updatedAt': e.updatedAt.toIso8601String(),
    };
  }
}
