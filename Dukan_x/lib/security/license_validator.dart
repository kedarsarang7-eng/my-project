// ============================================================================
// LICENSE VALIDATOR — Grace_Period state machine (pure classification surface)
// ============================================================================
// Feature: offline-license-activation (Task 5.1)
//
// The License_Validator performs silent background revalidation of the
// Local_License_File and applies the Grace_Period_State that the rest of the
// app (e.g. `license_invalid_listener.dart`, task 5.3) reacts to.
//
// THIS FILE IMPLEMENTS ONLY THE PURE, DETERMINISTIC CLASSIFICATION (Task 5.1).
// The stateful pieces — the background-validation loop (Task 5.2) and the
// Read_Only/Locked wiring into `license_invalid_listener.dart` (Task 5.3) — are
// declared here as the abstract contract from the design but implemented in
// their own tasks.
//
// Design constraints honoured here:
//   * PURE & DETERMINISTIC. `classify` is a `static` function with no I/O and no
//     clock reads — `now` and `lastValidatedAt` are passed in. This is the
//     "core property surface" the design calls out, so Property 12 (Task 5.4)
//     can drive it with generated inputs.
//   * SERVICE LAYER ONLY. This file imports no Flutter UI/material code.
//   * REUSE, DON'T REBUILD. `driftComponentCount` is the value produced by
//     `MachineFingerprint.differingComponentCount(...)`
//     (lib/core/security/device/device_fingerprint.dart) — the same drift
//     measure used for the same-machine decision (Requirements 6.1/6.2).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';

/// The current license-health state derived from the days elapsed since the
/// last successful validation, plus fingerprint drift and clock state
/// (Requirements 6.3, 7.6–7.11).
///
/// Exactly four states exist by design; they are ordered from most to least
/// permissive: [normal] → [warning] → [readOnly] → [locked].
enum GracePeriodState {
  /// Within the trusted window — full functionality (Requirement 7.6).
  normal,

  /// Renewal window — full functionality, but the user is warned
  /// (Requirement 7.7).
  warning,

  /// Records may be viewed but new bills cannot be created (Requirements 7.8,
  /// 7.9).
  readOnly,

  /// Everything except reactivation is blocked. Reached by exceeding the grace
  /// window, by a clock-tamper detection, or by a new-machine fingerprint drift
  /// (Requirements 6.3, 7.10, 7.11, 7.13).
  locked,
}

/// Performs silent background revalidation of the Local_License_File and
/// exposes the resulting [GracePeriodState].
///
/// The single piece of behaviour that is fully specified and implemented at
/// this point is the pure [classify] function below. The streaming state and
/// the background-validation loop are part of the design contract but are
/// implemented by later tasks (5.2 / 5.3).
abstract class LicenseValidator {
  /// The grace-window day boundaries (inclusive upper bounds), expressed as
  /// whole days elapsed since `lastValidatedAt`. Centralised so the boundary
  /// semantics live in exactly one place.
  ///
  ///   * `daysElapsed <= normalMaxDays (7)`            → [GracePeriodState.normal]
  ///   * `normalMaxDays < daysElapsed <= warningMaxDays (14)`  → [GracePeriodState.warning]
  ///   * `warningMaxDays < daysElapsed <= readOnlyMaxDays (21)`→ [GracePeriodState.readOnly]
  ///   * `daysElapsed > readOnlyMaxDays (21)`          → [GracePeriodState.locked]
  static const int normalMaxDays = 7; // Requirement 7.6
  static const int warningMaxDays = 14; // Requirement 7.7
  static const int readOnlyMaxDays =
      21; // Requirement 7.8 (Locked beyond, 7.10)

  /// Two or more differing fingerprint components mark the installation as a new
  /// machine requiring reactivation (Requirements 6.2, 6.3). At most one
  /// differing component is tolerated as the same machine (Requirement 6.1).
  static const int newMachineDriftThreshold = 2;

