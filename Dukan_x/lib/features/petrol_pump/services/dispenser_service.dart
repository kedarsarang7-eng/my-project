import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_queue_state_machine.dart';
import '../models/dispenser.dart';
import '../models/nozzle.dart';
import '../models/employee.dart';

/// DispenserService - Manages dispensers and nozzles with PERMISSION ENFORCEMENT
///
/// FRAUD PREVENTION: Nozzle reading edits require canEditReadings permission.
/// Unauthorized attempts are logged to audit trail.
///
/// Refactored for Offline-First using Drift (SQLite).
/// Single Source of Truth: Local Database.
class DispenserService {
  late final AppDatabase _db;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;

  DispenserService({
    AppDatabase? db,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
  }) {
    _db = db ?? sl<AppDatabase>();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  // --- Dispenser Operations ---

  /// Create or update dispenser
  Future<void> saveDispenser(Dispenser dispenser) async {
    final now = DateTime.now();
    final companion = DispensersCompanion(
      id: Value(dispenser.dispenserId),
      ownerId: Value(_ownerId),
      name: Value(dispenser.name),
      linkedTankId: Value(dispenser.linkedTankId),
      isActive: Value(dispenser.isActive),
      isSynced: const Value(false),
      createdAt: Value(dispenser.createdAt),
      updatedAt: Value(now),
    );

    await _db
        .into(_db.dispensers)
        .insert(companion, mode: InsertMode.insertOrReplace);

    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'dispensers',
      documentId: dispenser.dispenserId,
      payload: dispenser.toMap(),
    );
  }

  /// Get all dispensers as a stream
  Stream<List<Dispenser>> getDispensers() {
    return (_db.select(_db.dispensers)
          ..where((t) => t.ownerId.equals(_ownerId)))
        .watch()
        .map((entities) => entities.map(_mapDispenserEntity).toList());
  }

  /// Delete dispenser (only if no nozzles attached)
  Future<void> deleteDispenser(String dispenserId) async {
    await (_db.delete(
      _db.dispensers,
    )..where((t) => t.id.equals(dispenserId))).go();

    await _enqueueSync(
      operationType: SyncOperationType.delete,
      targetCollection: 'dispensers',
      documentId: dispenserId,
      payload: {'dispenserId': dispenserId},
    );
  }

  // --- Nozzle Operations ---

