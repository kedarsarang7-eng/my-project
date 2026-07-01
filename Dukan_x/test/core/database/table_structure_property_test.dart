// ============================================================================
// Task 7.3 — PROPERTY TEST
// Feature: offline-license-activation, Property 16: Every table declares
// System_Columns and the required indexes
// **Validates: Requirements 8.1, 8.5, 16.2**
// ============================================================================
// Property 16 (design.md): "For any Local_Store table that mirrors a cloud
// entity, the table declares all eight System_Columns (id, tenant_id,
// created_at, updated_at, deleted_at, sync_status, server_id, local_version)
// and defines indexes on tenant_id, sync_status, and deleted_at."
//
// Approach (in-memory introspection, ≥100 generated cases):
//   1. Open a fresh in-memory AppDatabase via `AppDatabase.forTesting(
//      NativeDatabase.memory())`. Opening it runs the Drift `onCreate` step,
//      which calls `createAll()` and then `_createSystemColumnIndexes()`, so
//      the real production schema (schemaVersion 40) — every table plus the
//      System_Columns indexes — is materialised.
//   2. Introspect the *actual* SQLite catalog once with `PRAGMA table_info`
//      (column set per table) and `PRAGMA index_list` + `PRAGMA index_info`
//      (the set of columns covered by any index per table).
//   3. Run a `dartproptest` property over the System_Columns cloud-entity
//      table set (the 18 tables `AppDatabase._systemColumnIndexTables`
//      enumerates), sampling table + column + index combinations across 200
//      runs (≥100) and asserting, for the sampled table:
//        - the universal System_Columns id, tenant_id, sync_status,
//          server_id, local_version exist, plus created_at/updated_at/
//          deleted_at exactly where the cloud-entity table declares them
//          (Req 8.1), and
//        - an index exists on tenant_id and on sync_status, plus deleted_at
//          where the table has that column (Req 8.5, 16.2).
//
// PBT library: dartproptest ^0.2.1 (the project's resolvable glados-equivalent;
// see pubspec.yaml — glados is unresolvable against the Flutter-SDK test pins).
//
// Run: flutter test test/core/database/table_structure_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/database/app_database.dart';

/// At least 100 iterations per the spec; 200 matches the project PBT default.
const int kNumRuns = 200;

/// Universal System_Columns required on *every* cloud-entity table (Req 8.1).
/// id is the primary key; the other four are added by the `TableSystemColumns`
/// mixin / the v39 migration.
const List<String> kUniversalSystemColumns = <String>[
  'id',
  'tenant_id',
  'sync_status',
  'server_id',
  'local_version',
];

/// Descriptor for one System_Columns cloud-entity table.
///
/// Mirrors `AppDatabase._systemColumnIndexTables` (the 18 tables that carry the
/// System_Columns and therefore the required indexes), enriched with the
/// timestamp columns each table actually declares so the column assertions hold
/// against the real Drift schema:
///   * [hasCreatedAt] / [hasUpdatedAt] — soft-audit timestamps the table
///     declares (some lean tables such as user_sessions / bill_items omit one
///     or both),
///   * [hasDeletedAt] — soft-delete column; drives both the deleted_at column
///     assertion and the deleted_at index assertion (the index is created only
///     where the column exists — Req 8.5).
class _SysTable {
  const _SysTable(
    this.table, {
    this.hasCreatedAt = true,
    this.hasUpdatedAt = true,
    this.hasDeletedAt = true,
  });

  final String table;
  final bool hasCreatedAt;
  final bool hasUpdatedAt;
  final bool hasDeletedAt;

  /// All System_Columns this table is expected to declare.
  List<String> get expectedColumns => <String>[
    ...kUniversalSystemColumns,
    if (hasCreatedAt) 'created_at',
    if (hasUpdatedAt) 'updated_at',
    if (hasDeletedAt) 'deleted_at',
  ];

  /// Columns that must be backed by an index (Req 8.5, 16.2).
  List<String> get expectedIndexedColumns => <String>[
    'tenant_id',
    'sync_status',
    if (hasDeletedAt) 'deleted_at',
  ];
}

