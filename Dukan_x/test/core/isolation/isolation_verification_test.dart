import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/repository/bills_repository.dart';
import 'package:dukanx/core/repository/shop_repository.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/sync/sync_queue_state_machine.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

// Mocks
class MockSyncManager extends Mock implements SyncManager {
  @override
  Future<String> enqueue(SyncQueueItem? item) async {
    return 'mock-op-id';
  }
}

class MockErrorHandler extends Mock implements ErrorHandler {
  @override
  Future<RepositoryResult<T>> runSafe<T>(
    Future<T> Function() block,
    String operation,
  ) async {
    final result = await block();
    return RepositoryResult.success(result);
  }
}

void main() {
  late AppDatabase database;
  late BillsRepository billsRepo;
  late ShopRepository shopRepo;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final mockSyncManager = MockSyncManager();
    final mockErrorHandler = MockErrorHandler();

    billsRepo = BillsRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
    );
    shopRepo = ShopRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Hard Business Type Isolation Verification', () {
    test('Grocery Shop CANNOT use Prescription', () {
      final groceryType = 'grocery';
      final capability = BusinessCapability.usePrescription;
      expect(FeatureResolver.canAccess(groceryType, capability), isFalse);
      try {
        FeatureResolver.enforceAccess(groceryType, capability);
        fail('Should have thrown SecurityException');
      } catch (e) {
        expect(e, isA<SecurityException>());
      }
    });

    test('Grocery Shop CANNOT use IMEI', () {
      expect(
        FeatureResolver.canAccess('grocery', BusinessCapability.useIMEI),
        isFalse,
      );
    });

    test('Pharmacy Shop CAN use Prescription but NOT IMEI', () {
      final pharmacy = 'pharmacy';
      expect(
        FeatureResolver.canAccess(pharmacy, BusinessCapability.usePrescription),
        isTrue,
      );
      expect(
        FeatureResolver.canAccess(pharmacy, BusinessCapability.useIMEI),
        isFalse,
      );
    });

    test('Electronics Shop CAN use IMEI but NOT Prescription', () {
      final electronics = 'electronics';
      expect(
        FeatureResolver.canAccess(electronics, BusinessCapability.useIMEI),
        isTrue,
      );
      expect(
        FeatureResolver.canAccess(
          electronics,
          BusinessCapability.usePrescription,
        ),
        isFalse,
      );
    });

    test('Petrol Pump CAN use Fuel features', () {
      final pump = 'petrolPump';
      expect(
        FeatureResolver.canAccess(pump, BusinessCapability.useFuelManagement),
        isTrue,
      );
      expect(
        FeatureResolver.canAccess(pump, BusinessCapability.useVehicleDetails),
        isTrue,
      );
    });
  });

  group('Bill Repository Enforcement Integration', () {
    test('Create Bill REJECTS forbidden fields for Grocery', () async {
      // 1. Setup Shop as Grocery
      final userId = 'user_grocery';
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              businessType: const Value('grocery'),
              name: 'Grocery Store',
              ownerId: userId,
              ownerName: const Value('Owner'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Create Bill with Prescription (Forbidden)
      final bill = Bill(
        id: 'bill1',
        customerId: 'cust1',
        ownerId: userId,
        invoiceNumber: 'INV1',
        date: DateTime.now(),
        businessType: 'grocery',
        prescriptionId: 'Rx123', // ILLEGAL FIELD
        items: [],
      );

      // 3. functional test
      expect(
        () async => await billsRepo.createBill(bill),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Create Bill REJECTS forbidden fields for Restaurant', () async {
      // 1. Setup Shop as Restaurant
      final userId = 'user_rest';
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              businessType: const Value('restaurant'),
              name: 'Restaurant',
              ownerId: userId,
              ownerName: const Value('Chef'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Create Bill with IMEI (Forbidden)
      final bill = Bill(
        id: 'bill2',
        customerId: 'cust2',
        ownerId: userId,
        invoiceNumber: 'INV2',
        date: DateTime.now(),
        businessType: 'restaurant',
        items: [
          BillItem(
            productId: 'item1',
            productName: 'Food',
            qty: 1,
            price: 100,
            serialNo: 'IMEI123', // ILLEGAL FIELD
          ),
        ],
      );

      // 3. functional test
      expect(
        () async => await billsRepo.createBill(bill),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Create Bill ALLOWS valid fields for Pharmacy', () async {
      // 1. Setup Shop as Pharmacy
      final userId = 'user_pharma';
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              businessType: const Value('pharmacy'),
              name: 'Med Shop',
              ownerId: userId,
              ownerName: const Value('Chemist'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // 2. Create Bill with Prescription (Allowed)
      final bill = Bill(
        id: 'bill3',
        customerId: 'cust3',
        ownerId: userId,
        invoiceNumber: 'INV3',
        date: DateTime.now(),
        businessType: 'pharmacy',
        prescriptionId: 'RxValid', // VALID FIELD
        items: [],
      );

      // 3. functional test - Should NOT throw SecurityException
      // Might fail on other validations (like empty items) but NOT SecurityException
      try {
        await billsRepo.createBill(bill);
      } catch (e) {
        // We only care if it throws SecurityException (or generic Exception with Security msg)
        if (e is SecurityException ||
            e.toString().contains('Security Violation')) {
          fail('Should verify pharmacy can use prescription');
        }
      }
    });

    test('Business Type Lock: Cannot change type if data exists', () async {
      final userId = 'user_lockcheck';
      // 1. Create Shop
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              name: 'Lock Check Store',
              ownerId: userId,
              businessType: const Value('grocery'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // await shopRepo.saveBusinessType(userId, 'grocery'); // Already set by insert

      // 2. Create a Bill (Data exists)
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'b1',
              userId: userId,
              invoiceNumber: 'INV1',
              billDate: DateTime.now(),
              itemsJson: '[]',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              businessType: const Value('grocery'),
            ),
          );

      // 3. Try to change type to pharmacy
      expect(
        () async => await shopRepo.saveBusinessType(userId, 'pharmacy'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'msg',
            contains('Business Type is LOCKED'),
          ),
        ),
      );
    });

    test('Business Type Lock: Can change type if NO data exists', () async {
      final userId = 'user_fresh';
      // 1. Create Shop
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              name: 'Fresh Store',
              ownerId: userId,
              businessType: const Value('grocery'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // await shopRepo.saveBusinessType(userId, 'grocery'); // Already set by insert

      // 2. CHANGE OK (No bills/expenses)
      await shopRepo.saveBusinessType(userId, 'pharmacy');

      final shop = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(userId))).getSingle();
      expect(shop.businessType, 'pharmacy');
    });
  });
}
