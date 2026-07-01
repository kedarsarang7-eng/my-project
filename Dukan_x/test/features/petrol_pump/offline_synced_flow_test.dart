import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/audit_repository.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/repository/customers_repository.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';
import 'package:dukanx/features/petrol_pump/models/nozzle.dart';
import 'package:dukanx/features/petrol_pump/services/period_lock_service.dart';
import 'package:dukanx/features/petrol_pump/services/petrol_pump_billing_service.dart';
import 'package:dukanx/features/petrol_pump/services/shift_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockAuditRepository extends Mock implements AuditRepository {
  @override
  Future<RepositoryResult<void>> logAction({
    required String userId,
    required String targetTableName,
    required String recordId,
    required String action,
    String? newValueJson,
    String? oldValueJson,
    String? deviceId,
    String? appVersion,
  }) async {
    return Future.value(const RepositoryResult.success(null));
  }
}

class MockSessionManager extends Mock implements SessionManager {
  @override
  String? get ownerId => 'test_owner_1';
}

class MockCustomersRepository extends Mock implements CustomersRepository {}

class MockPeriodLockService extends Mock implements PeriodLockService {
  @override
  Future<bool> isDateLocked(DateTime date) async => false;
}

void main() {
  late AppDatabase db;
  late ShiftService shiftService;
  late PetrolPumpBillingService billingService;
  late MockAuditRepository mockAuditRepo;
  late MockSessionManager mockSessionManager;
  late MockPeriodLockService mockPeriodLockService; // Declare

  setUp(() async {
    // In-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());

    // Register standard mocks
    mockAuditRepo = MockAuditRepository();
    mockSessionManager = MockSessionManager();
    mockPeriodLockService = MockPeriodLockService();

    // Initialize services with local DB
    shiftService = ShiftService(
      db: db,
      auditRepo: mockAuditRepo,
      sessionManager: mockSessionManager,
    );

    billingService = PetrolPumpBillingService(
      db: db,
      shiftService: shiftService,
      periodLockService: mockPeriodLockService, // Use variable
      auditRepo: mockAuditRepo,
      sessionManager: mockSessionManager,
      customersRepo: MockCustomersRepository(),
    );

    // Seed Data: FuelType, Tank, Dispenser, Nozzle, Ledger Accounts
    await _seedData(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Offline Flow: Open Shift -> Create Bill -> Sync Queue Verification',
    () async {
      // 1. Open Shift
      final shift = await shiftService.openShift('Morning Shift', ['emp1']);
      expect(shift.status.name, 'open');

      // Verify Sync Queue for Shift Create
      var syncItems = await db.select(db.syncQueue).get();
      expect(syncItems.length, 2); // Shift + Nozzle Reset
      final shiftSync = syncItems.firstWhere(
        (i) => i.targetCollection == 'shifts',
      );
      expect(shiftSync.operationType, 'create');
      expect(shiftSync.documentId, shift.shiftId);

      // 2. Create Bill
      final nozzle = Nozzle(
        nozzleId: 'n1',
        dispenserId: 'd1',
        fuelTypeId: 'petrol',
        fuelTypeName: 'Petrol',
        openingReading: 1000.0,
        closingReading: 1000.0,
        linkedTankId: 't1',
        ownerId: 'test_owner_1',
      );

      final fuelType = FuelType(
        fuelId: 'petrol',
        fuelName: 'Petrol',
        currentRatePerLitre: 100.0,
        linkedGSTRate: 18.0,
        ownerId: 'test_owner_1',
      );

      final bill = await billingService.createFuelBill(
        nozzle: nozzle,
        fuelType: fuelType,
        litres: 10.0,
        rate: 100.0,
        customerId: 'cust1',
        paymentType: 'Cash',
      );

      expect(bill, isNotNull);
      expect(bill!.grandTotal, 1000.0);

      // Verify Data Consistency
      // A. Stock Deducted
      final tank = await (db.select(
        db.tanks,
      )..where((t) => t.tankId.equals('t1'))).getSingle();
      expect(tank.currentStock, 4990.0); // 5000 - 10

      // B. Nozzle Reading Updated
      final updatedNozzle = await (db.select(
        db.nozzles,
      )..where((t) => t.nozzleId.equals('n1'))).getSingle();
      expect(updatedNozzle.closingReading, 1010.0); // 1000 + 10

      // C. Journal Entry Created
      final journals = await db.select(db.journalEntries).get();
      expect(journals.isNotEmpty, isTrue);
      expect(journals.first.amount, 1000.0);

      // Verify Ledger Updates
      final cashAcc = await (db.select(
        db.ledgerAccounts,
      )..where((t) => t.id.equals('cash_acc'))).getSingle();
      final salesAcc = await (db.select(
        db.ledgerAccounts,
      )..where((t) => t.id.equals('sales_acc'))).getSingle();

      // Cash (Asset) Debit (+1000) -> 0 (init) + 1000 = 1000
      // Sales (Income) Credit (+1000) -> 0 (init) + 1000 = 1000
      expect(cashAcc.currentBalance, 1000.0);
      expect(salesAcc.currentBalance, 1000.0);

      // Verify Sync Queue Population
      // Should have: Shift(1) + NozzleReset(1) + Bill(1) + Tank(1) + Nozzle(1) + StockMovement(1) + Journal(1) = 7
      syncItems = await db.select(db.syncQueue).get();
      expect(syncItems.length, 7);

      // Check specific types
      final billSync = syncItems.firstWhere(
        (i) => i.targetCollection == 'bills',
      );
      expect(billSync.operationType, 'create');

      final tankSync = syncItems.firstWhere(
        (i) => i.targetCollection == 'tanks',
      );
      expect(tankSync.operationType, 'update');

      final nozzleSync = syncItems.firstWhere(
        (i) => i.targetCollection == 'nozzles',
      );
      expect(nozzleSync.operationType, 'update');

      final stockSync = syncItems.firstWhere(
        (i) => i.targetCollection == 'stock_movements',
      );
      expect(stockSync.operationType, 'create');

      // 3. Close Shift
      await shiftService.closeShift(
        shift.shiftId,
        closedBy: 'emp1',
        cashDeclared: 1000.0,
      );

      // Verify Sync Queue for Shift Update
      syncItems = await db.select(db.syncQueue).get();
      // +1 for Shift Update (Close). Nozzle Reset does NOT happen on close.
      // Total should be 7 + 1 = 8
      expect(syncItems.length, 8);

      final shiftCloseSync = syncItems.where(
        (i) => i.targetCollection == 'shifts' && i.operationType == 'update',
      );
      expect(shiftCloseSync, isNotEmpty);
    },
  );
}

Future<void> _seedData(AppDatabase db) async {
  // Tanks
  await db
      .into(db.tanks)
      .insert(
        TanksCompanion.insert(
          tankId: 't1',
          ownerId: 'test_owner_1',
          name: 'Tank 1',
          fuelTypeId: 'petrol',
          capacity: 10000,
          currentStock: 5000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  // Dispensers
  await db
      .into(db.dispensers)
      .insert(
        DispensersCompanion.insert(
          id: 'd1',
          ownerId: 'test_owner_1',
          name: 'Dispenser 1',
          linkedTankId: Value('t1'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  // Nozzles
  await db
      .into(db.nozzles)
      .insert(
        NozzlesCompanion.insert(
          nozzleId: 'n1',
          ownerId: 'test_owner_1',
          dispenserId: 'd1',
          name: 'Nozzle 1',
          fuelTypeId: 'petrol',
          fuelTypeName: 'Petrol',
          openingReading: const Value(1000),
          closingReading: const Value(1000),
          linkedTankId: Value('t1'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  // Ledger Accounts (Cash, Sales)
  await db
      .into(db.ledgerAccounts)
      .insert(
        LedgerAccountsCompanion.insert(
          id: 'cash_acc',
          userId: 'test_owner_1',
          name: 'Cash',
          type: 'ASSET',
          accountGroup: Value('ASSETS'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

  await db
      .into(db.ledgerAccounts)
      .insert(
        LedgerAccountsCompanion.insert(
          id: 'sales_acc',
          userId: 'test_owner_1',
          name: 'Sales',
          type: 'INCOME',
          accountGroup: Value('REVENUE'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
}
