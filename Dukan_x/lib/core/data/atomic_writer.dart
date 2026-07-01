// AtomicWriter — central wrapper for multi-step writes that must commit
// across local store + remote backend + provider invalidation, with
// rollback on partial failure.
//
// Per `bugfix.md` clause 2.7, every mutation path must produce a single
// observable outcome across the three views of the same entity. Per
// clause 2.8, dependent screens reopened after a write must see fresh
// data via correct invalidation. Today many feature services (see
// `delivery_challan_service.dart`) hand-roll their own try/catch +
// stock-rollback ladders. `AtomicWriter.run` factors that pattern into
// one helper so every D4 fix can opt in without copying the ladder.
//
// Usage:
//
//     await AtomicWriter.run(
//       label: 'billing.create_bill',
//       local: () => _db.insertBill(bill),
//       compensateLocal: () => _db.deleteBill(bill.id),
//       remote: () => _api.postBill(bill),
//       compensateRemote: () => _api.deleteBill(bill.id),
//       invalidate: () {
//         ref.invalidate(billsProvider);
//         ref.invalidate(dashboardSummaryProvider);
//       },
//     );
//
// Semantics:
//   1. `local()` runs first. If it throws, nothing else runs.
//   2. `remote()` runs next. If it throws, `compensateLocal()` is invoked
//      to undo step 1, then the original error is rethrown as a typed
//      `AtomicWriteFailure`.
//   3. `invalidate()` runs only after both writes succeed. If it throws,
//      the writes still stand (data is consistent) but a structured log
//      records the invalidation failure so dependent screens can be
//      forced to refresh later. We do not roll back already-committed
//      writes for an invalidation glitch.
//
// `compensateLocal` and `compensateRemote` are optional. If absent and
// the corresponding step needs rolling back, the failure is rethrown
// with `partial: true` so callers know cleanup is owed.
//
// This helper is intentionally provider-agnostic — `invalidate` is a
// callback the caller supplies, so Riverpod, Bloc and ChangeNotifier
// users can all share the rollback ladder.

import 'dart:async';
import 'dart:developer' as developer;

/// Typed failure surface for any multi-step write wrapped by
/// `AtomicWriter.run`. Callers catch `AtomicWriteFailure` to inspect
/// `step` (which phase failed) and `partial` (whether already-committed
/// state was successfully rolled back).
class AtomicWriteFailure implements Exception {
  AtomicWriteFailure({
    required this.label,
    required this.step,
    required this.cause,
    required this.stackTrace,
    required this.partial,
  });

  /// Stable label for the failing operation, e.g. `billing.create_bill`.
  final String label;

  /// Which phase failed: `local`, `remote`, `compensateLocal`,
  /// `compensateRemote`, or `invalidate`.
  final AtomicWriteStep step;

  /// The original error or exception that was thrown.
  final Object cause;

  /// Captured stack trace for structured logs.
  final StackTrace stackTrace;

  /// True when one of the writes succeeded but its compensator failed
  /// (or was absent), so the system is in a partially-committed state
  /// the caller must reconcile.
  final bool partial;

  @override
  String toString() =>
      'AtomicWriteFailure($label/$step, partial=$partial): $cause';
}

/// Phase in the atomic write ladder. Surfaced on `AtomicWriteFailure`
/// so callers can branch on which step failed.
enum AtomicWriteStep {
  local,
  remote,
  compensateLocal,
  compensateRemote,
  invalidate,
}

/// Central runner for multi-step writes that must be atomic across local
/// store, remote backend and provider invalidation.
class AtomicWriter {
  AtomicWriter._();

  /// Run a multi-step write with rollback on partial failure.
  ///
  /// The signature is intentionally explicit: every caller must name the
  /// operation (`label`), write locally and remotely, and invalidate
  /// dependent providers. Compensators are optional but strongly
  /// recommended — without them a remote failure leaves the local store
  /// dirty and `partial=true` is rethrown.
  static Future<T> run<T>({
    required String label,
    required Future<T> Function() local,
    required Future<void> Function() remote,
    required void Function() invalidate,
    Future<void> Function()? compensateLocal,
    Future<void> Function()? compensateRemote,
  }) async {
    late T localResult;

    // Phase 1 — local write.
    try {
      localResult = await local();
    } catch (e, st) {
      _log(label, AtomicWriteStep.local, e, st);
      throw AtomicWriteFailure(
        label: label,
        step: AtomicWriteStep.local,
        cause: e,
        stackTrace: st,
        partial: false,
      );
    }

    // Phase 2 — remote write. Compensate local on failure.
    try {
      await remote();
    } catch (e, st) {
      _log(label, AtomicWriteStep.remote, e, st);
      var partial = compensateLocal == null;
      if (compensateLocal != null) {
        try {
          await compensateLocal();
        } catch (rollbackErr, rollbackSt) {
          _log(label, AtomicWriteStep.compensateLocal, rollbackErr, rollbackSt);
          partial = true;
        }
      }
      throw AtomicWriteFailure(
        label: label,
        step: AtomicWriteStep.remote,
        cause: e,
        stackTrace: st,
        partial: partial,
      );
    }

    // Phase 3 — provider invalidation. Writes already stand, so a
    // failure here does not roll back; it is surfaced as a non-fatal
    // log + a non-partial AtomicWriteFailure.
    try {
      invalidate();
    } catch (e, st) {
      _log(label, AtomicWriteStep.invalidate, e, st);
      throw AtomicWriteFailure(
        label: label,
        step: AtomicWriteStep.invalidate,
        cause: e,
        stackTrace: st,
        partial: false,
      );
    }

    return localResult;
  }

  static void _log(
    String label,
    AtomicWriteStep step,
    Object e,
    StackTrace st,
  ) {
    developer.log(
      'Atomic write failure in $label at $step: $e',
      name: 'AtomicWriter',
      error: e,
      stackTrace: st,
    );
  }
}