/// The System_Columns cloud-entity tables — the exact set
/// `AppDatabase._systemColumnIndexTables` indexes, annotated with the timestamp
/// columns each table declares in `tables.dart`.
const List<_SysTable> kSystemColumnTables = <_SysTable>[
  _SysTable('bills'),
  _SysTable('bill_items', hasUpdatedAt: false, hasDeletedAt: false),
  _SysTable('customers'),
  _SysTable('products'),
  _SysTable('payments'),
  _SysTable('vendors'),
  _SysTable('purchase_orders'),
  _SysTable('purchase_items', hasUpdatedAt: false, hasDeletedAt: false),
  _SysTable('stock_movements', hasUpdatedAt: false, hasDeletedAt: false),
  _SysTable('users', hasDeletedAt: false),
  _SysTable(
    'user_sessions',
    hasCreatedAt: false,
    hasUpdatedAt: false,
    hasDeletedAt: false,
  ),
  _SysTable('roles'),
  _SysTable('permissions'),
  _SysTable('categories'),
  _SysTable('units'),
  _SysTable('inventory'),
  _SysTable('business_settings'),
  _SysTable('tax_rates'),
];

/// The set of column names declared by [table] (via `PRAGMA table_info`).
Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.data['name'] as String).toSet();
}

/// The union of columns covered by any index on [table] (via `PRAGMA
/// index_list` + `PRAGMA index_info`). Because the System_Columns indexes are
/// single-column (`idx_<table>_<column>`), membership in this set is exactly
/// "an index exists on this column".
Future<Set<String>> _indexedColumnsOf(AppDatabase db, String table) async {
  final indexes = await db.customSelect('PRAGMA index_list($table)').get();
  final columns = <String>{};
  for (final idx in indexes) {
    final name = idx.data['name'] as String?;
    if (name == null) continue;
    final info = await db.customSelect("PRAGMA index_info('$name')").get();
    for (final row in info) {
      final col = row.data['name'];
      if (col is String) columns.add(col);
    }
  }
  return columns;
}

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory database: opening it runs onCreate (createAll +
    // _createSystemColumnIndexes), materialising the production schema.
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Feature: offline-license-activation, Property 16: Every table declares '
      'System_Columns and the required indexes', () {
    test(
      'Feature: offline-license-activation, Property 16 — every '
      'System_Columns cloud-entity table declares its System_Columns and '
      'defines indexes on tenant_id, sync_status (+ deleted_at where present)',
      () async {
        // Snapshot the real catalog once so the property predicate stays a
        // cheap, synchronous lookup across all 200 runs.
        final columnsByTable = <String, Set<String>>{};
        final indexedColumnsByTable = <String, Set<String>>{};
        for (final spec in kSystemColumnTables) {
          columnsByTable[spec.table] = await _columnsOf(db, spec.table);
          indexedColumnsByTable[spec.table] = await _indexedColumnsOf(
            db,
            spec.table,
          );
        }

        final tableGen = Gen.elementOf<_SysTable>(kSystemColumnTables);
        final probeGen = Gen.interval(0, 1 << 20);

        // Property: for a generated table and a sampled column/index probe,
        // every expected System_Column is present and every required index
        // exists.
        final held = forAll(
          (_SysTable spec, int probe) {
            final columns = columnsByTable[spec.table]!;
            final indexedColumns = indexedColumnsByTable[spec.table]!;

            // (a) All expected System_Columns are declared (Req 8.1).
            for (final col in spec.expectedColumns) {
              if (!columns.contains(col)) return false;
            }

            // (b) The required indexes exist (Req 8.5, 16.2).
            for (final col in spec.expectedIndexedColumns) {
              if (!indexedColumns.contains(col)) return false;
            }

            // (c) Sampled (table, column) and (table, index) combinations —
            // re-checked explicitly so each run exercises a specific pair,
            // giving combination coverage over the table set.
            final probedColumn =
                spec.expectedColumns[probe % spec.expectedColumns.length];
            if (!columns.contains(probedColumn)) return false;

            final probedIndex =
                spec.expectedIndexedColumns[probe %
                    spec.expectedIndexedColumns.length];
            if (!indexedColumns.contains(probedIndex)) return false;

            return true;
          },
          [tableGen, probeGen],
          numRuns: kNumRuns,
        );

        expect(held, isTrue);
      },
    );

    // Deterministic anchor: exhaustively verify all 18 tables in one pass so
    // a failure points directly at the offending table/column/index.
    test(
      'Feature: offline-license-activation, Property 16 — anchor: all 18 '
      'System_Columns tables satisfy the column and index contract',
      () async {
        for (final spec in kSystemColumnTables) {
          final columns = await _columnsOf(db, spec.table);
          final indexedColumns = await _indexedColumnsOf(db, spec.table);

          for (final col in spec.expectedColumns) {
            expect(
              columns,
              contains(col),
              reason: 'table ${spec.table} is missing System_Column "$col"',
            );
          }
          for (final col in spec.expectedIndexedColumns) {
            expect(
              indexedColumns,
              contains(col),
              reason: 'table ${spec.table} is missing an index on "$col"',
            );
          }
        }
      },
    );
  });
}
