// ============================================================================
// VENDORS REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages supplier/vendor data with Drift persistence
//
// Author: Antigravity
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';

/// Vendor Model for UI
class Vendor {
  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstin;
  final double totalPurchased;
  final double totalPaid;
  final double totalOutstanding;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vendor({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstin,
    this.totalPurchased = 0.0,
    this.totalPaid = 0.0,
    this.totalOutstanding = 0.0,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'gstin': gstin,
    'totalPurchased': totalPurchased,
    'totalPaid': totalPaid,
    'totalOutstanding': totalOutstanding,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Vendor.fromEntity(VendorEntity e) => Vendor(
    id: e.id,
    userId: e.userId,
    name: e.name,
    phone: e.phone,
    email: e.email,
    address: e.address,
    gstin: e.gstin,
    totalPurchased: e.totalPurchased,
    totalPaid: e.totalPaid,
    totalOutstanding: e.totalOutstanding,
    isActive: e.isActive,
    isSynced: e.isSynced,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
  );
}

/// Vendors Repository
class VendorsRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;

  VendorsRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
  });

  String get collectionName => 'vendors';

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a vendor
  Future<RepositoryResult<Vendor>> createVendor(Vendor vendor) async {
    return await errorHandler.runSafe<Vendor>(() async {
      final now = DateTime.now();

      await database
          .into(database.vendors)
          .insert(
            VendorsCompanion.insert(
              id: vendor.id,
              userId: vendor.userId,
              name: vendor.name,
              phone: Value(vendor.phone),
              email: Value(vendor.email),
              address: Value(vendor.address),
              gstin: Value(vendor.gstin),
              totalPurchased: Value(vendor.totalPurchased),
              totalPaid: Value(vendor.totalPaid),
              totalOutstanding: Value(vendor.totalOutstanding),
              isActive: Value(vendor.isActive),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendor.userId,
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: vendor.id,
          payload: vendor.toMap(),
        ),
      );

      return vendor;
    }, 'createVendor');
  }

  /// Update a vendor
  Future<RepositoryResult<Vendor>> updateVendor(Vendor vendor) async {
    return await errorHandler.runSafe<Vendor>(() async {
      final now = DateTime.now();

      await (database.update(
        database.vendors,
      )..where((t) => t.id.equals(vendor.id))).write(
        VendorsCompanion(
          name: Value(vendor.name),
          phone: Value(vendor.phone),
          email: Value(vendor.email),
          address: Value(vendor.address),
          gstin: Value(vendor.gstin),
          totalPurchased: Value(vendor.totalPurchased),
          totalPaid: Value(vendor.totalPaid),
          totalOutstanding: Value(vendor.totalOutstanding),
          isActive: Value(vendor.isActive),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendor.userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: vendor.id,
          payload: vendor.toMap(),
        ),
      );

      return vendor;
    }, 'updateVendor');
  }

  /// Delete a vendor (soft delete)
  Future<RepositoryResult<bool>> deleteVendor(String id, String userId) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();

      await (database.update(
        database.vendors,
      )..where((t) => t.id.equals(id))).write(
        VendorsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: userId,
          operationType: SyncOperationType.delete,
          targetCollection: collectionName,
          documentId: id,
          payload: const {},
        ),
      );

      return true;
    }, 'deleteVendor');
  }

  /// Get vendor by ID
  Future<RepositoryResult<Vendor>> getById(String id) async {
    return await errorHandler.runSafe<Vendor>(() async {
      final entity = await (database.select(
        database.vendors,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) throw Exception('Vendor not found');
      return Vendor.fromEntity(entity);
    }, 'getById');
  }

  /// Get all vendors
  Future<RepositoryResult<List<Vendor>>> getAll(String userId) async {
    return await errorHandler.runSafe<List<Vendor>>(() async {
      final results =
          await (database.select(database.vendors)
                ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();

      return results.map(Vendor.fromEntity).toList();
    }, 'getAll');
  }

  /// Watch vendors
  Stream<List<Vendor>> watchAll(String userId) {
    return (database.select(database.vendors)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(Vendor.fromEntity).toList());
  }

  // ============================================
  // BUSINESS LOGIC
  // ============================================

  /// Update vendor balance and totals after a purchase
  Future<void> updateVendorAfterPurchase({
    required String vendorId,
    required double billAmount,
    required double paidAmount,
  }) async {
    final outstandingIncrement = billAmount - paidAmount;

    final vendor = await (database.select(
      database.vendors,
    )..where((t) => t.id.equals(vendorId))).getSingleOrNull();

    if (vendor != null) {
      final now = DateTime.now();
      await (database.update(
        database.vendors,
      )..where((t) => t.id.equals(vendorId))).write(
        VendorsCompanion(
          totalPurchased: Value(vendor.totalPurchased + billAmount),
          totalPaid: Value(vendor.totalPaid + paidAmount),
          totalOutstanding: Value(
            vendor.totalOutstanding + outstandingIncrement,
          ),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: vendor.userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: vendorId,
          payload: {
            'totalPurchased': vendor.totalPurchased + billAmount,
            'totalPaid': vendor.totalPaid + paidAmount,
            'totalOutstanding': vendor.totalOutstanding + outstandingIncrement,
            'updatedAt': now.toIso8601String(),
          },
        ),
      );
    }
  }
}
