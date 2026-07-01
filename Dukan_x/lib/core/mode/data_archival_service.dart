// ============================================================================
// DATA ARCHIVAL SERVICE — two-year Local_Store archival partition
// ============================================================================
// Feature: offline-license-activation (Task 19.1)
//
// The Data_Archival_Service keeps the offline Local_Store fast as data grows by
// PARTITIONING each high-volume table by record age. It implements Requirement
// 16:
//
//   16.1  Records older than 2 years (by `created_at`) are MOVED into an
//         archive store, while the remaining (recent) records stay live. After
//         a run the archive store holds exactly the old records and the live
//         store holds exactly the remaining ones — the live data set stays
//         correct and complete (Property 33).
//   16.2  Indexes are maintained on the columns used by high-frequency queries
//         (`created_at` and `tenant_id`) on BOTH the live and the archive
//         tables, so queries stay fast after archival.
//
// Design constraints honoured here (see design.md, "Local Data Scale"):
//   * SERVICE LAYER ONLY. Pure Dart with no Flutter / widget-tree dependency;
//     injected through the existing `service_locator` (`sl`) and never
//     referenced by the UI. No UI changes are introduced.
//   * REUSE, DON'T REBUILD. It operates on the EXISTING Drift/SQLCipher
//     [AppDatabase] (`app_database.dart`) and never drops or redefines an
//     existing table. The archive tables (`archive_<table>`) are NEW, purely
//     additive tables created on demand inside the same encrypted database, so
//     the archive store inherits the Local_Store's SQLCipher protection.
//   * CLOUD MODE UNTOUCHED. Archival is a maintenance concern of the offline
//     Local_Store; nothing here changes Cloud_Subscription_Mode behaviour.
//
// Atomicity: a whole run executes inside ONE Drift transaction. Each row is
// copied into its archive table and then removed from the live table using the
// SAME age predicate, so a row can never be lost or duplicated. If any step
// fails, the entire transaction rolls back and the live store is left exactly
// as it was.
//
// Foreign keys: `foreign_keys = ON` is enabled for the Local_Store, and
// `bill_items` references `bills` with ON DELETE CASCADE. To guarantee the live
// store stays referentially complete, a cascade child is archived together with
// (and before) its parent in the same transaction, using a predicate that also
// captures any child whose parent is being archived. Deleting the old parents
// therefore cascades onto rows that were already moved to the archive — never
// onto a live row.
//
// Author: DukanX Engineering
// ============================================================================

import 'package:drift/drift.dart' show Variable;

import '../database/app_database.dart';
import '../services/logger_service.dart';

// ============================================================================
// Configuration
// ============================================================================

/// Describes a single live table that participates in age-based archival.
///
/// A record is "old" when its [ageColumn] (`created_at` by default) is strictly
/// older than the two-year cutoff. For a table that is the CHILD side of an
/// `ON DELETE CASCADE` foreign key, set [cascadeParentTable] and
/// [parentKeyColumn] so the child is partitioned by *parent membership* as well
/// as its own age — this keeps the live store referentially complete when the
/// parent rows are removed.
class ArchivableTable {
  /// Live SQL table name (must be a trusted, code-defined identifier — it is
  /// inlined into DDL/DML and is never derived from user input).
  final String table;

  /// The age column the two-year cutoff is applied to. Defaults to
  /// `created_at`, the universal System_Column every archivable table carries.
  final String ageColumn;

  /// When this table is the child of an `ON DELETE CASCADE` foreign key, the
  /// parent table name (e.g. `bills`). `null` for independent tables.
  final String? cascadeParentTable;

  /// The column on THIS table that references [cascadeParentTable]`.id`
  /// (e.g. `bill_id`). Required when [cascadeParentTable] is set.
  final String? parentKeyColumn;

