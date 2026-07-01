// ============================================================================
// SYNC FOUNDATION — Atomic offline-write recording into the Sync_Queue
// ============================================================================
// Feature: offline-license-activation (Task 11.1)
//
// Sync_Foundation is the service-layer component that records every offline
// write into the EXISTING `SyncQueue` table and stamps the written business
// row's System_Columns. For each offline create/update it performs, in ONE
// Drift transaction:
//
//   1. the caller's business-record write (insert/update of the actual row),
//   2. the universal System_Columns stamp — `sync_status = pending` and
//      `local_version` incremented by exactly one (Req 8.6), and
//   3. exactly one matching `SyncQueue` entry (Req 12.1, 12.2).
//
// Atomicity guarantee (Req 12.7 / Property 15): all three happen inside a
// single `db.transaction(...)`. If the SyncQueue insert (or any earlier step)
// fails, the transaction rolls back so NOTHING is persisted, and the failure is
// surfaced to the caller as an [OfflineWriteFailure].
//
// Design constraints honoured here (see design.md "Sync_Foundation (Dart)"):
//   * REUSE, DON'T REBUILD. The queue entry is written through the existing
//     `AppDatabase.insertSyncQueueItem` / `SyncQueue` table and the existing
//     `SyncQueueItem` model. No table is dropped or redefined. The
//     System_Columns stamp is a generic UPDATE over the columns added by the
//     v39 migration (task 7.1).
//   * SERVICE LAYER ONLY. Injected through the existing `service_locator`
//     (`sl`); never referenced by the widget tree. No Flutter UI imports.
//   * SECURITY. The table name cannot be a SQL parameter, so it is validated
//     against a fixed allow-list of System_Columns tables; every value is bound
//     through parameterized statements.
//
// Task 11.2 additions (this file): the documented Conflict_Strategy map and the
// disabled-sync guard.
//   * Conflict_Strategy (Req 12.3, 12.6): a per-entity-class map from each
//     entity class to its documented resolution rule. It is PURELY DECLARATIVE
//     — recorded so a future synchronization worker can apply it — and is NEVER
//     executed in this version (Req 12.4).
//   * Disabled-sync guard (Req 12.4, 12.5 / Property 27): synchronization is
//     defined but inert. Any attempt to trigger sync is blocked BEFORE any
//     Local_Store access, leaving the store unchanged, and the caller is told
//     "sync disabled" (via a [SyncDisabled] result or a catchable
//     [SyncDisabledException]). No conflict resolution and no sync is performed.
//
// Author: DukanX Engineering
// ============================================================================

import 'package:drift/drift.dart' show Variable;

import '../database/app_database.dart';
import '../security/store/store_forensic_gate.dart';
import '../services/logger_service.dart';
import '../sync/sync_queue_state_machine.dart';

// ============================================================================
// Result type
// ============================================================================

/// Outcome of an offline write recorded through [SyncFoundation.recordWrite].
///
/// A dependency-free, service-layer result type (mirrors the `RouteResult`
/// pattern in `mode_manager.dart`) so the sync layer stays free of Flutter /
/// Firebase imports and surfaces a typed failure to the caller (Req 12.7).
sealed class OfflineWriteResult {
  const OfflineWriteResult();

  /// Whether the offline write was persisted atomically.
  bool get isSuccess => this is OfflineWriteSuccess;
}

/// A successful, fully-committed offline write.
///
/// Carries the [operationId] of the single recorded `SyncQueue` entry and the
/// [localVersion] the business row holds after the increment (Req 8.6).
class OfflineWriteSuccess extends OfflineWriteResult {
  final String operationId;
  final int localVersion;
  const OfflineWriteSuccess({
    required this.operationId,
    required this.localVersion,
  });
}

