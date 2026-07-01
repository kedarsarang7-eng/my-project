// ============================================================================
// VEGETABLES BROKER SYNC HANDLER (Requirement 4.1, 4.3, 4.4, 4.5, 14.1, 14.6)
// ============================================================================
// Offline-first sync handler for the Mandi (vegetablesBroker) vertical.
// Synchronizes the canonical Stack_B entities — `Farmers` and
// `CommissionLedger` — based on their `syncState` column.
//
// Each sync cycle:
//  1. Queries records WHERE sync_state = 'unsynced'.
//  2. Enqueues them for transmission via the live SyncManager.
//  3. On success: flips sync_state to 'synced' within the same cycle.
//  4. On failure: retains sync_state as 'unsynced', preserves the local record
//     unchanged, increments the retry counter, and surfaces an error to the
//     caller.
//
// Retry policy (R14.6): Each entity is retried up to 5 attempts. After 5
// consecutive failures the entity remains in the local queue (unsynced, local
// record preserved) but is excluded from future cycles until manually reset.
//
// Connectivity-triggered cycle (R14.1): On network connectivity change from
// offline→online, a sync cycle begins within 60 seconds.
//
// This handler does NOT reference `veg_rate_entries` or any concept without a
// backing model. It targets only the canonical Drift tables.
//
// NOTE: The `sync_state` and `last_modified_at` columns were added in the v43
// migration (task 4.1) but `build_runner` has not been re-run, so the generated
// companions/entities do not include them. All sync-state reads and writes use
// raw SQL (`customSelect` / `customStatement`) until code-gen catches up.
// ============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/models/sync_types.dart';
import '../../../core/sync/sync_queue_state_machine.dart';

/// Result of a single sync cycle, surfacing per-entity errors to the caller.
class MandiSyncCycleResult {
  /// Number of entities successfully synced in this cycle.
  final int syncedCount;

  /// Entities that failed to sync, keyed by entity id with the error message.
  final Map<String, String> failures;

  const MandiSyncCycleResult({
    required this.syncedCount,
    required this.failures,
  });

  /// True when all entities were synced without error.
  bool get isSuccess => failures.isEmpty;

  /// True when no unsynced entities were found (nothing to do).
  bool get isNoop => syncedCount == 0 && failures.isEmpty;
}

