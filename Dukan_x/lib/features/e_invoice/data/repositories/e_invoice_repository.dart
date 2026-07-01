import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/e_invoice_model.dart';
import '../models/e_way_bill_model.dart';

/// e-Invoice Repository
///
/// Handles local database operations for e-invoices and e-way bills
/// with offline-first architecture.
class EInvoiceRepository {
  final AppDatabase _db;

  EInvoiceRepository(this._db);

  // ============================================================================
  // e-INVOICE OPERATIONS
  // ============================================================================

  /// Create a new e-invoice record
  Future<RepositoryResult<EInvoiceModel>> createEInvoice({
    required String userId,
    required String billId,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db
          .into(_db.eInvoices)
          .insert(
            EInvoicesCompanion.insert(
              id: id,
              userId: userId,
              billId: billId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.eInvoices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to create e-invoice');
      }

      return RepositoryResult.success(EInvoiceModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error creating e-invoice: $e');
    }
  }

  /// Update e-invoice with IRN data (after successful generation)
  Future<RepositoryResult<EInvoiceModel>> updateWithIRN({
    required String id,
    required String irn,
    required String ackNumber,
    required DateTime ackDate,
    String? qrCode,
    String? signedInvoice,
    String? signedQrCode,
  }) async {
    try {
      await (_db.update(_db.eInvoices)..where((t) => t.id.equals(id))).write(
        EInvoicesCompanion(
          irn: Value(irn),
          ackNumber: Value(ackNumber),
          ackDate: Value(ackDate),
          qrCode: Value(qrCode),
          signedInvoice: Value(signedInvoice),
          signedQrCode: Value(signedQrCode),
          status: const Value('GENERATED'),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return getEInvoiceById(id);
    } catch (e) {
      return RepositoryResult.failure('Error updating e-invoice: $e');
    }
  }

  /// Mark e-invoice as failed
  Future<RepositoryResult<void>> markFailed({
    required String id,
    required String error,
  }) async {
    try {
      // First get current retry count
      final current = await (_db.select(
        _db.eInvoices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final currentRetries = current?.retryCount ?? 0;

      await (_db.update(_db.eInvoices)..where((t) => t.id.equals(id))).write(
        EInvoicesCompanion(
          status: const Value('FAILED'),
          lastError: Value(error),
          retryCount: Value(currentRetries + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error marking e-invoice failed: $e');
    }
  }

  /// Cancel an e-invoice
  Future<RepositoryResult<void>> cancelEInvoice({
    required String id,
    required String reason,
  }) async {
    try {
      await (_db.update(_db.eInvoices)..where((t) => t.id.equals(id))).write(
        EInvoicesCompanion(
          status: const Value('CANCELLED'),
          cancelReason: Value(reason),
          cancelledAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error cancelling e-invoice: $e');
    }
  }

  /// Get e-invoice by ID
  Future<RepositoryResult<EInvoiceModel>> getEInvoiceById(String id) async {
    try {
      final entity = await (_db.select(
        _db.eInvoices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('e-Invoice not found');
      }

      return RepositoryResult.success(EInvoiceModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error fetching e-invoice: $e');
    }
  }

  /// Get e-invoice by bill ID
  Future<RepositoryResult<EInvoiceModel?>> getEInvoiceByBillId(
    String billId,
  ) async {
    try {
      final entity = await (_db.select(
        _db.eInvoices,
      )..where((t) => t.billId.equals(billId))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.success(null);
      }

      return RepositoryResult.success(EInvoiceModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error fetching e-invoice: $e');
    }
  }

  /// Get all e-invoices for a user
  Future<RepositoryResult<List<EInvoiceModel>>> getAllEInvoices({
    required String userId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _db.select(_db.eInvoices)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (status != null) {
        query = query..where((t) => t.status.equals(status));
      }

      if (fromDate != null) {
        query = query..where((t) => t.createdAt.isBiggerOrEqualValue(fromDate));
      }

      if (toDate != null) {
        query = query..where((t) => t.createdAt.isSmallerOrEqualValue(toDate));
      }

      final entities = await query.get();
      final models = entities.map((e) => EInvoiceModelX.fromEntity(e)).toList();

      return RepositoryResult.success(models);
    } catch (e) {
      return RepositoryResult.failure('Error fetching e-invoices: $e');
    }
  }

  /// Get pending e-invoices (for retry queue)
  Future<RepositoryResult<List<EInvoiceModel>>> getPendingEInvoices(
    String userId,
  ) async {
    try {
      final entities =
          await (_db.select(_db.eInvoices)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.status.isIn(['PENDING', 'FAILED']),
                )
                ..where((t) => t.retryCount.isSmallerThanValue(3))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();

      return RepositoryResult.success(
        entities.map((e) => EInvoiceModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching pending e-invoices: $e');
    }
  }

  /// Store the NIC request payload for offline retry (outbox pattern).
  ///
  /// Temporarily uses `signedInvoice` column — it's NULL until IRN is
  /// generated, so it's safe to repurpose as outbox payload storage.
  /// Once IRN generation succeeds, [updateWithIRN] overwrites it with
  /// the real signed invoice data.
  Future<void> storeRequestPayload({
    required String id,
    required String payload,
  }) async {
    await (_db.update(_db.eInvoices)..where((t) => t.id.equals(id))).write(
      EInvoicesCompanion(
        signedInvoice: Value(payload),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retrieve the stored NIC request payload for retry.
  ///
  /// Returns `null` if no payload was stored or if IRN was already generated.
  Future<String?> getStoredPayload(String id) async {
    final entity = await (_db.select(
      _db.eInvoices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    // Only return if status is still PENDING/FAILED (not yet generated)
    if (entity == null) return null;
    if (entity.status == 'GENERATED' || entity.status == 'CANCELLED') {
      return null;
    }
    return entity.signedInvoice;
  }

  // ============================================================================
  // e-WAY BILL OPERATIONS
  // ============================================================================

  /// Create a new e-way bill
  Future<RepositoryResult<EWayBillModel>> createEWayBill({
    required String userId,
    required String billId,
    required String fromPlace,
    required String toPlace,
    required int distanceKm,
    String? fromPincode,
    String? toPincode,
    String? vehicleNumber,
    String? transporterId,
    String? transporterName,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db
          .into(_db.eWayBills)
          .insert(
            EWayBillsCompanion.insert(
              id: id,
              userId: userId,
              billId: billId,
              date: now, // Required date field
              fromPlace: Value(fromPlace),
              toPlace: Value(toPlace),
              distanceKm: Value(distanceKm.toDouble()),
              fromPincode: Value(fromPincode),
              toPincode: Value(toPincode),
              vehicleNumber: Value(vehicleNumber),
              transporterId: Value(transporterId),
              transporterName: Value(transporterName),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.eWayBills,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to create e-way bill');
      }

      return RepositoryResult.success(EWayBillModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error creating e-way bill: $e');
    }
  }

  /// Update e-way bill with generated data
  Future<RepositoryResult<EWayBillModel>> updateEWayBillGenerated({
    required String id,
    required String ewbNumber,
    required DateTime ewbDate,
    required DateTime validUntil,
  }) async {
    try {
      await (_db.update(_db.eWayBills)..where((t) => t.id.equals(id))).write(
        EWayBillsCompanion(
          ewbNumber: Value(ewbNumber),
          ewbDate: Value(ewbDate),
          validUntil: Value(validUntil),
          status: const Value('GENERATED'),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      return getEWayBillById(id);
    } catch (e) {
      return RepositoryResult.failure('Error updating e-way bill: $e');
    }
  }

  /// Get e-way bill by ID
  Future<RepositoryResult<EWayBillModel>> getEWayBillById(String id) async {
    try {
      final entity = await (_db.select(
        _db.eWayBills,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('e-Way Bill not found');
      }

      return RepositoryResult.success(EWayBillModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error fetching e-way bill: $e');
    }
  }

  /// Get all e-way bills for a user
  Future<RepositoryResult<List<EWayBillModel>>> getAllEWayBills({
    required String userId,
    String? status,
  }) async {
    try {
      var query = _db.select(_db.eWayBills)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (status != null) {
        query = query..where((t) => t.status.equals(status));
      }

      final entities = await query.get();
      return RepositoryResult.success(
        entities.map((e) => EWayBillModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching e-way bills: $e');
    }
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Get unsynced e-invoices
  Future<List<EInvoiceModel>> getUnsyncedEInvoices(String userId) async {
    final entities = await (_db.select(
      _db.eInvoices,
    )..where((t) => t.userId.equals(userId) & t.isSynced.equals(false))).get();
    return entities.map((e) => EInvoiceModelX.fromEntity(e)).toList();
  }

  /// Mark e-invoice as synced
  Future<void> markEInvoiceSynced(String id) async {
    await (_db.update(_db.eInvoices)..where((t) => t.id.equals(id))).write(
      const EInvoicesCompanion(isSynced: Value(true)),
    );
  }

  /// Get unsynced e-way bills
  Future<List<EWayBillModel>> getUnsyncedEWayBills(String userId) async {
    final entities = await (_db.select(
      _db.eWayBills,
    )..where((t) => t.userId.equals(userId) & t.isSynced.equals(false))).get();
    return entities.map((e) => EWayBillModelX.fromEntity(e)).toList();
  }

  /// Mark e-way bill as synced
  Future<void> markEWayBillSynced(String id) async {
    await (_db.update(_db.eWayBills)..where((t) => t.id.equals(id))).write(
      const EWayBillsCompanion(isSynced: Value(true)),
    );
  }
}
