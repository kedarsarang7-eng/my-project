// ============================================================================
// v46 MIGRATION — BACKFILL LEGACY 'SYSTEM' OWNER ATTRIBUTION (clinic task 4.4)
// ============================================================================
// Historical clinic writes were attributed to the literal placeholder owner id
// 'SYSTEM' (tasks 4.2/4.3 fixed NEW writes to use the real session owner id).
// This module re-attributes the EXISTING 'SYSTEM' rows to the correct owner.
//
// WHAT IS BACKFILLED (only columns that actually STORE 'SYSTEM'):
//   1. patients.user_id == 'SYSTEM'   → the real owner id.
//        The `patients` table stores the tenant owner in `user_id`; the old
//        PatientRepository wrote 'SYSTEM' there.
//   2. sync_queue rows for the 'patients' / 'appointments' collections whose
//      user_id == 'SYSTEM'  → the real owner id (both user_id and owner_id).
//        The `appointments` table has NO owner column (it scopes by doctorId /
//        patientId), so there is NOTHING to backfill on that table. The ONLY
//        place an appointment's 'SYSTEM' attribution was persisted is the
//        enqueued sync op (old AppointmentRepository enqueued userId: 'SYSTEM').
//        Those pending sync rows are therefore the "appointment-related sync"
//        the task refers to.
//
// WHAT IS LEFT UNTOUCHED:
//   • Any patient/sync row that already carries a real (non-'SYSTEM') owner id.
//     The UPDATEs match `= 'SYSTEM'` exactly, so a real owner id is never
//     rewritten — no data loss, no silent re-attribution of correct rows.
//
// FAIL-SAFE GUARD (no fabrication):
//   • If the resolved owner id is null / blank / itself 'SYSTEM', the backfill
//     SKIPS entirely and reports the reason. It NEVER invents an owner id and
//     NEVER buckets anything (further) under 'SYSTEM'. Aligns with the
//     owner_id_resolver fail-safe contract (task 4.2).
//
// ⚠️ MULTI-OWNER-ON-ONE-DEVICE CAVEAT (requires sign-off):
//   On a single-device, local-first install the re-attribution target is the
//   CURRENT authenticated owner. If TWO different owners ever used the SAME
//   device and BOTH produced 'SYSTEM'-attributed rows, this backfill cannot
//   distinguish them — it attributes ALL legacy 'SYSTEM' rows to whichever
//   owner is signed in when it runs. That is correct for the overwhelmingly
//   common single-owner-per-device case and strictly better than leaving rows
//   unattributed, but it is a documented limitation flagged for sign-off.
// ============================================================================

import 'package:drift/drift.dart';

/// The legacy placeholder owner id that this migration re-attributes away from.
const String kSystemOwnerSentinel = 'SYSTEM';

/// Sync-queue target collections whose 'SYSTEM'-attributed rows are backfilled.
/// `appointments` is included here (not as a stored table column) because its
/// only 'SYSTEM' attribution lived on the enqueued sync op.
const List<String> kBackfilledSyncCollections = <String>[
  'patients',
  'appointments',
];

/// Outcome of a backfill attempt — used for diagnostics / test assertions.
class SystemOwnerBackfillResult {
  /// True when the backfill ran; false when it was skipped (fail-safe guard).
  final bool ran;

  /// Why the backfill was skipped (null when it ran).
  final String? skippedReason;

  /// Number of `patients` rows re-attributed from 'SYSTEM' to the owner id.
  final int patientRowsReattributed;

  /// Number of pending `sync_queue` rows re-attributed from 'SYSTEM'.
  final int syncOpsReattributed;

  const SystemOwnerBackfillResult.skipped(this.skippedReason)
    : ran = false,
      patientRowsReattributed = 0,
      syncOpsReattributed = 0;

  const SystemOwnerBackfillResult.applied({
    required this.patientRowsReattributed,
    required this.syncOpsReattributed,
  }) : ran = true,
       skippedReason = null;