  const ArchivableTable(
    this.table, {
    this.ageColumn = 'created_at',
    this.cascadeParentTable,
    this.parentKeyColumn,
  }) : assert(
         cascadeParentTable == null || parentKeyColumn != null,
         'parentKeyColumn is required when cascadeParentTable is set',
       );

  /// Whether this table is the child side of a cascade foreign key.
  bool get isCascadeChild => cascadeParentTable != null;
}

// ============================================================================
// Result types
// ============================================================================

/// The per-table outcome of an archival run.
class TableArchivalResult {
  /// The live table that was partitioned.
  final String table;

  /// Number of rows moved into the archive table (== rows removed from live).
  final int archivedCount;

  const TableArchivalResult({required this.table, required this.archivedCount});

  @override
  String toString() =>
      'TableArchivalResult(table: $table, archived: $archivedCount)';
}

/// The outcome of a whole [DataArchivalService.runArchival] call.
sealed class ArchivalResult {
  const ArchivalResult();
}

/// Archival completed; [results] lists how many rows each table moved and
/// [cutoff] is the boundary that was applied (records older than it were
/// archived).
class ArchivalCompleted extends ArchivalResult {
  final DateTime cutoff;
  final List<TableArchivalResult> results;

  const ArchivalCompleted({required this.cutoff, required this.results});

  /// Total rows moved across every table in this run.
  int get totalArchived => results.fold(0, (sum, r) => sum + r.archivedCount);
}

/// Archival failed and the transaction rolled back; the live store is
/// unchanged. [reason] explains the failure.
class ArchivalFailed extends ArchivalResult {
  final String reason;
  final Object? error;

  const ArchivalFailed(this.reason, {this.error});
}

// ============================================================================
// Service
// ============================================================================

/// Partitions the Local_Store by record age: records older than two years are
/// moved into an archive store while the remainder stay live, with indexes
/// maintained on the high-frequency query columns (Requirement 16.1, 16.2).
///
/// Service layer only — injected through `sl`, never referenced by the UI.
class DataArchivalService {
  static const String _logTag = 'DataArchivalService';

  /// Archival horizon: records older than this many years are archived
  /// (Requirement 16.1).
  static const int archiveAgeYears = 2;

  /// Prefix for the additive archive tables (`archive_<table>`).
  static const String archiveTablePrefix = 'archive_';

  /// The columns the archive store and the live store keep indexed because
  /// they drive the high-frequency offline queries (Requirement 16.2):
  ///  - `created_at` — every date-range report and the archival cutoff itself;
  ///  - `tenant_id`  — multi-tenant isolation on every list query.
  static const List<String> highFrequencyIndexColumns = [
    'created_at',
    'tenant_id',
  ];

  /// The default high-volume transactional tables that grow without bound and
  /// therefore benefit from archival. Ordered so a cascade child (`bill_items`)
  /// is processed BEFORE its parent (`bills`) within the run's single
  /// transaction. All carry the universal `created_at` System_Column.
  static const List<ArchivableTable> defaultArchivableTables = [
    ArchivableTable(
      'bill_items',
      cascadeParentTable: 'bills',
      parentKeyColumn: 'bill_id',
    ),
    ArchivableTable('bills'),
    ArchivableTable('payments'),
    ArchivableTable('stock_movements'),
  ];

  final AppDatabase _db;
  final List<ArchivableTable> _tables;

  /// Creates a [DataArchivalService].
  ///
  /// [tables] defaults to [defaultArchivableTables]; callers may supply their
  /// own ordered list (children before cascade parents) to extend the set
  /// without changing this service.
  DataArchivalService(AppDatabase db, {List<ArchivableTable>? tables})
    : _db = db,
      _tables = tables ?? defaultArchivableTables;

  // --------------------------------------------------------------------------
  // Pure cutoff computation (Req 16.1) — directly testable (Property 33)
  // --------------------------------------------------------------------------

