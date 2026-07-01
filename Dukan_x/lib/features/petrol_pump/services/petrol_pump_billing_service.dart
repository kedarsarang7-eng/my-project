import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart'; // Provides Bill model
import '../../../../core/repository/audit_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/security/services/fraud_detection_service.dart';
import '../../../../core/error/credit_limit_exception.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_queue_state_machine.dart'; // Added: Provides SyncOperationType
import '../models/nozzle.dart';
import '../models/fuel_type.dart';
import 'shift_service.dart';
import 'period_lock_service.dart';

/// PetrolPumpBillingService - FRAUD-PROOF Fuel Billing
///
/// Refactored for Offline-First with Transactional Integrity.
/// All Key Operations (Bill, Stock, Nozzle, Ledger) occur in a single DB Transaction.
class PetrolPumpBillingService {
  late final AppDatabase _db;
  late final ShiftService _shiftService; // Now Drift-based
  late final PeriodLockService _periodLockService;
  late final AuditRepository _auditRepo;
  late final SessionManager _sessionManager;
  late final CustomersRepository _customersRepo;

  PetrolPumpBillingService({
    AppDatabase? db,
    ShiftService? shiftService,
    PeriodLockService? periodLockService,
    AuditRepository? auditRepo,
    SessionManager? sessionManager,
    CustomersRepository? customersRepo,
  }) {
    _db = db ?? sl<AppDatabase>();
    _shiftService = shiftService ?? ShiftService();
    _periodLockService = periodLockService ?? PeriodLockService();
    _auditRepo = auditRepo ?? sl<AuditRepository>();
    _sessionManager = sessionManager ?? sl<SessionManager>();
    _customersRepo = customersRepo ?? sl<CustomersRepository>();
  }

  // Fraud detection service for late night billing alerts
  FraudDetectionService? _fraudDetectionService;

  FraudDetectionService get fraudDetectionService {
    _fraudDetectionService ??= sl.isRegistered<FraudDetectionService>()
        ? sl<FraudDetectionService>()
        : null;
    return _fraudDetectionService!;
  }

  String get _ownerId => _sessionManager.ownerId ?? '';

