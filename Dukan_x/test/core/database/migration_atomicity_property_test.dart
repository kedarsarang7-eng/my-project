// ============================================================================
// Task 7.4 — PROPERTY TEST
// Feature: offline-license-activation, Property 17: Schema migration is atomic
// and preserves existing data
// **Validates: Requirements 8.7, 8.8**
// ============================================================================
//
// Property 17 (design.md):
//   "For any pre-migration dataset, a successful migration preserves every
//    existing row and column value and adds the new columns/tables/indexes,
//    while a migration that does not complete leaves the prior schema and all
//    data identical to the pre-migration snapshot and reports the failure."
//
// Requirement 8.7: extend the existing Drift schema through its migration
//   mechanism rather than redefine/drop existing tables, preserving all
//   existing rows and their column values during the migration.
// Requirement 8.8: if a schema migration does not complete successfully, retain
//   the prior schema and all existing data unchanged and report that the
//   migration did not complete.
//
// ----------------------------------------------------------------------------
// How this exercises the REAL migration ladder
// ----------------------------------------------------------------------------
// We construct a pre-v39 (schemaVersion 38) database by hand — a minimal
// snapshot of the cloud-entity tables that the v39/v40 steps touch — seed it
// with an arbitrary, generated dataset, then open the *real* `AppDatabase`
// over that connection. Drift sees `user_version = 38 < schemaVersion (40)` and
// runs the actual `onUpgrade` ladder (the `from < 39` System_Columns +
// cloud-entity step and the `from < 40` index step). We then assert against the
// live sqlite3 connection that every seeded row and its original column values
// survived and that the additive schema objects now exist.
//
// PBT library: dartproptest ^0.2.1 (the project's PBT library; see pubspec.yaml
// — `glados` is unresolvable against the Flutter-SDK-pinned test deps). Each
// property runs >= 100 generated cases.
//
// Run:
//   flutter test test/core/database/migration_atomicity_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import 'package:dukanx/core/database/app_database.dart';

/// At least 100 iterations per the spec; 200 matches the project's PBT default.
const int _kNumRuns = 200;

// ---------------------------------------------------------------------------
// Generated dataset model
// ---------------------------------------------------------------------------

class _ProductRow {
  const _ProductRow(this.id, this.name, this.sellingPrice);
  final String id;
  final String name;
  final double sellingPrice;
}

class _CustomerRow {
  const _CustomerRow(this.id, this.name);
  final String id;
  final String name;
}

class _BillRow {
  const _BillRow(this.id, this.invoiceNumber, this.grandTotal);
  final String id;
  final String invoiceNumber;
  final double grandTotal;
}

/// A pre-migration dataset: arbitrary rows for three representative existing
/// cloud-entity tables (products, customers, bills). Row counts and contents
/// vary per generated case, which is what drives the >= 100 distinct cases.
class _Dataset {
  const _Dataset({
    required this.products,
    required this.customers,
    required this.bills,
  });
  final List<_ProductRow> products;
  final List<_CustomerRow> customers;
  final List<_BillRow> bills;
}

// ---------------------------------------------------------------------------
// Generators (smart: ids are index-derived so primary keys never collide,
// while names/prices/counts vary freely to cover the input space)
// ---------------------------------------------------------------------------

/// Free-form text including punctuation/quotes — bound via parameters so it can
/// never break the seed SQL and round-trips byte-for-byte.
final Generator<String> _textGen = Gen.printableAsciiString(
  minLength: 0,
  maxLength: 24,
);

/// Money as integer cents in [0, 100000], converted to a double on use. The
/// identical double value is what we both store and expect back.
final Generator<int> _centsGen = Gen.interval(0, 100000);

double _cents(int c) => c / 100.0;