/// A failed offline write. The transaction rolled back, so nothing was
/// persisted (Req 12.7). [stage] names where the failure occurred
/// (`unknown_table`, `business_write`, `system_columns`, `sync_queue`, or
/// `transaction`) and [error] carries the underlying cause when available.
class OfflineWriteFailure extends OfflineWriteResult {
  final String stage;
  final String message;
  final Object? error;
  const OfflineWriteFailure({
    required this.stage,
    required this.message,
    this.error,
  });
}

// ============================================================================
// SyncQueue writer seam (mockable for the atomicity property test, task 11.3)
// ============================================================================

/// Seam for inserting exactly one `SyncQueue` entry. Implementations MUST throw
/// on failure so the enclosing transaction rolls back. A test can inject a
/// throwing implementation to prove the offline write is atomic (Property 15).
abstract class SyncQueueWriter {
  /// Inserts exactly one queue entry for [item]. Throws on failure.
  Future<void> write(SyncQueueItem item);
}

/// Default [SyncQueueWriter] that reuses the existing
/// `AppDatabase.insertSyncQueueItem` (which writes the shared `SyncQueue`
/// table). When invoked inside a `db.transaction(...)` closure it participates
/// in that transaction, so a failure here rolls the whole write back.
class DefaultSyncQueueWriter implements SyncQueueWriter {
  final AppDatabase _db;
  const DefaultSyncQueueWriter(this._db);

  @override
  Future<void> write(SyncQueueItem item) => _db.insertSyncQueueItem(item);
}

// ============================================================================
// SyncFoundation
// ============================================================================

/// Records offline writes into the `SyncQueue` and stamps the written row's
/// System_Columns inside a single atomic transaction (Req 8.6, 12.1, 12.2,
/// 12.7). Service layer only.
class SyncFoundation {
  static const String _logTag = 'SyncFoundation';

  /// The synchronization marker set on every offline write (Req 12.2 / 8.6).
  static const String pendingSyncStatus = 'pending';

  /// SQL table names that carry the universal System_Columns (the v39 mixin
  /// `TableSystemColumns`: tenant_id, sync_status, server_id, local_version).
  /// The table name cannot be bound as a SQL parameter, so writes are confined
  /// to this allow-list to prevent injection and typos.
  static const Set<String> systemColumnTables = {
    'bills',
    'bill_items',
    'customers',
    'products',
    'payments',
    'vendors',
    'purchase_orders',
    'purchase_items',
    'stock_movements',
    'users',
    'user_sessions',
    'roles',
    'permissions',
    'categories',
    'units',
    'inventory',
    'business_settings',
    'tax_rates',
  };

  final AppDatabase _db;
  final SyncQueueWriter _queueWriter;

  SyncFoundation(AppDatabase db, {SyncQueueWriter? queueWriter})
    : _db = db,
      _queueWriter = queueWriter ?? DefaultSyncQueueWriter(db);