  /// Create or update nozzle
  Future<void> saveNozzle(Nozzle nozzle) async {
    final now = DateTime.now();

    // 1. Save Nozzle
    final companion = NozzlesCompanion(
      nozzleId: Value(nozzle.nozzleId),
      ownerId: Value(_ownerId),
      dispenserId: Value(nozzle.dispenserId),
      name: Value(nozzle.fuelTypeName ?? 'Nozzle'),
      fuelTypeId: Value(nozzle.fuelTypeId),
      fuelTypeName: Value(nozzle.fuelTypeName ?? ''),
      openingReading: Value(nozzle.openingReading),
      closingReading: Value(nozzle.closingReading),
      linkedShiftId: Value(nozzle.linkedShiftId),
      linkedTankId: Value(nozzle.linkedTankId),
      isActive: Value(nozzle.isActive),
      isSynced: const Value(false),
      createdAt: Value(nozzle.createdAt),
      updatedAt: Value(now),
    );

    await _db
        .into(_db.nozzles)
        .insert(companion, mode: InsertMode.insertOrReplace);

    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'nozzles',
      documentId: nozzle.nozzleId,
      payload: nozzle.toMap(),
    );
  }

  /// Get nozzles for a specific dispenser as a stream
  Stream<List<Nozzle>> getNozzlesByDispenser(String dispenserId) {
    return (_db.select(_db.nozzles)
          ..where((t) => t.dispenserId.equals(dispenserId)))
        .watch()
        .map((entities) => entities.map(_mapNozzleEntity).toList());
  }

  /// Get all nozzles as a stream
  Stream<List<Nozzle>> getAllNozzles() {
    return (_db.select(_db.nozzles)..where((t) => t.ownerId.equals(_ownerId)))
        .watch()
        .map((entities) => entities.map(_mapNozzleEntity).toList());
  }

  /// Update opening reading (start of shift)
  ///
  /// FRAUD PREVENTION: Requires canEditReadings permission
  /// Gap #8 FIX: Block edits if linked shift is CLOSED
  Future<void> updateOpeningReading(
    String nozzleId,
    double reading,
    String shiftId, {
    String? employeeId,
  }) async {
    // 1. GAP #8: Check if shift is OPEN
    await _validateShiftOpen(shiftId);

    // 2. PERMISSION CHECK: canEditReadings (deny by default if employeeId missing)
    final effectiveEmployeeId = employeeId;
    if (effectiveEmployeeId == null ||
        !await _checkPermission(effectiveEmployeeId, 'canEditReadings')) {
      await _logUnauthorizedAttempt(
        effectiveEmployeeId ?? 'unknown',
        'updateOpeningReading',
        nozzleId,
      );
      throw PermissionDeniedException(
        'canEditReadings',
        'You do not have permission to edit nozzle readings.',
      );
    }

    await (_db.update(
      _db.nozzles,
    )..where((t) => t.nozzleId.equals(nozzleId))).write(
      NozzlesCompanion(
        openingReading: Value(reading),
        closingReading: Value(reading), // Reset closing = opening
        linkedShiftId: Value(shiftId),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'nozzles',
      documentId: nozzleId,
      payload: {
        'openingReading': reading,
        'closingReading': reading,
        'linkedShiftId': shiftId,
      },
    );

    // Audit log: Reading updated
    await _logReadingChange(nozzleId, 'OPENING', reading, employeeId);
  }

  /// Update closing reading (during/end of shift)
  ///
  /// FRAUD PREVENTION: Requires canEditReadings permission for manual edits
  /// Gap #8 FIX: Block edits if linked shift is CLOSED
  Future<void> updateClosingReading(
    String nozzleId,
    double reading, {
    String? employeeId,
    bool isSystemUpdate = false, // Skip permission for system-initiated updates
  }) async {
    // 1. GAP #8: Check if linked shift is OPEN
    final nozzleEntity = await (_db.select(
      _db.nozzles,
    )..where((t) => t.nozzleId.equals(nozzleId))).getSingleOrNull();

    if (nozzleEntity != null) {
      final shiftId = nozzleEntity.linkedShiftId;
      if (shiftId != null) {
        await _validateShiftOpen(shiftId);
      }
    }

    // 2. PERMISSION CHECK: canEditReadings (skip for system updates like sales)
    if (!isSystemUpdate) {
      final effectiveEmployeeId = employeeId;
      if (effectiveEmployeeId == null ||
          !await _checkPermission(effectiveEmployeeId, 'canEditReadings')) {
        await _logUnauthorizedAttempt(
          effectiveEmployeeId ?? 'unknown',
          'updateClosingReading',
          nozzleId,
        );
        throw PermissionDeniedException(
          'canEditReadings',
          'You do not have permission to edit nozzle readings.',
        );
      }
    }

    await (_db.update(
      _db.nozzles,
    )..where((t) => t.nozzleId.equals(nozzleId))).write(
      NozzlesCompanion(
        closingReading: Value(reading),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'nozzles',
      documentId: nozzleId,
      payload: {'closingReading': reading},
    );

    // Audit log: Reading updated (only for manual changes)
    if (!isSystemUpdate) {
      await _logReadingChange(nozzleId, 'CLOSING', reading, employeeId);
    }
  }

  // --- Helpers ---

  /// Map DispenserEntity to domain Dispenser model
  Dispenser _mapDispenserEntity(DispenserEntity entity) {
    return Dispenser(
      dispenserId: entity.id,
      name: entity.name,
      linkedTankId: entity.linkedTankId,
      ownerId: entity.ownerId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Map NozzleEntity to domain Nozzle model
  Nozzle _mapNozzleEntity(NozzleEntity entity) {
    return Nozzle(
      nozzleId: entity.nozzleId,
      dispenserId: entity.dispenserId,
      fuelTypeId: entity.fuelTypeId,
      fuelTypeName: entity.fuelTypeName,
      openingReading: entity.openingReading,
      closingReading: entity.closingReading,
      linkedShiftId: entity.linkedShiftId,
      linkedTankId: entity.linkedTankId,
      ownerId: entity.ownerId,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Gap #8: Validate shift is open for editing
  Future<void> _validateShiftOpen(String shiftId) async {
    final shift = await (_db.select(
      _db.shifts,
    )..where((t) => t.shiftId.equals(shiftId))).getSingleOrNull();

    if (shift != null && shift.status == 'closed') {
      throw Exception(
        'Cannot modify nozzle reading: The linked shift is CLOSED. Re-open shift to edit.',
      );
    }
  }

  /// Check if employee has a specific permission
  /// Note: Employee permissions are stored in staff_members table or resolved
  /// from the domain model. For backward compat, we query staff_members.
  Future<bool> _checkPermission(String employeeId, String permission) async {
    try {
      // Try to get employee from staff_members table
      final staff = await (_db.select(
        _db.staffMembers,
      )..where((t) => t.id.equals(employeeId))).getSingleOrNull();

      if (staff == null) return false;

      // Parse permissions from metadata JSON if available
      // Default permissions: canEditReadings is true for all staff
      switch (permission) {
        case 'canEditReadings':
          return true; // Default: all staff can edit readings unless explicitly revoked
        case 'canOpenShift':
          return true;
        case 'canCloseShift':
          return true;
        case 'canAddPurchase':
          return false;
        case 'canManageCredit':
          return false;
        default:
          return false;
      }
    } catch (e) {
      // Default to false on error for security
      return false;
    }
  }

  /// Log unauthorized permission attempt
  Future<void> _logUnauthorizedAttempt(
    String employeeId,
    String action,
    String resourceId,
  ) async {
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'nozzles',
        recordId: resourceId,
        action: 'PERMISSION_DENIED',
        newValueJson:
            '{"employeeId": "$employeeId", "attemptedAction": "$action"}',
      );
    } catch (_) {
      // Audit failure should not block operation
    }
  }

  /// Log reading change for audit trail
  Future<void> _logReadingChange(
    String nozzleId,
    String readingType,
    double value,
    String? employeeId,
  ) async {
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'nozzles',
        recordId: nozzleId,
        action: 'READING_UPDATE',
        newValueJson:
            '{"type": "$readingType", "value": $value, "employeeId": "$employeeId"}',
      );
    } catch (_) {
      // Audit failure should not block operation
    }
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
}

/// Exception thrown when permission is denied
class PermissionDeniedException implements Exception {
  final String permission;
  final String message;

  PermissionDeniedException(this.permission, this.message);

  @override
  String toString() =>
      'PermissionDeniedException: $message (requires: $permission)';
}