  /// Total rows re-attributed across all backfilled targets.
  int get totalReattributed => patientRowsReattributed + syncOpsReattributed;

  String get summary => ran
      ? 'applied (patients=$patientRowsReattributed, '
            'syncOps=$syncOpsReattributed)'
      : 'skipped ($skippedReason)';
}

/// Re-attributes legacy `'SYSTEM'` rows to [ownerId].
///
/// Pure with respect to its inputs (the executor + owner id) so it is trivially
/// unit-testable against an in-memory database. Idempotent: once no 'SYSTEM'
/// rows remain, re-running is a harmless no-op that reports zero rows.
///
/// Returns a [SystemOwnerBackfillResult]. Skips (without throwing) when
/// [ownerId] is null / blank / itself the 'SYSTEM' sentinel, so callers can run
/// it safely even when no authenticated owner is available.
Future<SystemOwnerBackfillResult> backfillSystemOwnerRows(
  GeneratedDatabase db, {
  required String? ownerId,
}) async {
  final resolved = ownerId?.trim() ?? '';

  // --- Fail-safe guard: never fabricate an owner; never re-bucket 'SYSTEM'. --
  if (resolved.isEmpty) {
    return const SystemOwnerBackfillResult.skipped(
      'no authenticated owner id available at backfill time',
    );
  }
  if (resolved == kSystemOwnerSentinel) {
    return const SystemOwnerBackfillResult.skipped(
      'resolved owner id is the SYSTEM sentinel',
    );
  }

  // Single transaction so the patient + sync backfills are atomic. Drift maps a
  // nested transaction (when invoked from inside the migrator) onto a SAVEPOINT.
  return db.transaction(() async {
    // 1. patients.user_id == 'SYSTEM' → real owner id.
    final patientRows = await db.customUpdate(
      'UPDATE patients SET user_id = ? WHERE user_id = ?',
      variables: [
        Variable<String>(resolved),
        Variable<String>(kSystemOwnerSentinel),
      ],
      updateKind: UpdateKind.update,
    );

    // 2. Pending sync ops for patients/appointments attributed to 'SYSTEM' →
    //    real owner id (both the legacy user_id and the explicit owner_id).
    final placeholders = List.filled(
      kBackfilledSyncCollections.length,
      '?',
    ).join(', ');
    final syncRows = await db.customUpdate(
      'UPDATE sync_queue SET user_id = ?, owner_id = ? '
      'WHERE user_id = ? AND target_collection IN ($placeholders)',
      variables: [
        Variable<String>(resolved),
        Variable<String>(resolved),
        Variable<String>(kSystemOwnerSentinel),
        ...kBackfilledSyncCollections.map((c) => Variable<String>(c)),
      ],
      updateKind: UpdateKind.update,
    );

    return SystemOwnerBackfillResult.applied(
      patientRowsReattributed: patientRows,
      syncOpsReattributed: syncRows,
    );
  });
}

/// Cheap existence check: is there any legacy 'SYSTEM' row still pending
/// backfill? Used by the deferred (on-open) retry so the retry is effectively a
/// no-op once the backfill has completed.
Future<bool> hasPendingSystemOwnerRows(GeneratedDatabase db) async {
  final placeholders = List.filled(
    kBackfilledSyncCollections.length,
    '?',
  ).join(', ');
  final row = await db
      .customSelect(
        'SELECT ('
        '  EXISTS(SELECT 1 FROM patients WHERE user_id = ?) OR '
        '  EXISTS(SELECT 1 FROM sync_queue WHERE user_id = ? '
        '         AND target_collection IN ($placeholders))'
        ') AS pending',
        variables: [
          Variable<String>(kSystemOwnerSentinel),
          Variable<String>(kSystemOwnerSentinel),
          ...kBackfilledSyncCollections.map((c) => Variable<String>(c)),
        ],
      )
      .getSingle();
  return (row.data['pending'] as int? ?? 0) != 0;
}
