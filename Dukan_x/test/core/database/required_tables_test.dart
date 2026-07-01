// ============================================================================
// REQUIRED CLOUD-ENTITY TABLE PRESENCE TEST
// ============================================================================
// Feature: offline-license-activation (task 7.5)
//
// Verifies Requirement 8.2: the Local_Store provides at minimum a table for
// each required cloud entity after schema creation/migration.
//
// The test opens an in-memory AppDatabase (which runs onCreate -> createAll,
// the equivalent end-state of the v39 migration that adds the missing
// cloud-entity tables) and inspects sqlite_master to assert every required
// table exists. Each logical cloud entity from Req 8.2 is mapped to the
// concrete Drift SQL table name used by this codebase.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dukanx/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  // Maps each Req 8.2 cloud entity to its actual Drift SQL table name.
  // Several entities are served by existing tables under different names
  // (e.g. sales -> bills, sessions -> user_sessions), which is why the
  // requirement language ("at minimum a table for each ... entity") is
  // satisfied by these concrete tables.
  const requiredEntityTables = <String, String>{
    'users': 'users',
    'roles': 'roles',
    'permissions': 'permissions',
    'sessions': 'user_sessions',
    'products': 'products',
    'categories': 'categories',
    'units': 'units',
    'inventory': 'inventory',
    'inventory_movements': 'stock_movements',
    'customers': 'customers',
    'sales': 'bills',
    'sale_items': 'bill_items',
    'payments': 'payments',
    'vendors': 'vendors',
    'purchases': 'purchase_orders',
    'purchase_items': 'purchase_items',
    'business_settings': 'business_settings',
    'tax_rates': 'tax_rates',
  };

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  /// Returns the set of physical table names in the opened database.
  Future<Set<String>> readTableNames() async {
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  group('Required cloud-entity tables (Req 8.2)', () {
    test(
      'every required cloud entity has a table after schema creation',
      () async {
        final tableNames = await readTableNames();

        final missing = <String>[];
        requiredEntityTables.forEach((entity, sqlName) {
          if (!tableNames.contains(sqlName)) {
            missing.add('$entity (expected SQL table "$sqlName")');
          }
        });

        expect(
          missing,
          isEmpty,
          reason: 'Missing required cloud-entity tables: ${missing.join(', ')}',
        );
      },
    );

    test(
      'the newly added cloud-entity tables exist (Req 8.2 additions)',
      () async {
        final tableNames = await readTableNames();

        // Tables introduced by the v39 offline-license-activation migration.
        const newlyAdded = <String>[
          'roles',
          'permissions',
          'categories',
          'units',
          'inventory',
          'business_settings',
          'tax_rates',
        ];

        for (final t in newlyAdded) {
          expect(
            tableNames.contains(t),
            isTrue,
            reason: 'Expected newly added table "$t" to exist',
          );
        }
      },
    );

    test('all 18 required cloud entities are covered', () {
      // Guards against accidental edits dropping an entity from the map.
      expect(requiredEntityTables.length, equals(18));
    });
  });
}
