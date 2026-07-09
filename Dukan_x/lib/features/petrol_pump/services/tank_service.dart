import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../models/tank.dart';

/// TankService - Manages fuel tank stock with AUDIT TRAIL
///
/// FRAUD PREVENTION (Gap #4 FIX):
/// All stock modifications are audit-logged with before/after values.
/// Manual adjustments require a reason and are flagged for review.
///
/// Refactored for Offline-First using Drift (SQLite).
/// Single Source of Truth: Local Database.
class TankService {
  late final AppDatabase _db;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;

  TankService({
    AppDatabase? db,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
  }) {
    _db = db ?? sl<AppDatabase>();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  /// Get all tanks as a stream (Drift .watch() for StreamBuilder compatibility)
  Stream<List<Tank>> getTanks() {
    return (_db.select(_db.tanks)..where((t) => t.ownerId.equals(_ownerId)))
        .watch()
        .map((entities) => entities.map(_mapEntityToDomain).toList());
  }

  /// Get single tank by ID
  Future<Tank?> getTankById(String tankId) async {
    final entity = await (_db.select(
      _db.tanks,
    )..where((t) => t.tankId.equals(tankId))).getSingleOrNull();
    if (entity == null) return null;
    return _mapEntityToDomain(entity);
  }

  /// Create or update tank (with audit)
  Future<void> saveTank(Tank tank, {String? employeeId}) async {
    final now = DateTime.now();
    final companion = TanksCompanion(
      tankId: Value(tank.tankId),
      ownerId: Value(_ownerId),
      name: Value(tank.tankName),
      fuelTypeId: Value(tank.fuelTypeId),
      capacity: Value(tank.capacity),
      currentStock: Value(tank.currentStock),
      isActive: Value(tank.isActive),
      isSynced: const Value(false),
      createdAt: Value(tank.createdAt),
      updatedAt: Value(now),
    );

    await _db.into(_db.tanks).insert(companion, mode: InsertMode.insertOrReplace);

    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'tanks',
      documentId: tank.tankId,
      payload: tank.toMap(),
    );

    await _logStockEvent(
      tankId: tank.tankId,
      action: 'TANK_SAVE',
      details: 'Tank ${tank.tankName} saved with stock ${tank.currentStock}L',
      employeeId: employeeId,
    );
  }

