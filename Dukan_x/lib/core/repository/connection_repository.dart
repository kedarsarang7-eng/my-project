// ============================================================================
// CONNECTION REPOSITORY
// ============================================================================
// Offline-first repository for customer-vendor connections
// Replaces direct Firestore calls in ConnectionService
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

/// Connection status values
class ConnectionStatus {
  static const String pending = 'PENDING';
  static const String active = 'ACTIVE';
  static const String rejected = 'REJECTED';
  static const String disconnected = 'DISCONNECTED';
}

/// Model for customer-vendor connections
class VendorConnection {
  final String id;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final String? vendorPhone;
  final String? vendorBusinessName;
  final String? vendorAddress;
  final String? customerRefId;
  final String status;
  final double totalBilled;
  final double totalPaid;
  final double outstandingBalance;
  final DateTime? lastInvoiceDate;
  final DateTime? lastPaymentDate;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorConnection({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    this.vendorPhone,
    this.vendorBusinessName,
    this.vendorAddress,
    this.customerRefId,
    this.status = ConnectionStatus.active,
    this.totalBilled = 0.0,
    this.totalPaid = 0.0,
    this.outstandingBalance = 0.0,
    this.lastInvoiceDate,
    this.lastPaymentDate,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorConnection.fromEntity(CustomerConnectionEntity entity) {
    return VendorConnection(
      id: entity.id,
      customerId: entity.customerId,
      vendorId: entity.vendorId,
      vendorName: entity.vendorName,
      vendorPhone: entity.vendorPhone,
      vendorBusinessName: entity.vendorBusinessName,
      vendorAddress: entity.vendorAddress,
      customerRefId: entity.customerRefId,
      status: entity.status,
      totalBilled: entity.totalBilled,
      totalPaid: entity.totalPaid,
      outstandingBalance: entity.outstandingBalance,
      lastInvoiceDate: entity.lastInvoiceDate,
      lastPaymentDate: entity.lastPaymentDate,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorPhone': vendorPhone,
      'vendorBusinessName': vendorBusinessName,
      'vendorAddress': vendorAddress,
      'customerRefId': customerRefId,
      'status': status,
      'totalBilled': totalBilled,
      'totalPaid': totalPaid,
      'outstandingBalance': outstandingBalance,
      'lastInvoiceDate': lastInvoiceDate?.toIso8601String(),
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Connection request model
class ConnectionRequest {
  final String id;
  final String customerId;
  final String vendorId;
  final String customerName;
  final String? customerPhone;
  final String status; // PENDING, ACCEPTED, REJECTED
  final DateTime createdAt;
  final DateTime? respondedAt;

  ConnectionRequest({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.customerName,
    this.customerPhone,
    this.status = 'PENDING',
    required this.createdAt,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'vendorId': vendorId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }
}

/// Repository for managing customer-vendor connections with offline-first approach
class ConnectionRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  static const _uuid = Uuid();

  ConnectionRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  // ============================================================================
  // CONNECTION OPERATIONS
  // ============================================================================

  /// Create a connection request (as customer wanting to link to vendor)
  /// This is queued for sync and will be processed when online
  Future<RepositoryResult<String>> createConnectionRequest({
    required String customerId,
    required String vendorId,
    required String customerName,
    String? customerPhone,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final now = DateTime.now();
      final requestId = _uuid.v4();

      // Queue the request for sync to Firestore
      // The actual connection happens when vendor accepts
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: customerId,
          operationType: SyncOperationType.create,
          targetCollection: 'connection_requests',
          documentId: requestId,
          payload: {
            'id': requestId,
            'customerId': customerId,
            'vendorId': vendorId,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'status': 'PENDING',
            'createdAt': now.toIso8601String(),
          },
          priority: 2, // Higher priority for connection requests
        ),
      );

      return requestId;
    }, 'createConnectionRequest');
  }

  /// Accept a connection request (as vendor)
  /// Creates the actual connection in local DB and queues sync
  Future<RepositoryResult<VendorConnection>> acceptConnectionRequest({
    required String userId, // Vendor's user ID
    required String requestId,
    required String customerId,
    required String customerName,
    String? customerRefId,
  }) async {
    return await errorHandler.runSafe<VendorConnection>(() async {
      final now = DateTime.now();
      final connectionId = _uuid.v4();

      // Create connection in local DB
      final connection = CustomerConnectionsCompanion.insert(
        id: connectionId,
        customerId: customerId,
        vendorId: userId,
        vendorName: '', // Will be populated from vendor profile
        status: Value(ConnectionStatus.active),
        customerRefId: Value(customerRefId),
        createdAt: now,
        updatedAt: now,
      );

      await database.into(database.customerConnections).insert(connection);

      // Queue connection for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.create,
          targetCollection: 'connections',
          documentId: connectionId,
          payload: {
            'id': connectionId,
            'customerId': customerId,
            'vendorId': userId,
            'status': ConnectionStatus.active,
            'customerRefId': customerRefId,
            'createdAt': now.toIso8601String(),
          },
        ),
      );

      // Update the request status
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: 'connection_requests',
          documentId: requestId,
          payload: {'status': 'ACCEPTED', 'respondedAt': now.toIso8601String()},
        ),
      );

      // Return the created connection
      final entity = await (database.select(
        database.customerConnections,
      )..where((t) => t.id.equals(connectionId))).getSingle();

      return VendorConnection.fromEntity(entity);
    }, 'acceptConnectionRequest');
  }

  /// Reject a connection request
  Future<RepositoryResult<void>> rejectConnectionRequest({
    required String userId,
    required String requestId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // Queue status update for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: 'connection_requests',
          documentId: requestId,
          payload: {'status': 'REJECTED', 'respondedAt': now.toIso8601String()},
        ),
      );
    }, 'rejectConnectionRequest');
  }

  /// Get all active connections for a customer
  Future<RepositoryResult<List<VendorConnection>>> getCustomerConnections(
    String customerId,
  ) async {
    return await errorHandler.runSafe<List<VendorConnection>>(() async {
      final entities =
          await (database.select(database.customerConnections)
                ..where(
                  (t) =>
                      t.customerId.equals(customerId) &
                      t.status.equals(ConnectionStatus.active),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
              .get();

      return entities.map(VendorConnection.fromEntity).toList();
    }, 'getCustomerConnections');
  }

  /// Get all connections for a vendor (their customers)
  Future<RepositoryResult<List<VendorConnection>>> getVendorConnections(
    String vendorId,
  ) async {
    return await errorHandler.runSafe<List<VendorConnection>>(() async {
      final entities =
          await (database.select(database.customerConnections)
                ..where(
                  (t) =>
                      t.vendorId.equals(vendorId) &
                      t.status.equals(ConnectionStatus.active),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
              .get();

      return entities.map(VendorConnection.fromEntity).toList();
    }, 'getVendorConnections');
  }

  /// Watch connections stream for reactive UI
  Stream<List<VendorConnection>> watchCustomerConnections(String customerId) {
    return (database.select(database.customerConnections)
          ..where(
            (t) =>
                t.customerId.equals(customerId) &
                t.status.equals(ConnectionStatus.active),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((entities) => entities.map(VendorConnection.fromEntity).toList());
  }

  /// Disconnect from a vendor
  Future<RepositoryResult<void>> disconnectFromVendor({
    required String userId,
    required String connectionId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // Update local status
      await (database.update(
        database.customerConnections,
      )..where((t) => t.id.equals(connectionId))).write(
        CustomerConnectionsCompanion(
          status: const Value(ConnectionStatus.disconnected),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.update,
          targetCollection: 'connections',
          documentId: connectionId,
          payload: {
            'status': ConnectionStatus.disconnected,
            'updatedAt': now.toIso8601String(),
          },
        ),
      );
    }, 'disconnectFromVendor');
  }

  /// Update connection statistics (called when bills/payments are made)
  Future<RepositoryResult<void>> updateConnectionStats({
    required String connectionId,
    double? addToBilled,
    double? addToPaid,
    DateTime? lastInvoiceDate,
    DateTime? lastPaymentDate,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // Get current connection
      final connection = await (database.select(
        database.customerConnections,
      )..where((t) => t.id.equals(connectionId))).getSingleOrNull();

      if (connection == null) return;

      final newTotalBilled = connection.totalBilled + (addToBilled ?? 0);
      final newTotalPaid = connection.totalPaid + (addToPaid ?? 0);
      final newOutstanding = newTotalBilled - newTotalPaid;

      await (database.update(
        database.customerConnections,
      )..where((t) => t.id.equals(connectionId))).write(
        CustomerConnectionsCompanion(
          totalBilled: Value(newTotalBilled),
          totalPaid: Value(newTotalPaid),
          outstandingBalance: Value(newOutstanding),
          lastInvoiceDate: lastInvoiceDate != null
              ? Value(lastInvoiceDate)
              : const Value.absent(),
          lastPaymentDate: lastPaymentDate != null
              ? Value(lastPaymentDate)
              : const Value.absent(),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );
    }, 'updateConnectionStats');
  }

  /// Search for shops/vendors by name or ID
  /// This queries local cache first, then syncs from server if not found
  Future<RepositoryResult<List<Map<String, dynamic>>>> searchShops(
    String query,
  ) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      // First check local shops table
      final localShops =
          await (database.select(database.shops)..where(
                (t) =>
                    t.name.like('%$query%') |
                    t.shopName.like('%$query%') |
                    t.id.equals(query),
              ))
              .get();

      if (localShops.isNotEmpty) {
        return localShops
            .map(
              (s) => {
                'id': s.id,
                'name': s.name,
                'shopName': s.shopName,
                'ownerId': s.ownerId,
                'phone': s.phone,
                'address': s.address,
              },
            )
            .toList();
      }

      // Queue a search request to sync matching shops
      // This will be processed when online and populate local cache
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: 'system',
          operationType:
              SyncOperationType.update, // Using update as a search signal
          targetCollection: 'shop_search',
          documentId: query,
          payload: {
            'query': query,
            'requestedAt': DateTime.now().toIso8601String(),
          },
          priority: 3,
        ),
      );

      return [];
    }, 'searchShops');
  }
}