Generator<_Dataset> _datasetGen() {
  final productsGen = Gen.array(
    Gen.tuple([_textGen, _centsGen]),
    minLength: 0,
    maxLength: 12,
  );
  final customersGen = Gen.array(_textGen, minLength: 0, maxLength: 12);
  final billsGen = Gen.array(
    Gen.tuple([_textGen, _centsGen]),
    minLength: 0,
    maxLength: 12,
  );

  return Gen.tuple([productsGen, customersGen, billsGen]).map((parts) {
    final rawProducts = parts[0] as List<dynamic>;
    final rawCustomers = parts[1] as List<dynamic>;
    final rawBills = parts[2] as List<dynamic>;

    final products = <_ProductRow>[
      for (var i = 0; i < rawProducts.length; i++)
        _ProductRow(
          'p$i',
          (rawProducts[i] as List)[0] as String,
          _cents((rawProducts[i] as List)[1] as int),
        ),
    ];
    final customers = <_CustomerRow>[
      for (var i = 0; i < rawCustomers.length; i++)
        _CustomerRow('c$i', rawCustomers[i] as String),
    ];
    final bills = <_BillRow>[
      for (var i = 0; i < rawBills.length; i++)
        _BillRow(
          'b$i',
          (rawBills[i] as List)[0] as String,
          _cents((rawBills[i] as List)[1] as int),
        ),
    ];

    return _Dataset(products: products, customers: customers, bills: bills);
  });
}

// ---------------------------------------------------------------------------
// Pre-v39 (schemaVersion 38) schema snapshot
// ---------------------------------------------------------------------------
//
// A minimal but faithful pre-feature schema for the eleven existing
// cloud-entity tables that the v39 step adds System_Columns to. Crucially these
// tables do NOT yet declare tenant_id / sync_status / server_id / local_version
// (the migration must add them) and the new v39 cloud-entity tables (roles,
// permissions, ...) are absent (the migration must create them). `deleted_at`
// is included where the v40 index step builds a deleted_at index.
void _buildV38Schema(s3.Database raw) {
  raw.execute('''
    CREATE TABLE bills (
      id TEXT NOT NULL PRIMARY KEY,
      invoice_number TEXT,
      grand_total REAL,
      deleted_at INTEGER
    );''');
  raw.execute('CREATE TABLE bill_items (id TEXT NOT NULL PRIMARY KEY);');
  raw.execute('''
    CREATE TABLE customers (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT,
      deleted_at INTEGER
    );''');
  raw.execute('''
    CREATE TABLE products (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT,
      selling_price REAL,
      deleted_at INTEGER
    );''');
  raw.execute(
    'CREATE TABLE payments (id TEXT NOT NULL PRIMARY KEY, deleted_at INTEGER);',
  );
  raw.execute(
    'CREATE TABLE vendors (id TEXT NOT NULL PRIMARY KEY, deleted_at INTEGER);',
  );
  raw.execute(
    'CREATE TABLE purchase_orders (id TEXT NOT NULL PRIMARY KEY, deleted_at INTEGER);',
  );
  raw.execute('CREATE TABLE purchase_items (id TEXT NOT NULL PRIMARY KEY);');
  raw.execute('CREATE TABLE stock_movements (id TEXT NOT NULL PRIMARY KEY);');
  raw.execute('CREATE TABLE users (id TEXT NOT NULL PRIMARY KEY);');
  raw.execute('CREATE TABLE user_sessions (id TEXT NOT NULL PRIMARY KEY);');
  // Accounting tables required by the v41 migration step
  raw.execute('CREATE TABLE journal_entries (id TEXT NOT NULL PRIMARY KEY);');
  raw.execute(
    'CREATE TABLE accounting_periods (id TEXT NOT NULL PRIMARY KEY);',
  );
  raw.execute('CREATE TABLE ledger_accounts (id TEXT NOT NULL PRIMARY KEY);');
}

void _seed(s3.Database raw, _Dataset ds) {
  for (final p in ds.products) {
    raw.execute(
      'INSERT INTO products (id, name, selling_price, deleted_at) '
      'VALUES (?, ?, ?, NULL)',
      [p.id, p.name, p.sellingPrice],
    );
  }
  for (final c in ds.customers) {
    raw.execute(
      'INSERT INTO customers (id, name, deleted_at) VALUES (?, ?, NULL)',
      [c.id, c.name],
    );
  }
  for (final b in ds.bills) {
    raw.execute(
      'INSERT INTO bills (id, invoice_number, grand_total, deleted_at) '
      'VALUES (?, ?, ?, NULL)',
      [b.id, b.invoiceNumber, b.grandTotal],
    );
  }
}