  /// Records a single offline create/update atomically.
  ///
  /// In one transaction it (1) runs [businessWrite] (the caller's insert/update
  /// of the actual business row identified by [documentId] in [table]), (2)
  /// stamps that row with `sync_status = pending` and `local_version`
  /// incremented by one, and (3) inserts exactly one matching `SyncQueue`
  /// entry. If any step fails the transaction rolls back — nothing is persisted
  /// — and an [OfflineWriteFailure] is returned (Req 12.7 / Property 15).
  ///
  /// [businessWrite] MUST NOT set `sync_status` or `local_version`; those
  /// System_Columns are owned and stamped by Sync_Foundation so the increment
  /// stays correct (after k writes `local_version == initial + k`).
  Future<OfflineWriteResult> recordWrite({
    required String table,
    required String documentId,
    required SyncOperationType operationType,
    required Map<String, dynamic> payload,
    required String userId,
    required Future<void> Function() businessWrite,
    String? tenantId,
    String? deviceId,
    String? ownerId,
    int priority = 5,
  }) async {
    // ========================================================================
    // TASK 18.2: READ-ONLY FORENSIC MODE (Local_Store tamper/swap — Req 17.12)
    // ========================================================================
    // When the Security_Layer has detected the Local_Store as swapped or
    // tampered with, the installation is in read-only forensic mode: reads stay
    // permitted but EVERY write is blocked. This is the single offline-write
    // chokepoint, so blocking here covers all callers without UI changes. It is
    // checked BEFORE any Local_Store access so nothing is persisted.
    if (StoreForensicGate.instance.isWriteBlocked) {
      LoggerService.e(
        _logTag,
        'Offline write to $table/$documentId blocked: Local_Store is in '
        'read-only forensic mode (tamper/swap detected).',
      );
      return OfflineWriteFailure(
        stage: 'forensic_read_only',
        message: StoreForensicGate.writeBlockedReason,
      );
    }

    // Confine writes to known System_Columns tables (table names can't be
    // parameterized; this also guards against typos).
    if (!systemColumnTables.contains(table)) {
      LoggerService.e(
        _logTag,
        'Rejected offline write to unknown System_Columns table "$table".',
      );
      return OfflineWriteFailure(
        stage: 'unknown_table',
        message: 'Table "$table" is not a System_Columns table.',
      );
    }

    // Tracks which phase failed so the surfaced failure is actionable. Mutated
    // inside the transaction closure before the error propagates out.
    String stage = 'transaction';

    try {
      final result = await _db.transaction(() async {
        // 1. The caller's business-record write.
        try {
          await businessWrite();
        } catch (e) {
          stage = 'business_write';
          rethrow;
        }

        // 2. Universal System_Columns stamp: pending + local_version + 1
        //    (Req 8.6). tenant_id is set only when provided so the statement
        //    never overwrites an existing value with null.
        try {
          await _stampSystemColumns(
            table: table,
            documentId: documentId,
            tenantId: tenantId,
          );
        } catch (e) {
          stage = 'system_columns';
          rethrow;
        }

        final newLocalVersion = await _readLocalVersion(table, documentId);

        // 3. Exactly one matching SyncQueue entry (Req 12.1, 12.2). Built from
        //    the existing model so the operationId/hash conventions are reused.
        final item = SyncQueueItem.create(
          userId: userId,
          operationType: operationType,
          targetCollection: table,
          documentId: documentId,
          payload: payload,
          priority: priority,
          deviceId: deviceId,
          ownerId: ownerId ?? tenantId ?? userId,
        );

        try {
          await _queueWriter.write(item);
        } catch (e) {
          // Queue insert failed -> persist nothing, surface the failure
          // (Req 12.7). Rethrowing aborts and rolls back the transaction.
          stage = 'sync_queue';
          rethrow;
        }

        return (operationId: item.operationId, localVersion: newLocalVersion);
      });

      LoggerService.i(
        _logTag,
        'Recorded offline ${operationType.value} on $table/$documentId '
        '(local_version=${result.localVersion}, op=${result.operationId}).',
      );
      return OfflineWriteSuccess(
        operationId: result.operationId,
        localVersion: result.localVersion,
      );
    } catch (e, st) {
      LoggerService.e(
        _logTag,
        'Offline write to $table/$documentId rolled back at stage "$stage"; '
        'nothing persisted.',
        e,
        st,
      );
      return OfflineWriteFailure(
        stage: stage,
        message: 'Offline write rolled back at stage "$stage".',
        error: e,
      );
    }
  }

  // ==========================================================================
  // Conflict_Strategy (documented, NOT executed — Req 12.3, 12.4, 12.6)
  // ==========================================================================

  /// The documented per-entity Conflict_Strategy map (Req 12.3).
  ///
  /// Exposed read-only from the foundation so callers and the future
  /// synchronization worker have a single source of truth, while the map stays
  /// a plain constant that is never executed here (Req 12.4).
  Map<SyncEntityClass, ConflictStrategy> get conflictStrategies =>
      ConflictStrategyMap.strategies;

