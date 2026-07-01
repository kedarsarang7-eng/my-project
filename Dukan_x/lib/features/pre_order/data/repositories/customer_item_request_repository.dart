import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/customer_item_request.dart';

class CustomerItemRequestRepository {
  final AppDatabase _db;
  final SyncManager _syncManager;

  CustomerItemRequestRepository({
    required AppDatabase db,
    required SyncManager syncManager,
  }) : _db = db,
       _syncManager = syncManager;

  /// Create a new request (Offline-First)
  Future<void> createRequest(CustomerItemRequest request) async {
    try {
      // 1. Insert into Local Database
      await _db
          .into(_db.customerItemRequests)
          .insert(
            CustomerItemRequestsCompanion.insert(
              id: request.id,
              customerId: request.customerId,
              vendorId: request.vendorId,
              status: Value(request.status.name),
              itemsJson: jsonEncode(
                request.items.map((e) => e.toMap()).toList(),
              ),
              note: Value(request.note),
              createdAt: request.createdAt,
              updatedAt: request.updatedAt,
              isSynced: const Value(false),
            ),
          );

      // 2. Queue for Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: request.customerId,
          operationType: SyncOperationType.create,
          targetCollection: 'customer_item_requests',
          documentId: request.id,
          payload: request.toMap(),
          priority: 1,
          ownerId: request.vendorId,
        ),
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to create request',
      );
      rethrow;
    }
  }

  /// Update a request (Vendor or Customer action)
  Future<void> updateRequest(CustomerItemRequest request) async {
    try {
      final now = DateTime.now();
      request.updatedAt = now;

      // 1. Update Local Database
      await (_db.update(
        _db.customerItemRequests,
      )..where((t) => t.id.equals(request.id))).write(
        CustomerItemRequestsCompanion(
          status: Value(request.status.name),
          itemsJson: Value(
            jsonEncode(request.items.map((e) => e.toMap()).toList()),
          ),
          note: Value(request.note),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ),
      );

      // 2. Queue for Sync
      await _syncManager.enqueue(
        SyncQueueItem.create(
          userId: request.customerId,
          operationType: SyncOperationType.update,
          targetCollection: 'customer_item_requests',
          documentId: request.id,
          payload: request.toMap(),
          priority: 1,
          ownerId: request.vendorId,
        ),
      );
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        userMessage: 'Failed to update request',
      );
      rethrow;
    }
  }

  /// Watch requests for a specific customer (Reactive)
  Stream<List<CustomerItemRequest>> watchRequestsForCustomer(
    String customerId,
  ) {
    return (_db.select(_db.customerItemRequests)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map((row) => _mapToModel(row)).toList());
  }

  /// Watch requests for a specific vendor (Reactive)
  Stream<List<CustomerItemRequest>> watchRequestsForVendor(String vendorId) {
    return (_db.select(_db.customerItemRequests)
          ..where((t) => t.vendorId.equals(vendorId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map((row) => _mapToModel(row)).toList());
  }

  /// Helper to map Entity -> Model
  CustomerItemRequest _mapToModel(CustomerItemRequestEntity row) {
    return CustomerItemRequest(
      id: row.id,
      customerId: row.customerId,
      vendorId: row.vendorId,
      status: RequestStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => RequestStatus.pending,
      ),
      items: (jsonDecode(row.itemsJson) as List)
          .map((e) => CustomerItemRequestItem.fromMap(e))
          .toList(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      note: row.note,
    );
  }

  // --- LEGACY COMPATIBILITY (Drafts) ---

  Future<CustomerItemRequest?> getDraft(String customerId) async {
    // Return null to indicate no saved draft (in-memory only for legacy screen)
    return null;
  }

  Future<void> saveDraft(CustomerItemRequest request) async {
    // No-op for now
  }
}
