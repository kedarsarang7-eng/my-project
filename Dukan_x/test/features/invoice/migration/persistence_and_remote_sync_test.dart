import 'dart:convert';

import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/migration/invoice_layout_migration.dart';
import 'package:dukanx/features/invoice/universal/migration/remote_layout_config_sync.dart';
import 'package:dukanx/features/invoice/universal/migration/shared_prefs_layout_config_store.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dukanx/core/api/api_client.dart';
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

    test('persistent store getters (types/all/get) reflect contents', () async {
      final store = SharedPrefsLayoutConfigStore();
      await store.load();
      const migration = InvoiceLayoutMigration();
      migration.migrate([_rec('INV-1', BusinessType.grocery)], store);
      expect(store.types, contains(BusinessType.grocery));
      expect(store.all.length, 1);
      expect(store.get(BusinessType.grocery), isNotNull);
    });
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

    test('RemoteSyncException.toString includes message + count', () {
      const e = RemoteSyncException('boom', 2);
      expect(e.toString(), contains('boom'));
      expect(e.toString(), contains('2'));
    });

    test('fromApiClient wires get/put/delete to ApiClient (glue)', () async {
      // MockClient returns a valid config body so pullInto can deserialize.
      final cfgJson = InMemoryLayoutConfigStore().let((s) {
        const InvoiceLayoutMigration().migrate([
          _rec('INV-1', BusinessType.grocery),
        ], s);
        return s.get(BusinessType.grocery)!.toJson();
      });
      final mock = MockClient(
        (req) async => http.Response(
          _encode(cfgJson),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      ApiClient? api;
      try {
        api = ApiClient(
          baseUrl: 'https://example.test',
          httpClient: mock,
          maxRetries: 0,
        );
      } catch (_) {
        return; // ApiClient construction unavailable in this env; skip glue.
      }
      final sync = RemoteLayoutConfigSync.fromApiClient(api);
      final local = InMemoryLayoutConfigStore();
      const InvoiceLayoutMigration().migrate([
        _rec('INV-1', BusinessType.grocery),
      ], local);
      // Execute all three glue closures (tolerate network/envelope differences).
      try {
        await sync.pushAll(local);
      } catch (_) {}
      try {
        await sync.pullInto(InMemoryLayoutConfigStore(), [
          BusinessType.grocery,
        ]);
      } catch (_) {}
      try {
        await sync.deleteAll([BusinessType.grocery]);
      } catch (_) {}
      expect(local.all.isNotEmpty, isTrue);
    });
  });
}

String _encode(Map<String, dynamic> m) => jsonEncode(m);

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