  /// Returns the documented [ConflictStrategy] for [entityClass] (Req 12.3).
  /// This only reports the documented rule — it performs no resolution.
  ConflictStrategy conflictStrategyFor(SyncEntityClass entityClass) =>
      ConflictStrategyMap.strategyFor(entityClass);

  // ==========================================================================
  // Disabled-sync guard (Req 12.4, 12.5 / Property 27)
  // ==========================================================================

  /// Whether synchronization is enabled. It is permanently disabled in this
  /// version (Req 12.4): sync is defined but inert.
  static const bool isSyncEnabled = false;

  /// Blocks any attempt to trigger synchronization (Req 12.5 / Property 27).
  ///
  /// Synchronization is disabled and inert this version, so this guard returns
  /// a [SyncDisabled] indication WITHOUT touching the Local_Store and WITHOUT
  /// running any conflict resolution. It performs no database access at all, so
  /// the store is provably left unchanged. Callers that prefer an exception can
  /// use [triggerSyncOrThrow].
  SyncDisabled triggerSync() {
    LoggerService.w(
      _logTag,
      'Sync trigger blocked: synchronization is disabled this version. '
      'Local_Store left unchanged; no conflict resolution performed.',
    );
    return const SyncDisabled();
  }

  /// Exception-raising form of [triggerSync] (Req 12.5). Throws a catchable
  /// [SyncDisabledException] and, like [triggerSync], never touches the
  /// Local_Store and never runs conflict resolution.
  Never triggerSyncOrThrow() {
    LoggerService.w(
      _logTag,
      'Sync trigger blocked (throwing): synchronization is disabled this '
      'version. Local_Store left unchanged; no conflict resolution performed.',
    );
    throw const SyncDisabledException();
  }

  /// Stamps `sync_status = pending` and increments `local_version` by one for
  /// the row [documentId] in [table] (Req 8.6). COALESCE makes the increment
  /// safe for legacy rows whose `local_version` is still NULL (treated as 0).
  /// All values are bound parameters; only the allow-listed [table] is inlined.
  Future<void> _stampSystemColumns({
    required String table,
    required String documentId,
    String? tenantId,
  }) async {
    if (tenantId != null) {
      await _db.customStatement(
        'UPDATE $table SET sync_status = ?, '
        'local_version = COALESCE(local_version, 0) + 1, '
        'tenant_id = ? WHERE id = ?',
        [pendingSyncStatus, tenantId, documentId],
      );
    } else {
      await _db.customStatement(
        'UPDATE $table SET sync_status = ?, '
        'local_version = COALESCE(local_version, 0) + 1 WHERE id = ?',
        [pendingSyncStatus, documentId],
      );
    }
  }

  /// Reads back the post-increment `local_version` for [documentId] in [table].
  Future<int> _readLocalVersion(String table, String documentId) async {
    final row = await _db
        .customSelect(
          'SELECT local_version AS lv FROM $table WHERE id = ?',
          variables: [Variable<String>(documentId)],
        )
        .getSingleOrNull();
    return row?.read<int?>('lv') ?? 0;
  }
}

// ============================================================================
// Conflict_Strategy (documented, NOT executed — Req 12.3, 12.4, 12.6)
// ============================================================================

/// How a future synchronization worker WILL resolve a conflict for an entity
/// class. These values are documented now so the worker can be added later
/// without changing the Local_Store schema (Req 12.6). They are PURELY
/// DECLARATIVE in this version — nothing in this file (or anywhere else) reads
/// these values to perform conflict resolution (Req 12.4).
enum ConflictStrategy {
  /// The offline (local) write is authoritative; the cloud copy is discarded.
  /// Documented for: sales.
  localWins('local_wins'),

  /// The most recently written copy (by timestamp) is authoritative.
  /// Documented for: inventory.
  lastWriteWins('last_write_wins'),

  /// The cloud copy is authoritative; the local copy is discarded.
  /// Documented for: roles, permissions, user profiles, settings.
  cloudWins('cloud_wins'),