  /// Pure, deterministic classification of the Grace_Period_State — the core
  /// property surface (Requirements 6.1, 6.2, 6.3, 7.6, 7.7, 7.8, 7.10, 7.11).
  ///
  /// Inputs (no I/O, no ambient clock — everything is passed in):
  ///   * [now] — the current wall-clock time being evaluated.
  ///   * [lastValidatedAt] — the trusted reference time recorded at the most
  ///     recent successful validation (server-provided `Last_Validated_At`).
  ///   * [driftComponentCount] — the number of Machine_Fingerprint components
  ///     that differ from the activated fingerprint (0..5), i.e. the result of
  ///     `MachineFingerprint.differingComponentCount(...)`.
  ///
  /// Decision order (forced-Locked conditions are evaluated first because they
  /// override the day-based grace window):
  ///   1. `now < lastValidatedAt` → [GracePeriodState.locked]. The clock reports
  ///      a time earlier than the trusted reference, which is treated as clock
  ///      tampering (Requirement 7.11).
  ///   2. `driftComponentCount >= 2` → [GracePeriodState.locked]. Two or more
  ///      components differ, so this is a new machine requiring reactivation
  ///      (Requirements 6.2, 6.3). A drift of 0 or 1 is tolerated as the same
  ///      machine and does NOT force Locked on its own (Requirement 6.1).
  ///   3. Otherwise classify on `daysElapsed`, the number of WHOLE 24-hour
  ///      periods between [lastValidatedAt] and [now]:
  ///        * `daysElapsed <= 7`        → [GracePeriodState.normal]   (Req 7.6)
  ///        * `7 < daysElapsed <= 14`   → [GracePeriodState.warning]  (Req 7.7)
  ///        * `14 < daysElapsed <= 21`  → [GracePeriodState.readOnly] (Req 7.8)
  ///        * `daysElapsed > 21`        → [GracePeriodState.locked]   (Req 7.10)
  ///
  /// Boundary semantics: `daysElapsed` is computed with `Duration.inDays`, which
  /// counts only COMPLETE 24-hour periods (it truncates any partial day). So a
  /// gap of exactly 7 days plus a few seconds still counts as 7 days elapsed and
  /// remains [GracePeriodState.normal]; the state only advances once the next
  /// whole day completes. Because the clock-tamper case (1) already returns for
  /// `now < lastValidatedAt`, the elapsed duration here is always non-negative,
  /// so `inDays` floors a non-negative value (no toward-zero ambiguity remains).
  static GracePeriodState classify({
    required DateTime now,
    required DateTime lastValidatedAt,
    required int driftComponentCount,
  }) {
    // (1) Clock tamper: time earlier than the trusted reference (Req 7.11).
    if (now.isBefore(lastValidatedAt)) {
      return GracePeriodState.locked;
    }

    // (2) New machine: two or more fingerprint components differ (Req 6.2/6.3).
    if (driftComponentCount >= newMachineDriftThreshold) {
      return GracePeriodState.locked;
    }

    // (3) Day-based grace window. `inDays` counts whole 24-hour periods only.
    final int daysElapsed = now.difference(lastValidatedAt).inDays;

    if (daysElapsed <= normalMaxDays) {
      return GracePeriodState.normal; // Req 7.6
    }
    if (daysElapsed <= warningMaxDays) {
      return GracePeriodState.warning; // Req 7.7
    }
    if (daysElapsed <= readOnlyMaxDays) {
      return GracePeriodState.readOnly; // Req 7.8
    }
    return GracePeriodState.locked; // Req 7.10
  }

  /// The live Grace_Period_State stream consumed by the license-invalid wiring.
  ///
  /// Implemented by Task 5.2 / 5.3 (the stateful background-validation loop and
  /// the `license_invalid_listener.dart` wiring). Declared here to keep the
  /// component contract aligned with the design.
  Stream<GracePeriodState> get state;

  /// Runs one silent background revalidation attempt.
  ///
  /// Implemented by Task 5.2 (24h interval, ±5min, 2s per-attempt budget,
  /// async/non-blocking, records the server `Last_Validated_At` on success and
  /// retains state on failure). Declared here for the contract only.
  Future<void> runBackgroundValidation();
}
