import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/database/app_database.dart';
import '../models/shift.dart';

import '../../../../core/sync/sync_queue_state_machine.dart';
import '../models/shift_reconciliation.dart';

/// ShiftService - Manages petrol pump shift lifecycle with FRAUD PREVENTION
///
/// Features:
/// - Staff-Nozzle Assignments
/// - Per-Staff Sales Tracking
/// - Cash Accountability & Settlement
/// - Offline-First Sync
///
/// Refactored for Offline-First using Drift (SQLite).
/// Single Source of Truth: Local Database.
class ShiftService {
  late final AppDatabase _db;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;

  ShiftService({
    AppDatabase? db,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
  }) {
    _db = db ?? sl<AppDatabase>();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  /// Check if there is already an open shift
  Future<Shift?> getActiveShift() async {
    final query = _db.select(_db.shifts)
      ..where((t) => t.status.equals(ShiftStatus.open.name))
      ..limit(1);

    final entity = await query.getSingleOrNull();
    if (entity == null) return null;
    return _mapToDomain(entity);
  }

  /// Open a new shift
  ///
  /// FRAUD PREVENTION: Captures nozzle readings at shift start
  Future<Shift> openShift(String name, List<String> employeeIds) async {
    // 1. Ensure no other open shift
    final active = await getActiveShift();
    if (active != null) {
      throw Exception('Another shift is already open. Please close it first.');
    }

    final newShiftId = _generateId();
    final startTime = DateTime.now();

    // 2. Create new shift
    final companion = ShiftsCompanion(
      shiftId: Value(newShiftId),
      shiftName: Value(name),
      startTime: Value(startTime),
      assignedEmployeeIds: Value(jsonEncode(employeeIds)),
      ownerId: Value(_ownerId),
      status: Value(ShiftStatus.open.name),
      createdAt: Value(startTime),
      updatedAt: Value(startTime),
      isSynced: const Value(false),
    );

    // Create assignments if provided (backward compatibility)
    // New code should use assignNozzleToStaff() explicitly

    print('DEBUG: Insert Shift Companion');
    try {
      await _db.into(_db.shifts).insert(companion);
    } catch (e, stack) {
      print('DEBUG: Shift Insert Failed: $e');
      print(stack);
      rethrow;
    }

    // Sync Queue: Shift Open
    print('DEBUG: Enqueue Shift Sync');
    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'shifts',
      documentId: newShiftId,
      payload: {
        'shiftId': newShiftId,
        'shiftName': name,
        'startTime': startTime.toIso8601String(),
        'assignedEmployeeIds': jsonEncode(employeeIds),
        'ownerId': _ownerId,
        'status': ShiftStatus.open.name,
      },
    );

    // 3. Reset all nozzles for new shift (carry over closing reading to opening)
    print('DEBUG: Resetting Nozzles');
    await _resetNozzlesForShift(newShiftId);

    // 4. Audit log: Shift opened
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'shifts',
        recordId: newShiftId,
        action: 'SHIFT_OPEN',
        newValueJson:
            '{"shiftName": "$name", "employees": ${employeeIds.length}}',
      );
    } catch (_) {
      // Audit log failure should not block shift operations
    }

    // Return domain model
    return Shift(
      shiftId: newShiftId,
      shiftName: name,
      startTime: startTime,
      assignedEmployeeIds: employeeIds,
      ownerId: _ownerId,
      status: ShiftStatus.open,
    );
  }

  /// Assign a nozzle to a staff member for the current open shift
  Future<void> assignNozzleToStaff(
    String shiftId,
    String staffId,
    String nozzleId,
  ) async {
    final allocationId = _generateId();

    // Revoke previous assignment for this nozzle in this shift if any
    await (_db.update(_db.staffNozzleAssignments)..where(
          (t) =>
              t.shiftId.equals(shiftId) &
              t.nozzleId.equals(nozzleId) &
              t.revokedAt.isNull(),
        ))
        .write(
          StaffNozzleAssignmentsCompanion(revokedAt: Value(DateTime.now())),
        );

    // Create new assignment
    await _db
        .into(_db.staffNozzleAssignments)
        .insert(
          StaffNozzleAssignmentsCompanion(
            id: Value(allocationId),
            shiftId: Value(shiftId),
            staffId: Value(staffId),
            nozzleId: Value(nozzleId),
            assignedAt: Value(DateTime.now()),
            assignedBy: Value(_ownerId),
            createdAt: Value(DateTime.now()),
          ),
        );

    // Audit
    await _auditRepo.logAction(
      userId: _ownerId,
      targetTableName: 'staff_nozzle_assignments',
      recordId: allocationId,
      action: 'ASSIGN_NOZZLE',
      newValueJson:
          '{"shift": "$shiftId", "staff": "$staffId", "nozzle": "$nozzleId"}',
    );
  }

  /// Close current shift with MANDATORY RECONCILIATION & STAFF SETTLEMENT
  Future<void> closeShift(
    String shiftId, {
    required String closedBy,
    required double cashDeclared,
    String? notes,
    bool forceClose = false, // Owner override only
  }) async {
    // 1. Get reconciliation data
    final reconciliation = await calculateShiftSales(shiftId);

    // 2. FRAUD CHECK: Block if variance exceeds tolerance (unless owner force-closes)
    if (!reconciliation.isWithinTolerance && !forceClose) {
      throw ShiftReconciliationException(
        'Shift cannot be closed: ${reconciliation.varianceLitres.abs().toStringAsFixed(2)}L variance detected. '
        'Expected ${reconciliation.nozzleLitres.toStringAsFixed(2)}L from readings, '
        'but only ${reconciliation.billedLitres.toStringAsFixed(2)}L billed.',
        reconciliation: reconciliation,
      );
    }

    // 3. Gap #6 FIX: Cash declaration verification
    final expectedCash = reconciliation.cashAmount;
    final cashVariance = cashDeclared - expectedCash;
    final cashVarianceThreshold = 100.0; // ₹100 tolerance

    // Log cash declaration for audit
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'shifts',
        recordId: shiftId,
        action: cashVariance.abs() > cashVarianceThreshold
            ? 'CASH_VARIANCE_ALERT'
            : 'CASH_DECLARATION',
        newValueJson:
            '{"declared": $cashDeclared, "expected": $expectedCash, "variance": $cashVariance, "closedBy": "$closedBy"}',
      );
    } catch (_) {}

    // Block close if cash declaration is failing
    if (cashVariance.abs() > cashVarianceThreshold && !forceClose) {
      throw CashDeclarationException(
        'Cash declaration mismatch: Declared ₹${cashDeclared.toStringAsFixed(0)} but expected ₹${expectedCash.toStringAsFixed(0)}. '
        'Variance: ₹${cashVariance.abs().toStringAsFixed(0)}. Please recount or contact owner.',
        declaredAmount: cashDeclared,
        expectedAmount: expectedCash,
        variance: cashVariance,
      );
    }

    final endTime = DateTime.now();

    // 5. Update shift with cash declaration
    await (_db.update(
      _db.shifts,
    )..where((t) => t.shiftId.equals(shiftId))).write(
      ShiftsCompanion(
        endTime: Value(endTime),
        status: Value(ShiftStatus.closed.name),
        totalSaleAmount: Value(reconciliation.totalSalesAmount),
        totalLitresSold: Value(reconciliation.billedLitres),
        cashCollected: Value(reconciliation.cashAmount),
        cashDeclared: Value(cashDeclared),
        cashVariance: Value(cashVariance),
        closedBy: Value(closedBy),
        notes: Value(notes),
        reconciliationJson: Value(jsonEncode(reconciliation.toMap())),
        wasForced: Value(forceClose),
        updatedAt: Value(endTime),
        isSynced: const Value(false),
      ),
    );

    // 5a. Create Staff Settlements
    await createStaffSettlements(shiftId);

    // Sync Queue: Shift Close
    await _enqueueSync(
      operationType: SyncOperationType.update,
      targetCollection: 'shifts',
      documentId: shiftId,
      payload: {
        'endTime': endTime.toIso8601String(),
        'status': ShiftStatus.closed.name,
        'totalSaleAmount': reconciliation.totalSalesAmount,
        'totalLitresSold': reconciliation.billedLitres,
        'cashCollected': reconciliation.cashAmount,
        'cashDeclared': cashDeclared,
        'cashVariance': cashVariance,
        'closedBy': closedBy,
        'notes': notes,
        'reconciliationJson': jsonEncode(reconciliation.toMap()),
        'wasForced': forceClose,
      },
    );

    // 6. Audit log: Shift closed
    try {
      await _auditRepo.logAction(
        userId: _ownerId,
        targetTableName: 'shifts',
        recordId: shiftId,
        action: forceClose ? 'SHIFT_FORCE_CLOSE' : 'SHIFT_CLOSE',
        newValueJson:
            '{"litres": ${reconciliation.billedLitres}, "variance": ${reconciliation.varianceLitres}, "total": ${reconciliation.totalSalesAmount}}',
      );
    } catch (_) {}
  }

  // --- New Helper for Sync Enqueue ---
  Future<void> _enqueueSync({
    required SyncOperationType operationType,
    required String targetCollection,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final safeDocId = documentId.length >= 4
        ? documentId.substring(0, 4)
        : documentId;
    final opId = '${_generateId()}_$safeDocId';

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
      userId: Value(_ownerId), // Assuming userId = ownerId for now
      priority: const Value(1),
    );

    await _db.into(_db.syncQueue).insert(syncItem);
  }

  /// Calculate shift sales from nozzle readings and bills
  Future<ShiftReconciliation> calculateShiftSales(String shiftId) async {
    // 1. Get all nozzles linked to this shift
    final nozzlesList = await (_db.select(
      _db.nozzles,
    )..where((t) => t.linkedShiftId.equals(shiftId))).get();

    double totalNozzleLitres = 0;
    final nozzleBreakdown = <NozzleReconciliation>[];

    for (final nozzleEntity in nozzlesList) {
      // Calculate litres sold based on entity logic
      // Assuming closingReading is updated continuously during billing
      // Logic copied from Nozzle model: closing - opening
      final litresSold =
          nozzleEntity.closingReading - nozzleEntity.openingReading;
      totalNozzleLitres += litresSold;

      nozzleBreakdown.add(
        NozzleReconciliation(
          nozzleId: nozzleEntity.nozzleId,
          fuelTypeName: nozzleEntity.fuelTypeName,
          openingReading: nozzleEntity.openingReading,
          closingReading: nozzleEntity.closingReading,
          litresSold: litresSold,
          billedLitres: 0, // Simplified: Not tracking per-nozzle billing yet
          variance: 0,
        ),
      );
    }

    // 2. Get all bills for this shift
    final billsList = await (_db.select(
      _db.bills,
    )..where((t) => t.shiftId.equals(shiftId))).get();

    double totalBilledLitres = 0;
    double cashAmount = 0;
    double upiAmount = 0;
    double cardAmount = 0;
    double creditAmount = 0;

    for (final bill in billsList) {
      // Sum litres from bill items (fuel quantity)
      final items = jsonDecode(bill.itemsJson) as List<dynamic>;
      for (final item in items) {
        if (item is Map) {
          final qty = (item['qty'] as num?)?.toDouble() ?? 0;
          totalBilledLitres += qty;
        }
      }

      // Sum payments by type
      final paymentType = bill.paymentMode?.toLowerCase() ?? 'cash';
      final grandTotal = bill.grandTotal;

      switch (paymentType) {
        case 'cash':
          cashAmount += grandTotal;
          break;
        case 'upi':
        case 'online':
          upiAmount += grandTotal;
          break;
        case 'card':
          cardAmount += grandTotal;
          break;
        case 'credit':
          creditAmount += grandTotal;
          break;
        default:
          cashAmount += grandTotal; // Default to cash
      }
    }

    // 3. Calculate variance
    final varianceLitres = totalNozzleLitres - totalBilledLitres;

    // 4. Generate warnings
    final warnings = <String>[];
    if (varianceLitres.abs() > ShiftReconciliation.toleranceLitres) {
      warnings.add(
        'Variance of ${varianceLitres.toStringAsFixed(2)}L detected. Investigation required.',
      );
    }
    if (totalNozzleLitres == 0 && totalBilledLitres == 0) {
      warnings.add('No sales recorded in this shift.');
    }

    return ShiftReconciliation(
      nozzleLitres: totalNozzleLitres,
      billedLitres: totalBilledLitres,
      tankDeducted: totalBilledLitres,
      varianceLitres: varianceLitres,
      cashAmount: cashAmount,
      upiAmount: upiAmount,
      cardAmount: cardAmount,
      creditAmount: creditAmount,
      warnings: warnings,
      nozzleBreakdown: nozzleBreakdown,
    );
  }

  /// Calculate sales per staff member
  Future<List<StaffSalesSummary>> calculateStaffSales(String shiftId) async {
    // 1. Get all assignments
    // 1. Get all active staff assignments for this shift if needed for fallback
    // (Future implementation)

    // 2. Get all bills
    final bills = await (_db.select(
      _db.bills,
    )..where((t) => t.shiftId.equals(shiftId))).get();

    final summaryMap = <String, StaffSalesSummary>{}; // staffId -> Summary

    // Helper to get or create summary
    StaffSalesSummary getSummary(String staffId) {
      return summaryMap.putIfAbsent(
        staffId,
        () => StaffSalesSummary(
          staffId: staffId,
          totalLitres: 0,
          totalAmount: 0,
          cashCollected: 0,
          digitalCollected: 0,
        ),
      );
    }

    // 3. Attribute Bills
    for (final bill in bills) {
      String? staffId = bill.attendantId;

      // Fallback: If no attendantId, try to link via Nozzle items
      if (staffId == null) {
        // Logic to find staff from nozzle assignment at bill time
        // Simplified: Find ANY staff assigned to the nozzle of the bill items
        // This is an approximation if explicit attendantId is missing.
      }

      if (staffId != null) {
        final summary = getSummary(staffId);
        // Add bill totals
        // Parse items for litres
        double litres = 0;
        try {
          final items = jsonDecode(bill.itemsJson) as List;
          for (var item in items) {
            litres += (item['qty'] as num?)?.toDouble() ?? 0;
          }
        } catch (_) {}

        summary.totalLitres += litres;
        summary.totalAmount += bill.grandTotal;

        if (bill.paymentMode?.toLowerCase() == 'cash') {
          summary.cashCollected += bill.grandTotal;
        } else {
          summary.digitalCollected += bill.grandTotal;
        }
      }
    }

    return summaryMap.values.toList();
  }

  /// Create pending settlements for all staff in the shift
  Future<void> createStaffSettlements(String shiftId) async {
    final staffSales = await calculateStaffSales(shiftId);

    for (final sales in staffSales) {
      final settlementId = _generateId();
      await _db
          .into(_db.staffCashSettlements)
          .insert(
            StaffCashSettlementsCompanion(
              id: Value(settlementId),
              shiftId: Value(shiftId),
              staffId: Value(sales.staffId),
              expectedCash: Value(sales.cashCollected),
              actualCash: Value(0.0), // To be filled by user
              difference: Value(
                -sales.cashCollected,
              ), // Initial shortage = full amount
              status: Value('PENDING'),
              settledAt: Value(DateTime.now()),
            ),
          );
    }
  }

  /// Reset nozzles: Last Closing -> New Opening
  Future<void> _resetNozzlesForShift(String shiftId) async {
    final nozzlesList = await _db.select(_db.nozzles).get();

    for (final nozzle in nozzlesList) {
      // For new shift, opening = previous closing
      // If closing was 0 (fresh install), it stays 0
      final newOpening = nozzle.closingReading > 0
          ? nozzle.closingReading
          : nozzle.openingReading;

      await (_db.update(
        _db.nozzles,
      )..where((t) => t.nozzleId.equals(nozzle.nozzleId))).write(
        NozzlesCompanion(
          openingReading: Value(newOpening),
          closingReading: Value(newOpening), // Reset for new sales
          linkedShiftId: Value(shiftId),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Sync Queue: Nozzle Reset
      await _enqueueSync(
        operationType: SyncOperationType.update,
        targetCollection: 'nozzles',
        documentId: nozzle.nozzleId,
        payload: {
          'openingReading': newOpening,
          'closingReading': newOpening,
          'linkedShiftId': shiftId,
        },
      );
    }
  }

  /// Get shift history
  Stream<List<Shift>> getShiftHistory({int limit = 50}) {
    return (_db.select(_db.shifts)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startTime, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  /// Get shifts for a specific date range (for DSR report)
  Future<List<Shift>> getShiftsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final entities =
        await (_db.select(_db.shifts)
              ..where(
                (t) =>
                    t.startTime.isBiggerOrEqualValue(start) &
                    t.startTime.isSmallerThanValue(end),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startTime,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();
    return entities.map(_mapToDomain).toList();
  }

  /// Get shift by ID
  Future<Shift?> getShiftById(String shiftId) async {
    final entity = await (_db.select(
      _db.shifts,
    )..where((t) => t.shiftId.equals(shiftId))).getSingleOrNull();

    if (entity == null) return null;
    return _mapToDomain(entity);
  }

  // --- Helpers ---

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
    // Ideally use Uuid().v4() but adding package dependency might break.
    // If uuid package is available: import 'package:uuid/uuid.dart'; return const Uuid().v4();
  }

  Shift _mapToDomain(ShiftEntity entity) {
    // Parse Payment Breakup from reconciliation JSON if available
    // OR create from columns if we had them.
    // We only have cashCollected.
    // However, the domain Shift object expects PaymentBreakup.
    // We can try to parse it from reconciliationJson.
    PaymentBreakup breakup = const PaymentBreakup();
    if (entity.reconciliationJson != null) {
      try {
        final map = jsonDecode(entity.reconciliationJson!);
        if (map is Map<String, dynamic>) {
          // ShiftReconciliation map contains cashAmount, upiAmount etc
          breakup = PaymentBreakup(
            cash: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
            upi: (map['upiAmount'] as num?)?.toDouble() ?? 0.0,
            card: (map['cardAmount'] as num?)?.toDouble() ?? 0.0,
            credit: (map['creditAmount'] as num?)?.toDouble() ?? 0.0,
          );
        }
      } catch (_) {}
    }

    return Shift(
      shiftId: entity.shiftId,
      shiftName: entity.shiftName,
      startTime: entity.startTime,
      endTime: entity.endTime,
      assignedEmployeeIds: _parseStringList(entity.assignedEmployeeIds),
      totalSaleAmount: entity.totalSaleAmount,
      totalLitresSold: entity.totalLitresSold,
      paymentBreakup: breakup,
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == entity.status,
        orElse: () => ShiftStatus.open,
      ),
      ownerId: entity.ownerId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      closedBy: entity.closedBy,
      notes: entity.notes,
    );
  }

  List<String> _parseStringList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}

/// Exception thrown when shift reconciliation fails
class ShiftReconciliationException implements Exception {
  final String message;
  final ShiftReconciliation reconciliation;

  ShiftReconciliationException(this.message, {required this.reconciliation});

  @override
  String toString() => 'ShiftReconciliationException: $message';
}

/// Exception thrown when cash declaration doesn't match expected
/// Gap #6 FIX: Ensures accountability for cash handling
class CashDeclarationException implements Exception {
  final String message;
  final double declaredAmount;
  final double expectedAmount;
  final double variance;

  CashDeclarationException(
    this.message, {
    required this.declaredAmount,
    required this.expectedAmount,
    required this.variance,
  });

  @override
  String toString() =>
      'CashDeclarationException: $message (Declared: ₹$declaredAmount, Expected: ₹$expectedAmount, Variance: ₹$variance)';
}

/// DTO for Staff Sales Calculation
class StaffSalesSummary {
  final String staffId;
  double totalLitres;
  double totalAmount;
  double cashCollected;
  double digitalCollected;

  StaffSalesSummary({
    required this.staffId,
    required this.totalLitres,
    required this.totalAmount,
    required this.cashCollected,
    required this.digitalCollected,
  });
}