  /// Conflicting fields are merged and the user is prompted to resolve the
  /// remainder. Documented for: product catalog.
  mergeWithPrompt('merge_with_prompt');

  /// Stable, serialization-friendly identifier for the strategy.
  final String value;
  const ConflictStrategy(this.value);
}

/// The entity classes that carry a documented [ConflictStrategy].
///
/// An "entity class" is the business-domain grouping the design's
/// Conflict_Strategy table is written against (e.g. "sales"), which may span
/// more than one physical Local_Store table. Kept separate from raw table
/// names so the documented strategy stays aligned with the design table.
enum SyncEntityClass {
  sales,
  inventory,
  roles,
  permissions,
  userProfiles,
  productCatalog,
  settings,
}

/// The documented per-entity Conflict_Strategy map (Req 12.3).
///
/// Mirrors the design.md "Conflict_Strategy (documented, not executed)" table
/// exactly:
///
/// | Entity class       | Conflict_Strategy |
/// | ------------------ | ----------------- |
/// | sales              | local wins        |
/// | inventory          | last-write-wins   |
/// | roles, permissions | cloud wins        |
/// | user profiles      | cloud wins        |
/// | product catalog    | merge-with-prompt |
/// | settings           | cloud wins        |
///
/// This is a constant lookup table only; it is never consulted to execute a
/// merge or resolution in this version (Req 12.4).
class ConflictStrategyMap {
  ConflictStrategyMap._();

  /// Immutable map from each entity class to its documented strategy.
  static const Map<SyncEntityClass, ConflictStrategy> strategies = {
    SyncEntityClass.sales: ConflictStrategy.localWins,
    SyncEntityClass.inventory: ConflictStrategy.lastWriteWins,
    SyncEntityClass.roles: ConflictStrategy.cloudWins,
    SyncEntityClass.permissions: ConflictStrategy.cloudWins,
    SyncEntityClass.userProfiles: ConflictStrategy.cloudWins,
    SyncEntityClass.productCatalog: ConflictStrategy.mergeWithPrompt,
    SyncEntityClass.settings: ConflictStrategy.cloudWins,
  };

  /// Returns the documented [ConflictStrategy] for [entityClass]. Every
  /// [SyncEntityClass] has an entry, so this is a total function.
  static ConflictStrategy strategyFor(SyncEntityClass entityClass) {
    // The map is exhaustive over the enum; the fallback is unreachable and
    // exists only to keep the return type non-nullable.
    return strategies[entityClass] ?? ConflictStrategy.cloudWins;
  }
}

// ============================================================================
// Disabled-sync guard (Req 12.4, 12.5 / Property 27)
// ============================================================================

/// Outcome of a sync trigger while synchronization is disabled (Req 12.5).
///
/// Synchronization is defined but inert in this version. Any caller that asks
/// the [SyncFoundation] to run sync receives this result (or catches a
/// [SyncDisabledException]); the Local_Store is left completely unchanged and
/// no conflict resolution runs.
class SyncDisabled {
  /// Stable indication that synchronization is disabled.
  static const String code = 'sync_disabled';

  /// Human-readable explanation for logs / the service layer.
  final String message;
  const SyncDisabled([
    this.message =
        'Synchronization is disabled in this version; no sync was performed '
        'and the Local_Store was left unchanged.',
  ]);

  @override
  String toString() => 'SyncDisabled($code): $message';
}

/// Thrown by [SyncFoundation.triggerSyncOrThrow] when a sync trigger is
/// attempted while synchronization is disabled (Req 12.5). It carries the same
/// [SyncDisabled] indication so callers that prefer exceptions get an
/// equivalent, clearly catchable signal.
class SyncDisabledException implements Exception {
  final SyncDisabled indication;
  const SyncDisabledException([this.indication = const SyncDisabled()]);

  String get code => SyncDisabled.code;
  String get message => indication.message;

  @override
  String toString() => 'SyncDisabledException: ${indication.message}';
}
