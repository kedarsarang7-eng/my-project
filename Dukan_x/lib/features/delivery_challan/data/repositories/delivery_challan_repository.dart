import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../../models/delivery_challan_model.dart';

class DeliveryChallanRepository {
  final AppDatabase _db;

  DeliveryChallanRepository(this._db);

  /// Create a new Delivery Challan
  Future<void> createChallan(DeliveryChallan challan) async {
    await _db.transaction(() async {
      await _db
          .into(_db.deliveryChallans)
          .insert(
            DeliveryChallansCompanion(
              id: Value(challan.id),
              userId: Value(challan.userId),
              challanNumber: Value(challan.challanNumber),
              customerId: Value(challan.customerId),
              customerName: Value(challan.customerName),
              challanDate: Value(challan.challanDate),
              dueDate: Value(challan.dueDate),
              subtotal: Value(challan.subtotal),
              taxAmount: Value(challan.taxAmount),
              grandTotal: Value(challan.grandTotal),
              status: Value(challan.status.name.toUpperCase()),
              transportMode: Value(challan.transportMode),
              vehicleNumber: Value(challan.vehicleNumber),
              eWayBillNumber: Value(challan.eWayBillNumber),
              shippingAddress: Value(challan.shippingAddress),
              lrNumber: Value(challan.lrNumber),
              transporterName: Value(challan.transporterName),
              itemsJson: Value(
                jsonEncode(challan.items.map((e) => e.toJson()).toList()),
              ),
              isSynced: const Value(false),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );

      // Queue for sync
      await _queueForSync(
        userId: challan.userId,
        operationType: SyncOperationType.create,
        documentId: challan.id,
        payload: challan.toJson(),
      );
    });
  }

  /// Update an existing Challan
  Future<void> updateChallan(DeliveryChallan challan) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.deliveryChallans,
      )..where((t) => t.id.equals(challan.id))).write(
        DeliveryChallansCompanion(
          customerId: Value(challan.customerId),
          customerName: Value(challan.customerName),
          challanDate: Value(challan.challanDate),
          subtotal: Value(challan.subtotal),
          taxAmount: Value(challan.taxAmount),
          grandTotal: Value(challan.grandTotal),
          status: Value(challan.status.name.toUpperCase()),
          transportMode: Value(challan.transportMode),
          vehicleNumber: Value(challan.vehicleNumber),
          eWayBillNumber: Value(challan.eWayBillNumber),
          shippingAddress: Value(challan.shippingAddress),
          lrNumber: Value(challan.lrNumber),
          transporterName: Value(challan.transporterName),
          itemsJson: Value(
            jsonEncode(challan.items.map((e) => e.toJson()).toList()),
          ),
          convertedBillId: Value(challan.convertedBillId),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Queue for sync
      await _queueForSync(
        userId: challan.userId,
        operationType: SyncOperationType.update,
        documentId: challan.id,
        payload: challan.toJson(),
      );
    });
  }

  /// Get Challan by ID
  Future<DeliveryChallan?> getById(String id) async {
    final row = await (_db.select(
      _db.deliveryChallans,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (row == null) return null;
    return _entityToModel(row);
  }

  /// Get all Challans for a user
  Future<List<DeliveryChallan>> getAll(String userId) async {
    final rows =
        await (_db.select(_db.deliveryChallans)
              ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.desc(t.challanDate),
                (t) => OrderingTerm.desc(t.createdAt),
              ]))
            .get();

    return rows.map(_entityToModel).toList();
  }

  /// Watch all Challans (for StreamBuilder)
  Stream<List<DeliveryChallan>> watchAll(String userId) {
    return (_db.select(_db.deliveryChallans)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.challanDate),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .map((rows) => rows.map(_entityToModel).toList());
  }

  /// Convert Entity to Model
  DeliveryChallan _entityToModel(DeliveryChallanEntity row) {
    List<DeliveryChallanItem> items = [];
    try {
      final List<dynamic> jsonList = jsonDecode(row.itemsJson);
      items = jsonList.map((e) => DeliveryChallanItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error parsing DC items: $e');
    }

    DeliveryChallanStatus status = DeliveryChallanStatus.draft;
    try {
      status = DeliveryChallanStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == row.status,
        orElse: () => DeliveryChallanStatus.draft,
      );
    } catch (_) {}

    return DeliveryChallan(
      id: row.id,
      userId: row.userId,
      challanNumber: row.challanNumber,
      customerId: row.customerId,
      customerName: row.customerName,
      challanDate: row.challanDate,
      dueDate: row.dueDate,
      subtotal: row.subtotal,
      taxAmount: row.taxAmount,
      grandTotal: row.grandTotal,
      status: status,
      transportMode: row.transportMode,
      vehicleNumber: row.vehicleNumber,
      eWayBillNumber: row.eWayBillNumber,
      shippingAddress: row.shippingAddress,
      lrNumber: row.lrNumber,
      transporterName: row.transporterName,
      items: items,
      convertedBillId: row.convertedBillId,
      isSynced: row.isSynced,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  /// Queue operations for Firestore sync
  Future<void> _queueForSync({
    required String userId,
    required SyncOperationType operationType,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final syncItem = SyncQueueItem.create(
      userId: userId,
      operationType: operationType,
      targetCollection: 'delivery_challans', // Firestore collection
      documentId: documentId,
      payload: payload,
      priority: 1, // High priority
    );

    await SyncManager.instance.enqueue(syncItem);
  }
}
