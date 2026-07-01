// ============================================================================
// CUSTOMER DASHBOARD REPOSITORY
// ============================================================================
// Offline-first repository for customer dashboard features
// Handles vendor connections, invoices, and dashboard statistics
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/sync_queue_state_machine.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/di/service_locator.dart';

// ============================================================================
// MODELS
// ============================================================================

/// Connected vendor with balance info
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
    this.status = 'ACTIVE',
    this.totalBilled = 0,
    this.totalPaid = 0,
    this.outstandingBalance = 0,
    this.lastInvoiceDate,
    this.lastPaymentDate,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorConnection.fromEntity(CustomerConnectionEntity e) {
    return VendorConnection(
      id: e.id,
      customerId: e.customerId,
      vendorId: e.vendorId,
      vendorName: e.vendorName,
      vendorPhone: e.vendorPhone,
      vendorBusinessName: e.vendorBusinessName,
      vendorAddress: e.vendorAddress,
      customerRefId: e.customerRefId,
      status: e.status,
      totalBilled: e.totalBilled,
      totalPaid: e.totalPaid,
      outstandingBalance: e.outstandingBalance,
      lastInvoiceDate: e.lastInvoiceDate,
      lastPaymentDate: e.lastPaymentDate,
      isSynced: e.isSynced,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
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

/// Customer dashboard statistics
class CustomerDashboardStats {
  final double totalOutstanding;
  final double totalPaid; // <--- Added
  final int vendorCount;
  final int unpaidInvoiceCount;
  final int unreadNotificationCount;
  final VendorConnection? lastActiveVendor;
  final DateTime calculatedAt;

  CustomerDashboardStats({
    required this.totalOutstanding,
    required this.totalPaid, // <--- Added
    required this.vendorCount,
    required this.unpaidInvoiceCount,
    required this.unreadNotificationCount,
    this.lastActiveVendor,
    required this.calculatedAt,
  });
}

/// Invoice for customer view
class CustomerInvoice {
  final String id;
  final String invoiceNumber;
  final String vendorId;
  final String vendorName;
  final DateTime billDate;
  final DateTime? dueDate;
  final double grandTotal;
  final double paidAmount;
  final String status;
  final bool isOverdue;

  CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.vendorId,
    required this.vendorName,
    required this.billDate,
    this.dueDate,
    required this.grandTotal,
    required this.paidAmount,
    required this.status,
    required this.isOverdue,
  });

  double get balanceDue => grandTotal - paidAmount;

  factory CustomerInvoice.fromBillEntity(BillEntity e) {
    final isOverdue =
        e.dueDate != null &&
        DateTime.now().isAfter(e.dueDate!) &&
        e.paidAmount < e.grandTotal;

    return CustomerInvoice(
      id: e.id,
      invoiceNumber: e.invoiceNumber,
      vendorId: e.userId, // vendorId is the bill owner
      vendorName: '', // Will be populated from connection
      billDate: e.billDate,
      dueDate: e.dueDate,
      grandTotal: e.grandTotal,
      paidAmount: e.paidAmount,
      status: e.status,
      isOverdue: isOverdue,
    );
  }
}

// ============================================================================
// REPOSITORY
// ============================================================================

class CustomerDashboardRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  // NEW: Firestore for real-time listeners
  final FirebaseFirestore firestore;

  CustomerDashboardRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    required this.firestore,
  });

  // ============================================
  // VENDOR CONNECTIONS
  // ============================================

  /// Get all connected vendors for a customer
  Future<RepositoryResult<List<VendorConnection>>> getConnectedVendors(
    String customerId,
  ) async {
    return errorHandler.runSafe(() async {
      final entities =
          await (database.select(database.customerConnections)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.status.equals('ACTIVE'))
                ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
              .get();

      return entities.map(VendorConnection.fromEntity).toList();
    }, 'getConnectedVendors');
  }

  /// Watch connected vendors stream
  Stream<List<VendorConnection>> watchConnectedVendors(String customerId) {
    return (database.select(database.customerConnections)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.status.equals('ACTIVE'))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((entities) => entities.map(VendorConnection.fromEntity).toList());
  }

  /// Add a vendor connection
  Future<RepositoryResult<VendorConnection>> addVendorConnection({
    required String customerId,
    required String vendorId,
    required String vendorName,
    String? vendorPhone,
    String? vendorBusinessName,
    String? customerRefId,
  }) async {
    return errorHandler.runSafe(() async {
      final now = DateTime.now();
      final id = const Uuid().v4();

      final entity = CustomerConnectionsCompanion.insert(
        id: id,
        customerId: customerId,
        vendorId: vendorId,
        vendorName: vendorName,
        vendorPhone: Value(vendorPhone),
        vendorBusinessName: Value(vendorBusinessName),
        customerRefId: Value(customerRefId),
        createdAt: now,
        updatedAt: now,
      );

      await database.into(database.customerConnections).insert(entity);

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: customerId,
          operationType: SyncOperationType.create,
          targetCollection: 'customer_connections',
          documentId: id,
          payload: {
            'id': id,
            'customerId': customerId,
            'vendorId': vendorId,
            'vendorName': vendorName,
            'vendorPhone': vendorPhone,
            'vendorBusinessName': vendorBusinessName,
            'customerRefId': customerRefId,
            'status': 'ACTIVE',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ),
      );

      final result = await (database.select(
        database.customerConnections,
      )..where((t) => t.id.equals(id))).getSingle();

      return VendorConnection.fromEntity(result);
    }, 'addVendorConnection');
  }

  // ============================================
  // DASHBOARD STATS
  // ============================================

  /// Get customer dashboard statistics
  Future<RepositoryResult<CustomerDashboardStats>> getDashboardStats(
    String customerId,
  ) async {
    return errorHandler.runSafe(() async {
      // Get all vendor connections
      final connections =
          await (database.select(database.customerConnections)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.status.equals('ACTIVE')))
              .get();

      // Calculate total outstanding and paid
      final totalOutstanding = connections.fold<double>(
        0,
        (total, c) => total + c.outstandingBalance,
      );
      final totalPaid = connections.fold<double>(
        0,
        (total, c) => total + c.totalPaid,
      );

      // Get unread notifications count
      final unreadNotifications =
          await (database.select(database.customerNotifications)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.isRead.equals(false)))
              .get();

      // Find last active vendor
      VendorConnection? lastActiveVendor;
      if (connections.isNotEmpty) {
        connections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        lastActiveVendor = VendorConnection.fromEntity(connections.first);
      }

      // Count unpaid invoices (simplified - from connections)
      final unpaidCount = connections
          .where((c) => c.outstandingBalance > 0)
          .length;

      return CustomerDashboardStats(
        totalOutstanding: totalOutstanding,
        totalPaid: totalPaid,
        vendorCount: connections.length,
        unpaidInvoiceCount: unpaidCount,
        unreadNotificationCount: unreadNotifications.length,
        lastActiveVendor: lastActiveVendor,
        calculatedAt: DateTime.now(),
      );
    }, 'getDashboardStats');
  }

  /// Watch dashboard stats stream
  Stream<CustomerDashboardStats> watchDashboardStats(String customerId) {
    return (database.select(database.customerConnections)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.status.equals('ACTIVE')))
        .watch()
        .asyncMap((connections) async {
          final totalOutstanding = connections.fold<double>(
            0,
            (total, c) => total + c.outstandingBalance,
          );
          final totalPaid = connections.fold<double>(
            0,
            (total, c) => total + c.totalPaid,
          );

          final unreadNotifications =
              await (database.select(database.customerNotifications)
                    ..where((t) => t.customerId.equals(customerId))
                    ..where((t) => t.isRead.equals(false)))
                  .get();

          VendorConnection? lastActiveVendor;
          if (connections.isNotEmpty) {
            connections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            lastActiveVendor = VendorConnection.fromEntity(connections.first);
          }

          return CustomerDashboardStats(
            totalOutstanding: totalOutstanding,
            totalPaid: totalPaid,
            vendorCount: connections.length,
            unpaidInvoiceCount: connections
                .where((c) => c.outstandingBalance > 0)
                .length,
            unreadNotificationCount: unreadNotifications.length,
            lastActiveVendor: lastActiveVendor,
            calculatedAt: DateTime.now(),
          );
        });
  }

  // ============================================
  // INVOICES FOR CUSTOMER
  // ============================================

  /// Get invoices for a customer from a specific vendor
  Future<RepositoryResult<List<BillEntity>>> getInvoicesFromVendor({
    required String customerId,
    required String vendorId,
    String? statusFilter, // PAID, UNPAID, PARTIAL
  }) async {
    return errorHandler.runSafe(() async {
      // Get customer's reference ID at this vendor
      final connection =
          await (database.select(database.customerConnections)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.vendorId.equals(vendorId)))
              .getSingleOrNull();

      String? customerRefToSearch = connection?.customerRefId;

      // FALLBACK: If customerRefId is null, try phone-based lookup
      if (customerRefToSearch == null) {
        // Get customer's phone from current user data
        final customerProfile =
            await (database.select(database.customers)
                  ..where((t) => t.id.equals(customerId))
                  ..limit(1))
                .getSingleOrNull();

        if (customerProfile?.phone != null &&
            customerProfile!.phone!.isNotEmpty) {
          // Find matching customer in vendor's customer list by phone
          final vendorCustomer =
              await (database.select(database.customers)
                    ..where((t) => t.userId.equals(vendorId))
                    ..where((t) => t.phone.equals(customerProfile.phone!)))
                  .getSingleOrNull();

          customerRefToSearch = vendorCustomer?.id;
        }
      }

      if (customerRefToSearch == null) {
        return <BillEntity>[];
      }

      // Get bills where this customer is the customerId
      var query = database.select(database.bills)
        ..where((t) => t.userId.equals(vendorId))
        ..where((t) => t.customerId.equals(customerRefToSearch!))
        ..where((t) => t.deletedAt.isNull());

      if (statusFilter != null) {
        query = query..where((t) => t.status.equals(statusFilter));
      }

      query.orderBy([(t) => OrderingTerm.desc(t.billDate)]);

      return query.get();
    }, 'getInvoicesFromVendor');
  }

  // ============================================
  // REAL-TIME SYNC LISTENERS
  // ============================================

  /// Start listening for real-time updates from connected vendors
  /// and sync them to local database.
  StreamSubscription? _vendorSubscription;
  StreamSubscription? _billsSubscription;

  void startRealtimeSync(String customerId) {
    // Watch local connections to dynamically update listeners
    watchConnectedVendors(customerId).listen((connections) {
      _updateBillListeners(connections, customerId);
    });
  }

  void _updateBillListeners(
    List<VendorConnection> connections,
    String customerId,
  ) {
    _billsSubscription?.cancel();

    for (final vendor in connections) {
      // Listen to this vendor's bills for THIS customer
      final stream = firestore
          .collection('businesses')
          .doc(vendor.vendorId)
          .collection('sales')
          .where('customerId', isEqualTo: vendor.customerRefId)
          .snapshots();

      _billsSubscription = stream.listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            await _syncBillFromFirestore(change.doc, vendor.vendorId);
          }
        }
      });
    }
  }

  Future<void> _syncBillFromFirestore(
    DocumentSnapshot doc,
    String vendorId,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final billDate = (data['billDate'] as Timestamp).toDate();

      await database
          .into(database.bills)
          .insertOnConflictUpdate(
            BillsCompanion(
              id: Value(doc.id),
              userId: Value(vendorId),
              billDate: Value(billDate),
              grandTotal: Value((data['totalAmount'] ?? 0).toDouble()),
              paidAmount: Value((data['paidAmount'] ?? 0).toDouble()),
              status: Value(data['status'] ?? 'pending'),
              itemsJson: Value('[]'),
              createdAt: Value(billDate),
              updatedAt: Value(DateTime.now()),
              isSynced: const Value(true),
            ),
          );
    } catch (e) {
      ErrorHandler.handle(e, stackTrace: StackTrace.current, showUI: false);
    }
  }

  void dispose() {
    _vendorSubscription?.cancel();
    _billsSubscription?.cancel();
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Provider for CustomerDashboardRepository
final customerDashboardRepositoryProvider =
    Provider<CustomerDashboardRepository>((ref) {
      return CustomerDashboardRepository(
        database: AppDatabase.instance,
        syncManager: sl<SyncManager>(),
        errorHandler: sl<ErrorHandler>(),
        firestore: FirebaseFirestore.instance,
      );
    });

/// Provider for dashboard stats
final customerDashboardStatsProvider =
    StreamProvider.family<CustomerDashboardStats, String>((ref, customerId) {
      final repo = ref.watch(customerDashboardRepositoryProvider);
      return repo.watchDashboardStats(customerId);
    });

/// Provider for connected vendors
final connectedVendorsProvider =
    StreamProvider.family<List<VendorConnection>, String>((ref, customerId) {
      final repo = ref.watch(customerDashboardRepositoryProvider);
      return repo.watchConnectedVendors(customerId);
    });