  /// The archival boundary for the given [now]: records whose age column is
  /// strictly before this instant are "older than two years" and get archived.
  ///
  /// Computed on the calendar (subtract [archiveAgeYears] from the year) so the
  /// boundary tracks real two-year-ago dates rather than a fixed day count.
  DateTime archiveCutoff(DateTime now) => DateTime(
    now.year - archiveAgeYears,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
  );

  // --------------------------------------------------------------------------
  // Index maintenance (Req 16.2)
  // --------------------------------------------------------------------------

  /// Ensures the high-frequency-query indexes exist on every live archivable
  /// table and on its archive table (Requirement 16.2).
  ///
  /// Idempotent (`CREATE INDEX IF NOT EXISTS`) so it is safe to call before
  /// every run and standalone. The archive table is created first when missing
  /// so its indexes can be attached.
  Future<void> ensureIndexes() async {
    for (final t in _tables) {
      await _ensureArchiveTable(t.table);
      await _ensureIndexesFor(t.table);
      await _ensureIndexesFor(_archiveNameOf(t.table));
    }
  }

  Future<void> _ensureIndexesFor(String table) async {
    for (final column in highFrequencyIndexColumns) {
      if (!await _columnExists(table, column)) continue;
      await _db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${table}_$column ON "$table" ("$column")',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Archival run (Req 16.1)
  // --------------------------------------------------------------------------

  /// Moves records older than two years into the archive store, keeping the
  /// remainder live (Requirement 16.1).
  ///
  /// The whole run is ONE transaction: every table's copy-then-remove uses the
  /// same age predicate, so the partition is exact and atomic. On any failure
  /// the transaction rolls back and the live store is left unchanged.
  ///
  /// [now] defaults to the current time and exists so the cutoff is injectable
  /// for tests.
  Future<ArchivalResult> runArchival({DateTime? now}) async {
    final cutoff = archiveCutoff(now ?? DateTime.now());
    LoggerService.i(
      _logTag,
      'Starting archival: moving records older than $cutoff '
      '($archiveAgeYears years) into the archive store.',
    );

    try {
      // Maintain indexes (and create any missing archive tables) before the
      // move so both partitions stay fast (Req 16.2).
      await ensureIndexes();

      final results = await _db.transaction(() async {
        final perTable = <TableArchivalResult>[];
        for (final t in _tables) {
          final moved = await _archiveTable(t, cutoff);
          perTable.add(
            TableArchivalResult(table: t.table, archivedCount: moved),
          );
        }
        return perTable;
      });

      final total = results.fold<int>(0, (s, r) => s + r.archivedCount);
      LoggerService.i(
        _logTag,
        'Archival completed: moved $total record(s) across '
        '${results.length} table(s) into the archive store.',
      );
      return ArchivalCompleted(cutoff: cutoff, results: results);
    } catch (e, st) {
      LoggerService.e(
        _logTag,
        'Archival rolled back; live store left unchanged.',
        e,
        st,
      );
      return ArchivalFailed('archival rolled back: $e', error: e);
    }
  }

  /// Copies the old rows of [t] into its archive table and removes them from
  /// the live table using the SAME predicate, returning the number moved.
  ///
  /// MUST run inside the run's transaction so the copy and the delete commit
  /// together.
  Future<int> _archiveTable(ArchivableTable t, DateTime cutoff) async {
    await _ensureArchiveTable(t.table);

    final archive = _archiveNameOf(t.table);
    final columns = await _columnNamesOf(t.table);
    final columnList = columns.map((c) => '"$c"').join(', ');

    // Age predicate. A cascade child also captures rows whose parent is being
    // archived, so removing the old parents never cascade-deletes a live row.
    final cutoffVar = Variable<DateTime>(cutoff);
    final String where;
    final List<Variable> variables;
    if (t.isCascadeChild) {
      where =
          '"${t.ageColumn}" < ? OR "${t.parentKeyColumn}" IN '
          '(SELECT "id" FROM "${t.cascadeParentTable}" WHERE "${t.ageColumn}" < ?)';
      variables = [cutoffVar, cutoffVar];
    } else {
      where = '"${t.ageColumn}" < ?';
      variables = [cutoffVar];
    }

    // 1. Copy the old rows into the archive table (additive; never touches the
    //    live schema). Explicit column list keeps it correct across schema
    //    evolution regardless of column order.
    final inserted = await _db.customUpdate(
      'INSERT INTO "$archive" ($columnList) '
      'SELECT $columnList FROM "${t.table}" WHERE $where',
      variables: variables,
    );

    // 2. Remove exactly those rows from the live table (same predicate).
    final deleted = await _db.customUpdate(
      'DELETE FROM "${t.table}" WHERE $where',
      variables: variables,
    );

    if (inserted != deleted) {
      // The copy and delete share a predicate, so this should never happen.
      // Throwing aborts and rolls back the whole run, leaving the live store
      // intact rather than risking a lossy partition.
      throw StateError(
        'Archival mismatch on "${t.table}": copied $inserted but removed '
        '$deleted; rolling back to protect the live store.',
      );
    }

    LoggerService.d(
      _logTag,
      'Archived $inserted record(s) from "${t.table}" into "$archive".',
    );
    return inserted;
  }

  // --------------------------------------------------------------------------
  // Archive-table provisioning helpers
  // --------------------------------------------------------------------------

  String _archiveNameOf(String table) => '$archiveTablePrefix$table';

  /// Creates the archive table for [table] if it does not exist, mirroring the
  /// live table's current columns (names + declared types) WITHOUT constraints,
  /// primary keys or foreign keys — an append-only archive store. If the
  /// archive table already exists but is missing columns the live table gained
  /// later, those columns are added so the column-list INSERT stays valid.
  Future<void> _ensureArchiveTable(String table) async {
    final archive = _archiveNameOf(table);
    final live = await _tableInfo(table);
    if (live.isEmpty) {
      // Live table not found (defensive): nothing to mirror.
      return;
    }

    if (!await _tableExists(archive)) {
      final defs = live
          .map((c) => c.type.isEmpty ? '"${c.name}"' : '"${c.name}" ${c.type}')
          .join(', ');
      await _db.customStatement(
        'CREATE TABLE IF NOT EXISTS "$archive" ($defs)',
      );
      return;
    }

    // Archive table exists — reconcile any columns added to the live table
    // since it was created (additive only).
    final existing = (await _columnNamesOf(archive)).toSet();
    for (final c in live) {
      if (existing.contains(c.name)) continue;
      final typeSuffix = c.type.isEmpty ? '' : ' ${c.type}';
      await _db.customStatement(
        'ALTER TABLE "$archive" ADD COLUMN "${c.name}"$typeSuffix',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Schema introspection (PRAGMA)
  // --------------------------------------------------------------------------

  Future<List<_ColumnInfo>> _tableInfo(String table) async {
    final rows = await _db.customSelect('PRAGMA table_info("$table")').get();
    return rows
        .map(
          (r) => _ColumnInfo(
            name: r.read<String>('name'),
            type: (r.readNullable<String>('type') ?? '').trim(),
          ),
        )
        .toList();
  }

  Future<List<String>> _columnNamesOf(String table) async {
    final info = await _tableInfo(table);
    return info.map((c) => c.name).toList();
  }

  Future<bool> _columnExists(String table, String column) async {
    final info = await _tableInfo(table);
    return info.any((c) => c.name == column);
  }

  Future<bool> _tableExists(String table) async {
    final row = await _db
        .customSelect(
          "SELECT 1 AS present FROM sqlite_master "
          "WHERE type = 'table' AND name = ?",
          variables: [Variable<String>(table)],
        )
        .getSingleOrNull();
    return row != null;
  }
}

/// A live column's name and declared SQLite type, read from `PRAGMA table_info`.
class _ColumnInfo {
  final String name;
  final String type;
  const _ColumnInfo({required this.name, required this.type});
}