// ---------------------------------------------------------------------------
// Raw-connection introspection helpers
// ---------------------------------------------------------------------------

bool _tableExists(s3.Database raw, String table) => raw.select(
  "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
  [table],
).isNotEmpty;

bool _indexExists(s3.Database raw, String index) => raw.select(
  "SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",
  [index],
).isNotEmpty;

Set<String> _columns(s3.Database raw, String table) => raw
    .select("PRAGMA table_info('$table')")
    .map((r) => r['name'] as String)
    .toSet();

const List<String> _systemColumns = [
  'tenant_id',
  'sync_status',
  'server_id',
  'local_version',
];

const List<String> _newCloudEntityTables = [
  'roles',
  'permissions',
  'categories',
  'units',
  'inventory',
  'business_settings',
  'tax_rates',
];

void main() {
  group('Feature: offline-license-activation, Property 17: Schema migration is '
      'atomic and preserves existing data', () {
    // ---------------------------------------------------------------------
    // PROPERTY (Req 8.7): a successful migration preserves every existing row
    // and column value AND adds the new System_Columns, tables, and indexes.
    //
    // Drives >= 100 cases via varied row counts and contents across three
    // representative existing tables.
    // ---------------------------------------------------------------------
    test('Feature: offline-license-activation, Property 17 — a successful '
        'v38->v40 migration preserves all existing rows/values and adds the '
        'additive System_Columns, cloud-entity tables, and indexes', () async {
      final held = await forAllAsync(
        (_Dataset ds) async {
          final raw = s3.sqlite3.openInMemory();
          AppDatabase? db;
          try {
            _buildV38Schema(raw);
            _seed(raw, ds);
            raw.userVersion = 38;

            // Snapshot the pre-migration data for an exact comparison.
            final beforeProducts = raw.select(
              'SELECT id, name, selling_price FROM products ORDER BY id',
            );
            final beforeCustomers = raw.select(
              'SELECT id, name FROM customers ORDER BY id',
            );
            final beforeBills = raw.select(
              'SELECT id, invoice_number, grand_total FROM bills ORDER BY id',
            );

            // Open the REAL database over this connection. Setting
            // closeUnderlyingOnClose=false lets us dispose `raw` ourselves
            // exactly once in `finally`.
            db = AppDatabase.forTesting(
              NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
            );
            // Force open -> runs the real onUpgrade(38 -> 41) ladder.
            await db.customSelect('SELECT 1').get();

            // --- schema version advanced to the current schemaVersion ---
            if (raw.userVersion != 42) return false;

            // --- new cloud-entity tables were created (Req 8.2/8.7) ---
            for (final t in _newCloudEntityTables) {
              if (!_tableExists(raw, t)) return false;
            }

            // --- System_Columns added on existing tables (Req 8.1/8.7) ---
            final productCols = _columns(raw, 'products');
            final customerCols = _columns(raw, 'customers');
            final billCols = _columns(raw, 'bills');
            for (final col in _systemColumns) {
              if (!productCols.contains(col)) return false;
              if (!customerCols.contains(col)) return false;
              if (!billCols.contains(col)) return false;
            }

            // --- required indexes exist (Req 8.5 additive step) ---
            if (!_indexExists(raw, 'idx_products_tenant_id')) return false;
            if (!_indexExists(raw, 'idx_products_sync_status')) return false;
            if (!_indexExists(raw, 'idx_products_deleted_at')) return false;
            if (!_indexExists(raw, 'idx_customers_tenant_id')) return false;
            if (!_indexExists(raw, 'idx_bills_deleted_at')) return false;

            // --- PRESERVATION: every original row + value survived ---
            final afterProducts = raw.select(
              'SELECT id, name, selling_price FROM products ORDER BY id',
            );
            if (afterProducts.length != beforeProducts.length) return false;
            for (var i = 0; i < afterProducts.length; i++) {
              final a = afterProducts[i];
              final b = beforeProducts[i];
              if (a['id'] != b['id']) return false;
              if (a['name'] != b['name']) return false;
              if ((a['selling_price'] as num?)?.toDouble() !=
                  (b['selling_price'] as num?)?.toDouble()) {
                return false;
              }
            }

            final afterCustomers = raw.select(
              'SELECT id, name FROM customers ORDER BY id',
            );
            if (afterCustomers.length != beforeCustomers.length) {
              return false;
            }
            for (var i = 0; i < afterCustomers.length; i++) {
              if (afterCustomers[i]['id'] != beforeCustomers[i]['id']) {
                return false;
              }
              if (afterCustomers[i]['name'] != beforeCustomers[i]['name']) {
                return false;
              }
            }

            final afterBills = raw.select(
              'SELECT id, invoice_number, grand_total FROM bills ORDER BY id',
            );
            if (afterBills.length != beforeBills.length) return false;
            for (var i = 0; i < afterBills.length; i++) {
              final a = afterBills[i];
              final b = beforeBills[i];
              if (a['id'] != b['id']) return false;
              if (a['invoice_number'] != b['invoice_number']) return false;
              if ((a['grand_total'] as num?)?.toDouble() !=
                  (b['grand_total'] as num?)?.toDouble()) {
                return false;
              }
            }

            // --- the new System_Columns are NULL on legacy rows: the
            //     migration is purely additive and performs no backfill ---
            final dirty = raw.select(
              'SELECT COUNT(*) AS c FROM products WHERE '
              'tenant_id IS NOT NULL OR sync_status IS NOT NULL OR '
              'server_id IS NOT NULL OR local_version IS NOT NULL',
            );
            if ((dirty.first['c'] as int) != 0) return false;

            return true;
          } finally {
            if (db != null) {
              try {
                await db.close();
              } catch (_) {}
            }
            raw.dispose();
          }
        },
        [_datasetGen()],
        numRuns: _kNumRuns,
      );

      expect(held, isTrue);
    });

    // ---------------------------------------------------------------------
    // PROPERTY (Req 8.8): a migration that does not complete reports the
    // failure and leaves the prior schema version and ALL existing data
    // unchanged.
    //
    // We inject a deterministic failure into the v39 step by pre-creating a
    // `roles` table, which makes `createTable(roles)` throw. The arbitrary
    // seeded dataset must remain intact and the schema version must not
    // advance past 38, across >= 100 generated cases.
    // ---------------------------------------------------------------------
    test('Feature: offline-license-activation, Property 17 — a migration that '
        'does not complete reports the failure and leaves the prior schema '
        'version and all existing data unchanged', () async {
      final held = await forAllAsync(
        (_Dataset ds) async {
          final raw = s3.sqlite3.openInMemory();
          AppDatabase? db;
          try {
            _buildV38Schema(raw);
            _seed(raw, ds);
            // Pre-create `roles` so the v39 `createTable(roles)` step fails
            // mid-migration (simulates a migration that cannot complete).
            raw.execute('CREATE TABLE roles (id TEXT NOT NULL PRIMARY KEY);');
            raw.userVersion = 38;

            final beforeProducts = raw.select(
              'SELECT id, name, selling_price FROM products ORDER BY id',
            );
            final beforeCustomers = raw.select(
              'SELECT id, name FROM customers ORDER BY id',
            );
            final beforeBills = raw.select(
              'SELECT id, invoice_number, grand_total FROM bills ORDER BY id',
            );

            db = AppDatabase.forTesting(
              NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
            );

            // The migration must REPORT the failure (Req 8.8): opening the
            // database surfaces the error rather than completing silently.
            var reported = false;
            try {
              await db.customSelect('SELECT 1').get();
            } catch (_) {
              reported = true;
            }
            if (!reported) return false;

            // The prior schema version is retained (not advanced to 40).
            if (raw.userVersion != 38) return false;

            // ALL existing data is unchanged: same rows, same values.
            final afterProducts = raw.select(
              'SELECT id, name, selling_price FROM products ORDER BY id',
            );
            if (afterProducts.length != beforeProducts.length) return false;
            for (var i = 0; i < afterProducts.length; i++) {
              if (afterProducts[i]['id'] != beforeProducts[i]['id']) {
                return false;
              }
              if (afterProducts[i]['name'] != beforeProducts[i]['name']) {
                return false;
              }
              if ((afterProducts[i]['selling_price'] as num?)?.toDouble() !=
                  (beforeProducts[i]['selling_price'] as num?)?.toDouble()) {
                return false;
              }
            }

            final afterCustomers = raw.select(
              'SELECT id, name FROM customers ORDER BY id',
            );
            if (afterCustomers.length != beforeCustomers.length) {
              return false;
            }
            for (var i = 0; i < afterCustomers.length; i++) {
              if (afterCustomers[i]['id'] != beforeCustomers[i]['id']) {
                return false;
              }
              if (afterCustomers[i]['name'] != beforeCustomers[i]['name']) {
                return false;
              }
            }

            final afterBills = raw.select(
              'SELECT id, invoice_number, grand_total FROM bills ORDER BY id',
            );
            if (afterBills.length != beforeBills.length) return false;
            for (var i = 0; i < afterBills.length; i++) {
              if (afterBills[i]['id'] != beforeBills[i]['id']) return false;
              if (afterBills[i]['invoice_number'] !=
                  beforeBills[i]['invoice_number']) {
                return false;
              }
              if ((afterBills[i]['grand_total'] as num?)?.toDouble() !=
                  (beforeBills[i]['grand_total'] as num?)?.toDouble()) {
                return false;
              }
            }

            return true;
          } finally {
            if (db != null) {
              try {
                await db.close();
              } catch (_) {}
            }
            raw.dispose();
          }
        },
        [_datasetGen()],
        numRuns: _kNumRuns,
      );

      expect(held, isTrue);
    });

    // ---------------------------------------------------------------------
    // Deterministic anchor example (Req 8.7): a concrete, fixed dataset is
    // preserved exactly and the additive objects appear. Complements the
    // generated cases with a stable, easy-to-read regression check.
    // ---------------------------------------------------------------------
    test(
      'Feature: offline-license-activation, Property 17 — anchor: a fixed '
      'dataset is preserved exactly and the v39/v40 objects are added',
      () async {
        final raw = s3.sqlite3.openInMemory();
        AppDatabase? db;
        try {
          _buildV38Schema(raw);
          const ds = _Dataset(
            products: [
              _ProductRow('p0', "Basmati Rice 5kg", 549.50),
              _ProductRow('p1', "O'Reilly's Tea", 120.00),
            ],
            customers: [_CustomerRow('c0', 'Asha & Sons')],
            bills: [_BillRow('b0', 'INV-001', 669.50)],
          );
          _seed(raw, ds);
          raw.userVersion = 38;

          db = AppDatabase.forTesting(
            NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
          );
          await db.customSelect('SELECT 1').get();

          expect(raw.userVersion, 42);

          for (final t in _newCloudEntityTables) {
            expect(_tableExists(raw, t), isTrue, reason: 'missing table $t');
          }
          for (final col in _systemColumns) {
            expect(_columns(raw, 'products'), contains(col));
          }
          expect(_indexExists(raw, 'idx_products_tenant_id'), isTrue);

          final products = raw.select(
            'SELECT id, name, selling_price FROM products ORDER BY id',
          );
          expect(products.length, 2);
          expect(products[0]['name'], 'Basmati Rice 5kg');
          expect((products[0]['selling_price'] as num).toDouble(), 549.50);
          expect(products[1]['name'], "O'Reilly's Tea");

          final customers = raw.select('SELECT id, name FROM customers');
          expect(customers.single['name'], 'Asha & Sons');

          final bills = raw.select(
            'SELECT id, invoice_number, grand_total FROM bills',
          );
          expect(bills.single['invoice_number'], 'INV-001');
          expect((bills.single['grand_total'] as num).toDouble(), 669.50);
        } finally {
          if (db != null) {
            try {
              await db.close();
            } catch (_) {}
          }
          raw.dispose();
        }
      },
    );
  });
}
