import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:dukanx/core/database/app_database.dart'; // Adjust path if needed
// import 'package:dukanx/features/inventory/services/production_service.dart';
// import 'package:dukanx/features/inventory/services/inventory_service.dart';
// import 'package:dukanx/features/accounting/services/accounting_service.dart';
// import 'package:dukanx/features/accounting/services/locking_service.dart';
// import 'package:dukanx/core/sync/sync_manager.dart';
// import 'package:mockito/mockito.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // In-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Manufacturing Module Schema Tests', () {
    test('BillOfMaterials table exists and can insert', () async {
      final bomId = 'bom-1';
      final userId = 'user-1';

      await database
          .into(database.billOfMaterials)
          .insert(
            BillOfMaterialsCompanion.insert(
              id: bomId,
              userId: userId,
              finishedGoodId: 'fg-1',
              rawMaterialId: 'rm-1',
              quantityRequired: 2.0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final result = await (database.select(
        database.billOfMaterials,
      )..where((t) => t.id.equals(bomId))).getSingle();
      expect(result.id, equals(bomId));
      expect(result.quantityRequired, equals(2.0));
    });

    test('ProductionEntries table exists and can insert', () async {
      final entryId = 'prod-1';
      final userId = 'user-1';

      await database
          .into(database.productionEntries)
          .insert(
            ProductionEntriesCompanion.insert(
              id: entryId,
              userId: userId,
              finishedGoodId: 'fg-1',
              quantityProduced: 10.0,
              productionDate: DateTime.now(),
              rawMaterialsJson: '{}',
              createdAt: DateTime.now(),
            ),
          );

      final result = await (database.select(
        database.productionEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();
      expect(result.id, equals(entryId));
      expect(result.quantityProduced, equals(10.0));
    });
  });

  group('Recurring Billing Schema Tests', () {
    test('Subscriptions table exists and can insert', () async {
      final subId = 'sub-1';
      final userId = 'user-1';

      await database
          .into(database.subscriptions)
          .insert(
            SubscriptionsCompanion.insert(
              id: subId,
              userId: userId,
              customerId: 'cust-1',
              planName: 'Basic Plan',
              billingCycle: const Value('MONTHLY'),
              startDate: DateTime.now(),
              nextBillingDate: DateTime.now().add(const Duration(days: 30)),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final result = await (database.select(
        database.subscriptions
      )..where((t) => t.id.equals(subId))).getSingle();
      expect(result.id, equals(subId));
      expect(result.billingCycle, equals('MONTHLY'));
    });
  });
}