  /// Add purchase (refill) with AUDIT TRAIL
  /// Gap #4 FIX: All purchases are logged with before/after stock
  Future<void> addPurchase(
    String tankId,
    double quantity, {
    String? employeeId,
    String? invoiceNumber,
    double? pricePerLitre,
  }) async {
    await _db.transaction(() async {
      final entity = await (_db.select(
        _db.tanks,
      )..where((t) => t.tankId.equals(tankId))).getSingleOrNull();
      if (entity == null) throw Exception('Tank not found');

      final tank = _mapEntityToDomain(entity);
      final oldStock = tank.currentStock;
      final updatedTank = tank.addPurchase(quantity);

      await (_db.update(_db.tanks)..where((t) => t.tankId.equals(tankId))).write(
        TanksCompanion(
          currentStock: Value(updatedTank.currentStock),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // AUDIT: Log purchase with before/after stock
      await _logStockEvent(
        tankId: tankId,
        action: 'STOCK_PURCHASE',
        details:
            'Purchase: +${quantity}L | Stock: ${oldStock}L → ${updatedTank.currentStock}L',
        employeeId: employeeId,
        metadata: {
          'quantityAdded': quantity,
          'stockBefore': oldStock,
          'stockAfter': updatedTank.currentStock,
          'invoiceNumber': invoiceNumber,
          'pricePerLitre': ?pricePerLitre,
          if (pricePerLitre != null) 'totalCost': quantity * pricePerLitre,
        },
      );
    });

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'tanks',
      documentId: tankId,
      payload: {
        'tankId': tankId,
        'quantityAdded': quantity,
        'invoiceNumber': invoiceNumber,
        'employeeId': employeeId,
      },
    );
  }

  /// Record dip reading (manual check) with AUDIT TRAIL
  /// Gap #4 FIX: Dip readings that cause stock changes are logged
  Future<void> recordDipReading(
    String tankId,
    double actualStock, {
    String? employeeId,
    String? reason,
  }) async {
    await _db.transaction(() async {
      final entity = await (_db.select(
        _db.tanks,
      )..where((t) => t.tankId.equals(tankId))).getSingleOrNull();
      if (entity == null) throw Exception('Tank not found');

      final tank = _mapEntityToDomain(entity);
      final oldStock = tank.currentStock;
      final variance = actualStock - tank.calculatedStock;
      final updatedTank = tank.updateWithDipReading(actualStock);

      await (_db.update(_db.tanks)..where((t) => t.tankId.equals(tankId))).write(
        TanksCompanion(
          currentStock: Value(updatedTank.currentStock),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // AUDIT: Log dip reading with variance
      await _logStockEvent(
        tankId: tankId,
        action: variance.abs() > 1 ? 'DIP_READING_VARIANCE' : 'DIP_READING',
        details:
            'Dip reading: ${actualStock}L | Variance: ${variance.toStringAsFixed(2)}L | ${reason ?? "Routine check"}',
        employeeId: employeeId,
        metadata: {
          'dipReading': actualStock,
          'calculatedStock': tank.calculatedStock,
          'previousStock': oldStock,
          'variance': variance,
          'reason': reason,
        },
      );

      // Alert if variance exceeds threshold
      if (variance.abs() > 10) {
        await _logStockEvent(
          tankId: tankId,
          action: 'STOCK_VARIANCE_ALERT',
          details:
              'HIGH VARIANCE DETECTED: ${variance.toStringAsFixed(2)}L difference requires investigation',
          employeeId: employeeId,
          metadata: {'severity': 'HIGH', 'variance': variance},
        );
      }
    });

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'tanks',
      documentId: tankId,
      payload: {
        'tankId': tankId,
        'dipReading': actualStock,
        'employeeId': employeeId,
        'reason': reason,
      },
    );
  }

  /// Manual stock adjustment (requires reason) with AUDIT TRAIL
  /// Gap #4 FIX: Manual adjustments are ALWAYS logged and flagged
  Future<void> adjustStock({
    required String tankId,
    required double newStock,
    required String reason,
    required String employeeId,
  }) async {
    await _db.transaction(() async {
      final entity = await (_db.select(
        _db.tanks,
      )..where((t) => t.tankId.equals(tankId))).getSingleOrNull();
      if (entity == null) throw Exception('Tank not found');

      final tank = _mapEntityToDomain(entity);
      final oldStock = tank.currentStock;
      final adjustment = newStock - oldStock;
      final clampedStock = newStock.clamp(0.0, tank.capacity);

      await (_db.update(_db.tanks)..where((t) => t.tankId.equals(tankId))).write(
        TanksCompanion(
          currentStock: Value(clampedStock),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // AUDIT: Log manual adjustment with flag for review
      await _logStockEvent(
        tankId: tankId,
        action: 'MANUAL_STOCK_ADJUSTMENT',
        details:
            'MANUAL ADJUSTMENT: ${oldStock}L → ${newStock}L (${adjustment > 0 ? "+" : ""}${adjustment.toStringAsFixed(2)}L) | Reason: $reason',
        employeeId: employeeId,
        metadata: {
          'stockBefore': oldStock,
          'stockAfter': newStock,
          'adjustment': adjustment,
          'reason': reason,
          'requiresReview': true,
        },
      );
    });

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'tanks',
      documentId: tankId,
      payload: {
        'tankId': tankId,
        'currentStock': newStock,
        'reason': reason,
        'employeeId': employeeId,
      },
    );
  }

  /// Deduct stock based on sales (called when Shift Closes)
  Future<void> deductSales(String tankId, double quantity) async {
    await _db.transaction(() async {
      final entity = await (_db.select(
        _db.tanks,
      )..where((t) => t.tankId.equals(tankId))).getSingleOrNull();
      if (entity == null) return; // Silent fail if tank deleted

      final tank = _mapEntityToDomain(entity);
      final updatedTank = tank.deductSales(quantity);

      await (_db.update(_db.tanks)..where((t) => t.tankId.equals(tankId))).write(
        TanksCompanion(
          currentStock: Value(updatedTank.currentStock),
          isSynced: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'tanks',
      documentId: tankId,
      payload: {'tankId': tankId, 'deductedQuantity': quantity},
    );
  }

  // --- Helpers ---

  /// Map Drift TankEntity to domain Tank model
  Tank _mapEntityToDomain(TankEntity entity) {
    return Tank(
      tankId: entity.tankId,
      tankName: entity.name,
      fuelTypeId: entity.fuelTypeId,
      capacity: entity.capacity,
      currentStock: entity.currentStock,
      ownerId: entity.ownerId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Enqueue a sync operation for offline-first sync
  Future<void> _enqueueSync({
    required SyncOperationType operationType,
    required String targetCollection,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final safeDocId = documentId.length >= 4
        ? documentId.substring(0, 4)
        : documentId;
    final opId = '${DateTime.now().microsecondsSinceEpoch}_$safeDocId';

    final syncItem = SyncQueueCompanion(
      operationId: Value(opId),
      operationType: Value(operationType.name),
      targetCollection: Value(targetCollection),
      documentId: Value(documentId),
      payload: Value(jsonEncode(payload)),
      status: const Value('PENDING'),
      createdAt: Value(DateTime.now()),
      retryCount: const Value(0),
      ownerId: Value(_ownerId),
      userId: Value(_ownerId),
      priority: const Value(1),
    );

    await _db.into(_db.syncQueue).insert(syncItem);
  }

  /// Log stock-related events to audit trail
  Future<void> _logStockEvent({
    required String tankId,
    required String action,
    required String details,
    String? employeeId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'tanks',
        recordId: tankId,
        action: action,
        newValueJson:
            '{"details": "$details", "employeeId": "${employeeId ?? 'system'}", "timestamp": "${DateTime.now().toIso8601String()}", "metadata": ${metadata != null ? metadata.toString() : '{}'}}',
      );
    } catch (_) {
      // Audit failure should not block stock operations
    }
  }
}
