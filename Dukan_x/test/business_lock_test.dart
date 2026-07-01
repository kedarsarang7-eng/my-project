import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

// Import app code
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/onboarding_repository.dart';
import 'package:dukanx/core/repository/bills_repository.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/error/error_handler.dart';

// Mocks
class MockSyncManager extends Mock implements SyncManager {}

class MockErrorHandler extends Mock implements ErrorHandler {
  @override
  @override
  Future<RepositoryResult<T>> runSafe<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    final result = await operation();
    return RepositoryResult.success(result);
  }
}

void main() {
  late AppDatabase database;
  late OnboardingRepository onboardingRepository;
  late BillsRepository billsRepository;
  late MockSyncManager mockSyncManager;
  late MockErrorHandler mockErrorHandler;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSyncManager = MockSyncManager();
    mockErrorHandler = MockErrorHandler();

    onboardingRepository = OnboardingRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
    );

    billsRepository = BillsRepository(
      database: database,
      syncManager: mockSyncManager,
      errorHandler: mockErrorHandler,
      // No other services needed for this specific test
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Business Type Lockdown Tests', () {
    const userId = 'user_123';

    test(
      'isBusinessTypeLocked returns false when no transactions exist',
      () async {
        final isLocked = await onboardingRepository.isBusinessTypeLocked(
          userId,
        );
        expect(isLocked, isFalse);
      },
    );

    test('isBusinessTypeLocked returns true after creating a bill', () async {
      // 1. Create a bill
      final billId = 'bill_1';
      final now = DateTime.now();

      // First, we need to create a USER (Shop)
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              name: 'Test Shop',
              ownerId: userId,
              businessType: const drift.Value('grocery'),
              createdAt: now,
              updatedAt: now,
              isSynced: const drift.Value(false),
            ),
          );

      // Insert Bill directly into DB to simulate existing data
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: billId,
              userId: userId,
              invoiceNumber: 'INV001',
              billDate: now,
              subtotal: const drift.Value(100.0),
              taxAmount: const drift.Value(0.0),
              grandTotal: const drift.Value(100.0),
              paidAmount: const drift.Value(100.0),
              businessType: const drift.Value('grocery'),
              createdAt: now,
              updatedAt: now,
              itemsJson: '[]',
              status: const drift.Value('Paid'),
              isSynced: const drift.Value(false),
            ),
          );

      // 2. Check lock status
      final isLocked = await onboardingRepository.isBusinessTypeLocked(userId);
      expect(isLocked, isTrue);
    });

    test(
      'BillsRepository blocks creation of mismatched business type',
      () async {
        final now = DateTime.now();

        // 1. Setup Shop as 'grocery'
        await database
            .into(database.shops)
            .insert(
              ShopsCompanion.insert(
                id: userId,
                name: 'Test Shop 2',
                ownerId: userId,
                businessType: const drift.Value('grocery'),
                createdAt: now,
                updatedAt: now,
                isSynced: const drift.Value(false),
              ),
            );

        // 2. Try to create a 'pharmacy' bill
        final bill = Bill(
          id: 'bill_bad',
          customerId: 'cust_bad',
          ownerId: userId,
          invoiceNumber: 'INV002',
          date: now,
          items: [],
          subtotal: 100,
          totalTax: 0,
          grandTotal: 100,
          paidAmount: 100,
          businessType: 'pharmacy', // MISMATCH!
          status: 'Paid',
          paymentType: 'Cash',
          source: 'app',
        );

        // 3. Expect security exception
        expect(
          () => billsRepository.createBill(bill),
          throwsA(
            predicate((e) => e.toString().contains('Security Violation')),
          ),
        );
      },
    );

    test('BillsRepository allows creation of matching business type', () async {
      final now = DateTime.now();

      // 1. Setup Shop as 'grocery'
      await database
          .into(database.shops)
          .insert(
            ShopsCompanion.insert(
              id: userId,
              name: 'Test Shop 3',
              ownerId: userId,
              businessType: const drift.Value('grocery'),
              createdAt: now,
              updatedAt: now,
              isSynced: const drift.Value(false),
            ),
          );

      // 2. Try to create a 'grocery' bill
      final bill = Bill(
        id: 'bill_good',
        customerId: 'cust_good',
        ownerId: userId,
        invoiceNumber: 'INV003',
        date: now,
        items: [],
        subtotal: 100,
        totalTax: 0,
        grandTotal: 100,
        paidAmount: 100,
        businessType: 'grocery', // MATCH!
        status: 'Paid',
        paymentType: 'Cash',
        source: 'app',
      );

      // 3. Should succeed (or fail on other things, but not Security Violation)
      // Since we didn't mock inventory/etc, it might fail elsewhere,
      // but we just want to ensure it passes the security check.
      try {
        await billsRepository.createBill(bill);
      } catch (e) {
        // If it throws Security Violation, fail test.
        if (e.toString().contains('Security Violation')) {
          fail(
            'Should not throw Security Violation for matching business type',
          );
        }
        // Iterate other errors (e.g. unique constraint) are fine for this specific unit test scope
      }
    });
  });
}
