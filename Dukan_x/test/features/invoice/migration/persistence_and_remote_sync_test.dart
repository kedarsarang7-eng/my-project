import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/migration/invoice_layout_migration.dart';
import 'package:dukanx/features/invoice/universal/migration/remote_layout_config_sync.dart';
import 'package:dukanx/features/invoice/universal/migration/shared_prefs_layout_config_store.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MigrationRecord _rec(String id, BusinessType type) {
  const items = [UniversalInvoiceItem(name: 'x', quantity: 1, unitPrice: 100)];
  final data = UniversalInvoiceData(
    shopName: 's',
    ownerName: 'o',
    address: 'a',
    mobile: 'm',
    customerName: 'c',
    invoiceNumber: id,
    date: DateTime(2026, 1, 1),
    items: items,
    grandTotal: 100,
  );
  return MigrationRecord(
    invoiceId: id,
    businessType: type,
    sourceItemCount: 1,
    sourceGrandTotal: 100,
    data: data,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefs persistent store — full migration run', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'migrate -> save -> reload persists configs; rollback clears them',
      () async {
        const migration = InvoiceLayoutMigration();
        final store = SharedPrefsLayoutConfigStore();
        await store.load();
        expect(store.count, 0);

        final records = [
          _rec('INV-1', BusinessType.grocery),
          _rec('INV-2', BusinessType.mobileShop),
        ];

        // Dry run writes nothing.
        final dry = migration.migrate(records, store, dryRun: true);
        expect(dry.isLossless, isTrue);
        expect(store.count, 0);

        // Commit + persist.
        final report = migration.migrate(records, store);
        expect(report.isLossless, isTrue);
        expect(store.count, 2);
        await store.save();

        // A fresh instance reads the persisted configs back.
        final reloaded = SharedPrefsLayoutConfigStore();
        await reloaded.load();
        expect(reloaded.count, 2);
        expect(reloaded.has(BusinessType.grocery), isTrue);
        expect(
          reloaded.get(BusinessType.mobileShop)!.businessType,
          BusinessType.mobileShop,
        );

        // Rollback + persist clears them.
        migration.rollback(store, report);
        await store.save();
        final afterRollback = SharedPrefsLayoutConfigStore();
        await afterRollback.load();
        expect(afterRollback.count, 0);
      },
    );
  });

  group('RemoteLayoutConfigSync — DynamoDB-via-API-Gateway adapter', () {
    test('pushAll uploads all configs; pullInto reconstructs them', () async {
      // Simulated remote key-value store (stands in for DynamoDB).
      final remote = <String, Map<String, dynamic>>{};
      final sync = RemoteLayoutConfigSync(
        getJson: (bt) async => remote[bt],
        putJson: (bt, json) async {
          remote[bt] = json;
          return true;
        },
        deleteJson: (bt) async => remote.remove(bt) != null,
      );

      // Build a local store via migration.
      const migration = InvoiceLayoutMigration();
      final local = InMemoryLayoutConfigStore();
      migration.migrate([
        _rec('INV-1', BusinessType.grocery),
        _rec('INV-2', BusinessType.hardware),
      ], local);
      expect(local.count, 2);

      // Push to remote.
      final pushed = await sync.pushAll(local);
      expect(pushed, 2);
      expect(remote.keys, containsAll(['grocery', 'hardware']));

      // Pull into a fresh empty local store.
      final target = InMemoryLayoutConfigStore();
      final pulled = await sync.pullInto(target, [
        BusinessType.grocery,
        BusinessType.hardware,
        BusinessType.clothing,
      ]);
      expect(pulled, 2); // clothing absent remotely -> skipped
      expect(target.has(BusinessType.grocery), isTrue);
      expect(
        target.get(BusinessType.hardware)!.businessType,
        BusinessType.hardware,
      );

      // Delete (production rollback path).
      final removed = await sync.deleteAll([
        BusinessType.grocery,
        BusinessType.hardware,
      ]);
      expect(removed, 2);
      expect(remote, isEmpty);
    });

    test('pushAll throws RemoteSyncException on backend failure', () async {
      final sync = RemoteLayoutConfigSync(
        getJson: (bt) async => null,
        putJson: (bt, json) async => false, // simulate backend error
        deleteJson: (bt) async => false,
      );
      const migration = InvoiceLayoutMigration();
      final local = InMemoryLayoutConfigStore();
      migration.migrate([_rec('INV-1', BusinessType.grocery)], local);

      expect(() => sync.pushAll(local), throwsA(isA<RemoteSyncException>()));
    });
  });
}