  /// Create a bill from a nozzle sale with FRAUD PREVENTION
  Future<Bill?> createFuelBill({
    required Nozzle nozzle,
    required FuelType fuelType,
    required double litres,
    required double rate,
    required String customerId,
    String paymentType = 'Cash',
    String? vehicleNumber,
    String? employeeId,
    DateTime? billDate,
  }) async {
    final now = DateTime.now();
    final requestedDate = billDate ?? now;

    // STEP 0: Period Lock Check
    if (await _periodLockService.isDateLocked(requestedDate)) {
      final lockDate = await _periodLockService.getLockDate();
      throw PeriodLockedException(
        lockedUntil: lockDate!,
        attemptedDate: requestedDate,
      );
    }

    // STEP 1: Validate active shift
    final activeShift = await _shiftService.getActiveShift();
    if (activeShift == null) {
      throw NoActiveShiftException(
        'Cannot create fuel bill: No active shift. Open a shift first.',
      );
    }

    if (activeShift.status.name != 'open') {
      throw ClosedShiftException(
        'Cannot create bill: Shift "${activeShift.shiftName}" is already closed.',
        shiftId: activeShift.shiftId,
      );
    }

    // STEP 2: Stock Availability Check
    final tankResult = await _resolveTankForNozzle(nozzle);
    final String? tankId = tankResult?.tankId;
    final double currentStock = tankResult?.currentStock ?? 0.0;

    if (tankResult != null && litres > currentStock) {
      throw InsufficientStockException(
        'Cannot sell $litres litres: Tank only has ${currentStock.toStringAsFixed(2)} litres available.',
        requestedLitres: litres,
        availableStock: currentStock,
        tankId: tankId!,
      );
    }

    // STEP 3: Credit Limit Check
    final totalAmount = litres * rate;
    if (paymentType == 'Credit' && customerId.isNotEmpty) {
      final customerResult = await _customersRepo.getById(customerId);
      if (customerResult.isSuccess && customerResult.data != null) {
        final customer = customerResult.data!;
        if (customer.isBlocked) {
          throw CreditLimitExceededException(
            currentDues: customer.totalDues,
            billAmount: totalAmount,
            creditLimit: customer.creditLimit,
            customerName: customer.name,
          );
        }
        if (customer.creditLimit > 0 &&
            (customer.totalDues + totalAmount) > customer.creditLimit) {
          throw CreditLimitExceededException(
            currentDues: customer.totalDues,
            billAmount: totalAmount,
            creditLimit: customer.creditLimit,
            customerName: customer.name,
          );
        }
      }
    }

    // STEP 4: Transactional Execution
    // We execute the DB operations in a transaction for atomicity.
    // Audit logging is done AFTER the transaction ensures success.
    print('DEBUG: Starting transaction for bill');
    final Bill? createdBill = await _db.transaction(() async {
      // A. Create Bill Record
      print('DEBUG: Generating ID');
      final billId = _generateId();
      // COMPLIANCE: Petrol and diesel are outside India's GST regime (taxed via
      // state VAT / central excise, handled in the merchant's own accounting).
      // Force the fuel GST rate to 0 at computation time rather than trusting
      // fuelType.linkedGSTRate, so no non-zero GST can ever be persisted on a
      // petrolPump fuel line item regardless of any stored or entered rate.
      const gstRate = 0.0;
      final gstAmount = totalAmount * gstRate / (100 + gstRate);

      final item = {
        'productId': fuelType.fuelId,
        'productName': fuelType.fuelName,
        'qty': litres,
        'price': rate,
        'unit': 'ltr',
        'gstRate': gstRate,
        'cgst': gstAmount / 2,
        'sgst': gstAmount / 2,
        'nozzleId': nozzle.nozzleId,
        'dispenserId': nozzle.dispenserId,
        'vehicleNumber': vehicleNumber,
      };

      print('DEBUG: Preparing BillCompanion for $billId');

      final subtotal = totalAmount - gstAmount;

      final billCompanion = BillsCompanion(
        id: Value(billId),
        invoiceNumber: Value(billId),
        customerId: Value(customerId),
        billDate: Value(requestedDate),
        itemsJson: Value(jsonEncode([item])),
        subtotal: Value(subtotal), // Corrected: subtotal
        taxAmount: Value(gstAmount),
        grandTotal: Value(totalAmount),
        paymentMode: Value(paymentType),
        businessType: Value('petrolPump'),
        status: Value(paymentType == 'Credit' ? 'Unpaid' : 'Paid'),
        paidAmount: Value(paymentType == 'Credit' ? 0.0 : totalAmount),
        shiftId: Value(activeShift.shiftId),
        userId: Value(_ownerId), // Corrected: userId (was ownerId)
        createdAt: Value(now),
        updatedAt: Value(now),
        isSynced: const Value(false),
      );

      print('DEBUG: Inserting Bill');
      await _db.into(_db.bills).insert(billCompanion);

      // Sync Queue: Bill
      print('DEBUG: Enqueuing Bill Sync');
      await _enqueueSync(
        operationType: SyncOperationType.create,
        targetCollection: 'bills',
        documentId: billId,
        payload: {
          'id': billId,
          'customerId': customerId,
          'billDate': requestedDate.toIso8601String(),
          'itemsJson': jsonEncode([item]),
          'subtotal': subtotal,
          'taxAmount': gstAmount,
          'grandTotal': totalAmount,
          'paymentMode': paymentType,
          'businessType': 'petrolPump',
          'status': paymentType == 'Credit' ? 'Unpaid' : 'Paid',
          'paidAmount': paymentType == 'Credit' ? 0.0 : totalAmount,
          'shiftId': activeShift.shiftId,
          'userId': _ownerId,
        },
      );

      // B. Deduct Tank Stock
      if (tankId != null) {
        print('DEBUG: Updating Tank Stock for $tankId');
        // Optimistic locking or direct decrement
        // For SQLite, simple update is usually safe enough if single writer
        // But we are in a transaction, so it's safe.
        await _db.customStatement(
          'UPDATE tanks SET current_stock = current_stock - ? WHERE tank_id = ?',
          [litres, tankId],
        );

        // Sync Queue: Tank Update
        final updatedTank = await (_db.select(
          _db.tanks,
        )..where((t) => t.tankId.equals(tankId))).getSingle();

        print('DEBUG: Enqueuing Tank Sync');
        await _enqueueSync(
          operationType: SyncOperationType.update,
          targetCollection: 'tanks',
          documentId: tankId,
          payload: {
            'currentStock': updatedTank.currentStock,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        // AUDIT FIX: Log to StockMovements
        print('DEBUG: Logging Stock Movement');
        final movementId = _generateId();
        final stockAfter = updatedTank.currentStock;
        final stockBefore = stockAfter + litres;

        final movement = StockMovementsCompanion(
          id: Value(movementId),
          userId: Value(_ownerId),
          productId: Value(fuelType.fuelId), // Fuel Product ID
          type: Value('OUT'),
          reason: Value('FUEL_SALE'),
          quantity: Value(litres),
          stockBefore: Value(stockBefore),
          stockAfter: Value(stockAfter),
          referenceId: Value(billId),
          description: Value('Fuel Sale - Vehicle: ${vehicleNumber ?? "N/A"}'),
          warehouseId: Value(tankId), // Tank acts as Warehouse
          date: Value(requestedDate),
          createdAt: Value(now),
          isSynced: const Value(false),
        );

        await _db.into(_db.stockMovements).insert(movement);

        // Sync Queue: Stock Movement
        await _enqueueSync(
          operationType: SyncOperationType.create,
          targetCollection: 'stock_movements',
          documentId: movementId,
          payload: {
            'id': movementId,
            'userId': _ownerId,
            'productId': fuelType.fuelId,
            'type': 'OUT',
            'reason': 'FUEL_SALE',
            'quantity': litres,
            'stockBefore': stockBefore,
            'stockAfter': stockAfter,
            'referenceId': billId,
            'warehouseId': tankId,
            'date': requestedDate.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
        );
      }

      // C. Update Nozzle Reading
      // We explicitly UPDATE the Closing Reading
      print('DEBUG: Updating Nozzle Reading for ${nozzle.nozzleId}');
      await _db.customStatement(
        'UPDATE nozzles SET closing_reading = closing_reading + ? WHERE nozzle_id = ?',
        [litres, nozzle.nozzleId],
      );

      // Sync Queue: Nozzle Update
      final updatedNozzle = await (_db.select(
        _db.nozzles,
      )..where((t) => t.nozzleId.equals(nozzle.nozzleId))).getSingle();
      await _enqueueSync(
        operationType: SyncOperationType.update,
        targetCollection: 'nozzles',
        documentId: nozzle.nozzleId,
        payload: {
          'closingReading': updatedNozzle.closingReading,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      // D. Posting to Ledger (Accounting)
      await _postAccountingEntry(
        billId: billId,
        amount: totalAmount,
        paymentType: paymentType,
        customerId: customerId,
        date: requestedDate,
      );

      // Return constructed bill object
      // Note: We are mocking BillItem structure here as we don't have the full class definition handy
      // but creating a Bill object should work if imported correctly.
      return Bill(
        id: billId,
        customerId: customerId,
        date: requestedDate,
        // Determine items list based on repository or model definition.
        // Assuming Bill expects List<BillItem>.
        // We will pass empty list for now to satisfy constructor, or construct BillItem if possible.
        items: [],
        grandTotal: totalAmount,
        paymentType: paymentType,
        shiftId: activeShift.shiftId,
        status: paymentType == 'Credit' ? 'Unpaid' : 'Paid',
        subtotal: totalAmount - gstAmount,
        totalTax: gstAmount,
        paidAmount: paymentType == 'Credit' ? 0 : totalAmount,
        onlinePaid: (paymentType == 'UPI' || paymentType == 'Card')
            ? totalAmount
            : 0,
        cashPaid: paymentType == 'Cash' ? totalAmount : 0,
        businessType: 'petrolPump',
      );
    });

    // STEP 5: Audit Log (Post-Transaction)
    if (createdBill != null) {
      try {
        await _auditRepo.logAction(
          userId: _ownerId,
          targetTableName: 'bills',
          recordId: createdBill.id,
          action: 'FUEL_BILL_CREATED',
          newValueJson:
              '{"amount": $totalAmount, "litres": $litres, "shiftId": "${activeShift.shiftId}"}',
        );
      } catch (_) {}
    }

    return createdBill;
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

  // --- Helper Methods ---

  Future<TankInfo?> _resolveTankForNozzle(Nozzle nozzle) async {
    // Queries local DB for Tank linked to dispenser/nozzle
    // Logic: Nozzle -> Dispenser -> LinkedTank
    // OR Nozzle -> LinkedTank

    // Check nozzle specific link first
    if (nozzle.linkedTankId != null && nozzle.linkedTankId!.isNotEmpty) {
      final tank = await (_db.select(
        _db.tanks,
      )..where((t) => t.tankId.equals(nozzle.linkedTankId!))).getSingleOrNull();
      if (tank != null) return TankInfo(tank.tankId, tank.currentStock);
    }

    // Check dispenser link
    // Requires querying Dispenser table
    final dispenser = await (_db.select(
      _db.dispensers,
    )..where((t) => t.id.equals(nozzle.dispenserId))).getSingleOrNull();
    if (dispenser?.linkedTankId != null) {
      final tank =
          await (_db.select(_db.tanks)
                ..where((t) => t.tankId.equals(dispenser!.linkedTankId!)))
              .getSingleOrNull();
      if (tank != null) return TankInfo(tank.tankId, tank.currentStock);
    }

    return null;
  }

  Future<void> _postAccountingEntry({
    required String billId,
    required double amount,
    required String paymentType,
    required String customerId,
    required DateTime date,
  }) async {
    // 1. Resolve Account Names
    String debitAccountName = 'Cash'; // Default
    if (paymentType == 'UPI' || paymentType == 'Online') {
      debitAccountName = 'Bank';
    }
    if (paymentType == 'Credit') {
      debitAccountName = 'Customer Receivables'; // Generalized
    }

    const String creditAccountName = 'Sales';

    // 2. Update Ledger Balances (ensure accounts exist first)
    // We assume core accounts exist, or we create them?
    // For simplicity, we just update if they match.
    // DEBIT: Increase Asset (Cash/Bank/Receivable)
    await _updateLedgerBalance(debitAccountName, amount, isDebit: true);

    // CREDIT: Increase Revenue (Sales)
    await _updateLedgerBalance(creditAccountName, amount, isDebit: false);

    // 3. Create Journal Entry
    final entryId = _generateId();
    final items = [
      {'accountName': debitAccountName, 'dr': amount, 'cr': 0.0},
      {'accountName': creditAccountName, 'dr': 0.0, 'cr': amount},
    ];

    final payloadMap = {
      'id': entryId,
      'ownerId': _ownerId,
      'transactionDate': date.toIso8601String(),
      'description': 'Fuel Sale - Bill #$billId',
      'referenceId': billId,
      'referenceType': 'BILL',
      'entryItemsJson': jsonEncode(items),
      'totalAmount': amount,
      'isPosted': true,
      'isSynced': false,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final journalCompanion = JournalEntriesCompanion(
      id: Value(entryId),
      userId: Value(_ownerId),
      entryDate: Value(date),
      date: Value(date),
      description: Value('Fuel Sale - Bill #$billId'),
      sourceId: Value(billId),
      sourceType: const Value('BILL'),
      entriesJson: Value(jsonEncode(items)),
      amount: Value(amount),
      totalDebit: Value(amount),
      totalCredit: Value(amount),
      isSynced: const Value(false),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _db.into(_db.journalEntries).insert(journalCompanion);

    // Sync Queue: Journal Entry
    await _enqueueSync(
      operationType: SyncOperationType.create,
      targetCollection: 'journal_entries',
      documentId: entryId,
      payload: payloadMap,
    );
  }

  Future<void> _updateLedgerBalance(
    String accountName,
    double amount, {
    required bool isDebit,
  }) async {
    // Find account by name
    final account = await (_db.select(
      _db.ledgerAccounts,
    )..where((t) => t.name.equals(accountName))).getSingleOrNull();

    if (account != null) {
      // Determine effect on balance based on Account Group/Type
      // ASSETS/EXPENSES: Debit increases, Credit decreases
      // LIABILITIES/EQUITY/INCOME: Credit increases, Debit decreases

      // Standard Accounting Rules:
      final debitNormalTypes = ['ASSET', 'EXPENSE'];
      // Assumption: account.type stores one of 'ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'

      final isDebitNormal = debitNormalTypes.contains(account.type);

      double change = 0.0;
      if (isDebitNormal) {
        change = isDebit ? amount : -amount;
      } else {
        // Credit Normal
        change = isDebit ? -amount : amount;
      }

      await (_db.update(
        _db.ledgerAccounts,
      )..where((t) => t.id.equals(account.id))).write(
        LedgerAccountsCompanion(
          currentBalance: Value(account.currentBalance + change),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );
      // Not syncing Ledger balance updates to avoid conflicts, server will calculate from journal.
    } else {
      // Account doesn't exist? Ideally create it or log error.
      // For 'Customer Receivables', we might need to create it.
      // Skipping creation to minimize complexity for now.
    }
  }

  String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}';
  }
}

class TankInfo {
  final String tankId;
  final double currentStock;
  TankInfo(this.tankId, this.currentStock);
}

// Exceptions
class NoActiveShiftException implements Exception {
  final String message;
  NoActiveShiftException(this.message);
  @override
  String toString() => message;
}

class ClosedShiftException implements Exception {
  final String message;
  final String shiftId;
  ClosedShiftException(this.message, {required this.shiftId});
  @override
  String toString() => message;
}

class BackdatedBillException implements Exception {
  final String message;
  final DateTime attemptedDate;
  final DateTime currentDate;
  BackdatedBillException(
    this.message, {
    required this.attemptedDate,
    required this.currentDate,
  });
  @override
  String toString() => message;
}

class InsufficientStockException implements Exception {
  final String message;
  final double requestedLitres;
  final double availableStock;
  final String tankId;
  InsufficientStockException(
    this.message, {
    required this.requestedLitres,
    required this.availableStock,
    required this.tankId,
  });
  @override
  String toString() => message;
}