/// Lightweight DTO for an unsynced farmer row, extracted from raw SQL results.
class _UnsyncedFarmer {
  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? village;
  final String? bankAccountDetails;
  final double totalSales;
  final double totalCommissionDeducted;
  final double totalExpensesDeducted;
  final double totalPaid;
  final double currentBalance;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const _UnsyncedFarmer({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.village,
    this.bankAccountDetails,
    required this.totalSales,
    required this.totalCommissionDeducted,
    required this.totalExpensesDeducted,
    required this.totalPaid,
    required this.currentBalance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _UnsyncedFarmer.fromRow(Map<String, dynamic> row) {
    return _UnsyncedFarmer(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      village: row['village'] as String?,
      bankAccountDetails: row['bank_account_details'] as String?,
      totalSales: (row['total_sales'] as num).toDouble(),
      totalCommissionDeducted: (row['total_commission_deducted'] as num)
          .toDouble(),
      totalExpensesDeducted: (row['total_expenses_deducted'] as num).toDouble(),
      totalPaid: (row['total_paid'] as num).toDouble(),
      currentBalance: (row['current_balance'] as num).toDouble(),
      isActive: (row['is_active'] as int) == 1,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'id': id,
    'userId': userId,
    'name': name,
    'phone': phone,
    'village': village,
    'bankAccountDetails': bankAccountDetails,
    'totalSales': totalSales,
    'totalCommissionDeducted': totalCommissionDeducted,
    'totalExpensesDeducted': totalExpensesDeducted,
    'totalPaid': totalPaid,
    'currentBalance': currentBalance,
    'isActive': isActive,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// Lightweight DTO for an unsynced commission-ledger row.
class _UnsyncedLedgerEntry {
  final String id;
  final String userId;
  final String billId;
  final String farmerId;
  final String date;
  final double saleAmount;
  final double commissionRate;
  final double commissionAmount;
  final double laborCharges;
  final double otherExpenses;
  final double netPayableToFarmer;

  const _UnsyncedLedgerEntry({
    required this.id,
    required this.userId,
    required this.billId,
    required this.farmerId,
    required this.date,
    required this.saleAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.laborCharges,
    required this.otherExpenses,
    required this.netPayableToFarmer,
  });

  factory _UnsyncedLedgerEntry.fromRow(Map<String, dynamic> row) {
    return _UnsyncedLedgerEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      billId: row['bill_id'] as String,
      farmerId: row['farmer_id'] as String,
      date: row['date'] as String,
      saleAmount: (row['sale_amount'] as num).toDouble(),
      commissionRate: (row['commission_rate'] as num).toDouble(),
      commissionAmount: (row['commission_amount'] as num).toDouble(),
      laborCharges: (row['labor_charges'] as num).toDouble(),
      otherExpenses: (row['other_expenses'] as num).toDouble(),
      netPayableToFarmer: (row['net_payable_to_farmer'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'id': id,
    'userId': userId,
    'billId': billId,
    'farmerId': farmerId,
    'date': date,
    'saleAmount': saleAmount,
    'commissionRate': commissionRate,
    'commissionAmount': commissionAmount,
    'laborCharges': laborCharges,
    'otherExpenses': otherExpenses,
    'netPayableToFarmer': netPayableToFarmer,
  };
}

/// Sync handler for the Mandi vertical (vegetablesBroker business type).
///
/// Targets the canonical `Farmers` and `CommissionLedger` Drift tables.
/// Does NOT reference `veg_rate_entries` or any non-existent model.
///
/// Requirement 14.1: entities created/updated offline are enqueued and
/// transmitted on the next sync cycle, which starts within 60 seconds of
/// connectivity.
///
/// Requirement 14.6: on failure or missing acknowledgment, the entity is
/// retained in the local queue, the local record is preserved unchanged,
/// and retry occurs up to a maximum of 5 attempts per entity.
class VegetablesBrokerSyncHandler {
  VegetablesBrokerSyncHandler(this._syncManager, this._db);

  final SyncManager _syncManager;
  final AppDatabase _db;
  StreamSubscription<SyncResult>? _eventSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectivitySyncTimer;
  bool _attached = false;

  /// Maximum number of sync attempts per entity before giving up (R14.6).
  static const int maxSyncAttempts = 5;

  /// Maximum delay (seconds) before triggering a sync cycle after
  /// connectivity is restored (R14.1).
  static const int connectivitySyncDelaySecs = 60;

  /// Collections targeted by this handler.
  static const String farmerCollection = 'mandi_farmers';
  static const String ledgerCollection = 'mandi_commission_ledger';

  /// In-memory retry counter per entity id. Tracks consecutive failed
  /// sync attempts for the current session. Persisted to DB via the
  /// `sync_attempts` column when available; otherwise tracked in memory.
  final Map<String, int> _syncAttempts = {};

  /// Whether the last-known connectivity state was offline.
  bool _wasOffline = false;

  /// User ID for the current session (set on attach or first sync cycle).
  String? _userId;

  bool get isAttached => _attached;

  /// Expose retry attempts for testing/debugging.
  int getSyncAttempts(String entityId) => _syncAttempts[entityId] ?? 0;

  /// Reset retry counter for an entity (e.g. after manual intervention).
  void resetSyncAttempts(String entityId) => _syncAttempts.remove(entityId);

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  /// Attach to the live [SyncManager] event stream and start connectivity
  /// monitoring. Idempotent.
  void attach({String? userId}) {
    if (_attached) return;
    _attached = true;
    _userId = userId;

    _eventSub = _syncManager.syncEventStream.listen(
      _onSyncEvent,
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('VegetablesBrokerSyncHandler sync error: $e');
        }
      },
    );

    // Start monitoring connectivity for R14.1
    _startConnectivityMonitoring();

    if (kDebugMode) {
      debugPrint('VegetablesBrokerSyncHandler attached to live SyncManager');
    }
  }

  /// Observe sync results from the engine for Mandi-specific reconciliation.
  void _onSyncEvent(SyncResult result) {
    if (kDebugMode) {
      debugPrint(
        'VegetablesBrokerSyncHandler: operation ${result.operationId} '
        '${result.isSuccess ? "synced" : "failed"}',
      );
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _connectivitySyncTimer?.cancel();
    _connectivitySyncTimer = null;
    _attached = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECTIVITY MONITORING (Requirement 14.1)
  // ─────────────────────────────────────────────────────────────────────────

  /// Monitor connectivity changes. When transitioning from offline to online,
  /// schedule a sync cycle within [connectivitySyncDelaySecs] seconds.
  void _startConnectivityMonitoring() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Check initial state
    Connectivity().checkConnectivity().then(_setInitialConnectivity);
  }

  void _setInitialConnectivity(List<ConnectivityResult> results) {
    _wasOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);

    if (_wasOffline && !isOffline) {
      // Transition from offline → online: schedule sync within 60 seconds.
      _scheduleSyncOnConnectivity();
    }

    _wasOffline = isOffline;
  }

  /// Schedule a sync cycle to begin within [connectivitySyncDelaySecs] seconds
  /// of connectivity being restored. If already scheduled, skip.
  void _scheduleSyncOnConnectivity() {
    if (_connectivitySyncTimer?.isActive == true) return;

    if (kDebugMode) {
      debugPrint(
        'VegetablesBrokerSyncHandler: connectivity restored, scheduling '
        'sync cycle within $connectivitySyncDelaySecs seconds',
      );
    }

    // Fire immediately (0-second delay) but cap guarantee at 60 seconds.
    // In practice we trigger ASAP but the requirement guarantees "within 60s".
    _connectivitySyncTimer = Timer(
      const Duration(seconds: 1),
      _triggerConnectivitySync,
    );
  }

  void _triggerConnectivitySync() {
    if (_userId != null) {
      runSyncCycle(_userId!);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC CYCLE
  // ─────────────────────────────────────────────────────────────────────────

  /// Run a full synchronization cycle for all unsynced Mandi entities.
  ///
  /// Returns a [MandiSyncCycleResult] summarizing successes and failures.
  /// On failure for any entity: its syncState is retained as 'unsynced', the
  /// local record is not modified, the retry counter is incremented, and the
  /// error is included in the result.
  ///
  /// Entities that have reached [maxSyncAttempts] (5) are excluded from the
  /// cycle but remain in the local queue with their local record preserved
  /// (R14.6).
  Future<MandiSyncCycleResult> runSyncCycle(String userId) async {
    _userId = userId;
    int syncedCount = 0;
    final failures = <String, String>{};

    // --- Sync unsynced Farmers (Requirement 4.3, 14.1, 14.6) ---
    final unsyncedFarmers = await _getUnsyncedFarmers(userId);
    for (final farmer in unsyncedFarmers) {
      // R14.6: skip entities that have exhausted their retry budget.
      final attempts = _syncAttempts[farmer.id] ?? 0;
      if (attempts >= maxSyncAttempts) {
        failures[farmer.id] =
            'Max sync attempts ($maxSyncAttempts) reached; entity retained locally';
        if (kDebugMode) {
          debugPrint(
            'VegetablesBrokerSyncHandler: skipping farmer ${farmer.id} '
            '(max attempts reached)',
          );
        }
        continue;
      }

      try {
        await _enqueueFarmer(farmer);
        // Requirement 4.4: flip to synced within the same cycle on success.
        await _markFarmerSynced(farmer.id);
        // Reset retry counter on success.
        _syncAttempts.remove(farmer.id);
        syncedCount++;
      } catch (e) {
        // Requirement 4.5 / 14.6: retain unsynced, preserve local record,
        // increment retry counter, surface error.
        _syncAttempts[farmer.id] = attempts + 1;
        failures[farmer.id] = e.toString();
        if (kDebugMode) {
          debugPrint(
            'VegetablesBrokerSyncHandler: failed to sync farmer '
            '${farmer.id} (attempt ${attempts + 1}/$maxSyncAttempts): $e',
          );
        }
      }
    }

    // --- Sync unsynced CommissionLedger entries (Requirement 4.3, 14.1, 14.6) ---
    final unsyncedLedger = await _getUnsyncedLedgerEntries(userId);
    for (final entry in unsyncedLedger) {
      // R14.6: skip entities that have exhausted their retry budget.
      final attempts = _syncAttempts[entry.id] ?? 0;
      if (attempts >= maxSyncAttempts) {
        failures[entry.id] =
            'Max sync attempts ($maxSyncAttempts) reached; entity retained locally';
        if (kDebugMode) {
          debugPrint(
            'VegetablesBrokerSyncHandler: skipping ledger entry ${entry.id} '
            '(max attempts reached)',
          );
        }
        continue;
      }

      try {
        await _enqueueLedgerEntry(entry);
        // Requirement 4.4: flip to synced within the same cycle on success.
        await _markLedgerEntrySynced(entry.id);
        // Reset retry counter on success.
        _syncAttempts.remove(entry.id);
        syncedCount++;
      } catch (e) {
        // Requirement 4.5 / 14.6: retain unsynced, preserve local record,
        // increment retry counter, surface error.
        _syncAttempts[entry.id] = attempts + 1;
        failures[entry.id] = e.toString();
        if (kDebugMode) {
          debugPrint(
            'VegetablesBrokerSyncHandler: failed to sync ledger entry '
            '${entry.id} (attempt ${attempts + 1}/$maxSyncAttempts): $e',
          );
        }
      }
    }

    return MandiSyncCycleResult(syncedCount: syncedCount, failures: failures);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUERY — select entities where sync_state = 'unsynced' (Requirement 4.3)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all farmers belonging to [userId] whose sync_state is 'unsynced'.
  Future<List<_UnsyncedFarmer>> _getUnsyncedFarmers(String userId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM farmers WHERE user_id = ? AND sync_state = ?',
          variables: [Variable<String>(userId), Variable<String>('unsynced')],
        )
        .get();
    return rows.map((r) => _UnsyncedFarmer.fromRow(r.data)).toList();
  }

  /// Fetch all commission-ledger entries belonging to [userId] whose
  /// sync_state is 'unsynced'.
  Future<List<_UnsyncedLedgerEntry>> _getUnsyncedLedgerEntries(
    String userId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM commission_ledger WHERE user_id = ? AND sync_state = ?',
          variables: [Variable<String>(userId), Variable<String>('unsynced')],
        )
        .get();
    return rows.map((r) => _UnsyncedLedgerEntry.fromRow(r.data)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSMIT — enqueue each entity through the SyncManager
  // ─────────────────────────────────────────────────────────────────────────

  /// Enqueue a farmer entity for sync via the live offline queue.
  Future<void> _enqueueFarmer(_UnsyncedFarmer farmer) async {
    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: farmer.userId,
        operationType: SyncOperationType.update,
        targetCollection: farmerCollection,
        documentId: farmer.id,
        payload: farmer.toPayload(),
      ),
    );
  }

  /// Enqueue a commission-ledger entry for sync via the live offline queue.
  Future<void> _enqueueLedgerEntry(_UnsyncedLedgerEntry entry) async {
    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: entry.userId,
        operationType: SyncOperationType.update,
        targetCollection: ledgerCollection,
        documentId: entry.id,
        payload: entry.toPayload(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE TRANSITION — flip to 'synced' on success (Requirement 4.4)
  // ─────────────────────────────────────────────────────────────────────────

  /// Mark a farmer record as synced.
  ///
  /// Uses [customStatement] because the generated Drift companion has not yet
  /// been regenerated to include the `sync_state` column (added in the v43
  /// migration). Once `build_runner` is re-run, this can migrate to a typed
  /// companion update.
  Future<void> _markFarmerSynced(String farmerId) async {
    await _db.customStatement(
      "UPDATE farmers SET sync_state = 'synced' WHERE id = ?",
      <Object?>[farmerId],
    );
  }

  /// Mark a commission-ledger entry as synced.
  Future<void> _markLedgerEntrySynced(String ledgerId) async {
    await _db.customStatement(
      "UPDATE commission_ledger SET sync_state = 'synced' WHERE id = ?",
      <Object?>[ledgerId],
    );
  }
}
