// AUDIT_SYSTEM — LICENSE-ACTIVATION CACHE CLASSIFIERS (Task 14.1)
//
// Pure decision logic for the per-screen verification of license-gated
// Offline_Mode. Two independent classifiers live here:
//
//   1. Cache validity (Req 8.1, 8.5) — given a cached License_Activation state
//      described by `(present, ageDays, integrityValid)`, decide whether
//      Offline_Mode is available or must be denied with a re-activation prompt.
//
//   2. Activation lockout (Req 8.7) — given `(consecutiveFailures,
//      secondsSinceLastFailure)`, decide whether further activation attempts are
//      blocked within the 60-second lockout window after 5 consecutive failures.
//
// The underlying activation mechanism (Cognito/Lambda verification, encrypted
// persistence) is owned by the sibling `offline-license-activation` spec; this
// file is referenced conceptually but NOT imported. These classifiers only
// model the verification that the mechanism's rules were applied correctly.
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 14.1)
// _Requirements: 8.1, 8.5, 8.7_

/// The validity period, in days, of a cached License_Activation. A cached
/// activation strictly older than this many days is treated as expired
/// (Req 8.5).
const int kActivationValidityDays = 30;

/// The number of consecutive activation failures that triggers a lockout
/// (Req 8.7).
const int kLockoutFailureThreshold = 5;

/// The duration, in seconds, that further activation attempts are blocked once
/// the failure threshold is reached (Req 8.7).
const int kLockoutWindowSeconds = 60;

/// Whether Offline_Mode is available on the current Screen, based on the cached
/// License_Activation state.
enum OfflineAccessDecision {
  /// A valid cached activation exists; Offline_Mode is available.
  available,

  /// No valid cached activation; Offline_Mode is denied and the Screen prompts
  /// for re-activation (Req 8.5).
  deniedPromptReactivation,
}

/// The reason a cached activation was rejected. [valid] means the cache passed
/// every check; the remaining values each force re-activation (Req 8.5).
enum CacheRejectionReason {
  /// The cache is valid — Offline_Mode is available.
  valid,

  /// No cached activation is present.
  absent,

  /// The cached activation is older than its 30-day validity period.
  expired,

  /// The cached activation failed integrity validation.
  integrityFailed,
}

/// The outcome of evaluating a cached License_Activation state.
class CacheValidityResult {
  CacheValidityResult({required this.decision, required this.reason});

  /// Whether Offline_Mode is available or denied.
  final OfflineAccessDecision decision;

  /// Why the cache was accepted or rejected.
  final CacheRejectionReason reason;

  /// True iff Offline_Mode is available (cache is valid).
  bool get isAvailable => decision == OfflineAccessDecision.available;

  /// True iff Offline_Mode is denied and re-activation is prompted.
  bool get promptsReactivation =>
      decision == OfflineAccessDecision.deniedPromptReactivation;

  @override
  String toString() => 'CacheValidityResult(${decision.name}, ${reason.name})';
}

/// Pure classifier for cached License_Activation validity (Req 8.1, 8.5).
///
/// Offline_Mode is denied (and re-activation prompted) **if and only if** the
/// cached activation is absent, older than [kActivationValidityDays], or fails
/// integrity validation. Otherwise Offline_Mode is available.
class LicenseCacheClassifier {
  const LicenseCacheClassifier({this.validityDays = kActivationValidityDays});

  /// The validity window in days (defaults to 30).
  final int validityDays;

  /// Classify a cached activation described by pure values.
  ///
  /// * [present] — whether any cached activation exists.
  /// * [ageDays] — age of the cached activation in whole days (ignored when
  ///   [present] is false).
  /// * [integrityValid] — whether the cached activation passed integrity
  ///   validation (ignored when [present] is false).
  CacheValidityResult classify({
    required bool present,
    required int ageDays,
    required bool integrityValid,
  }) {
    final reason = _rejectionReason(
      present: present,
      ageDays: ageDays,
      integrityValid: integrityValid,
    );
    final decision = reason == CacheRejectionReason.valid
        ? OfflineAccessDecision.available
        : OfflineAccessDecision.deniedPromptReactivation;
    return CacheValidityResult(decision: decision, reason: reason);
  }

  /// True iff the cached state grants Offline_Mode access.
  bool isOfflineAvailable({
    required bool present,
    required int ageDays,
    required bool integrityValid,
  }) {
    return classify(
      present: present,
      ageDays: ageDays,
      integrityValid: integrityValid,
    ).isAvailable;
  }

  CacheRejectionReason _rejectionReason({
    required bool present,
    required int ageDays,
    required bool integrityValid,
  }) {
    if (!present) return CacheRejectionReason.absent;
    if (ageDays > validityDays) return CacheRejectionReason.expired;
    if (!integrityValid) return CacheRejectionReason.integrityFailed;
    return CacheRejectionReason.valid;
  }
}

/// Whether further activation attempts are currently permitted (Req 8.7).
enum LockoutDecision {
  /// Activation attempts are allowed.
  allowed,

  /// The attempt limit was reached; attempts are blocked within the 60-second
  /// window and an attempt-limit error is surfaced.
  blockedAttemptLimit,
}

/// The outcome of evaluating activation lockout state.
class LockoutResult {
  LockoutResult({required this.decision});

  /// Whether attempts are allowed or blocked.
  final LockoutDecision decision;

  /// True iff further activation attempts are currently blocked.
  bool get isBlocked => decision == LockoutDecision.blockedAttemptLimit;

  @override
  String toString() => 'LockoutResult(${decision.name})';
}

/// Pure classifier for activation lockout after consecutive failures (Req 8.7).
///
/// Once activation has failed [kLockoutFailureThreshold] consecutive times,
/// further attempts are blocked for the [kLockoutWindowSeconds]-second window.
/// A success before the 5th consecutive failure resets the counter (modeled by
/// the caller passing the current consecutive-failure count).
class ActivationLockoutClassifier {
  const ActivationLockoutClassifier({
    this.failureThreshold = kLockoutFailureThreshold,
    this.windowSeconds = kLockoutWindowSeconds,
  });

  /// Consecutive failures required to trigger a lockout (defaults to 5).
  final int failureThreshold;

  /// Lockout duration in seconds (defaults to 60).
  final int windowSeconds;

  /// Classify lockout state from pure values.
  ///
  /// * [consecutiveFailures] — number of consecutive activation failures (a
  ///   success resets this to 0 before this call).
  /// * [secondsSinceLastFailure] — elapsed seconds since the most recent
  ///   failure.
  ///
  /// Attempts are blocked **iff** the failure count has reached the threshold
  /// and the elapsed time is still within the lockout window. Once the window
  /// elapses, attempts are allowed again.
  LockoutResult classify({
    required int consecutiveFailures,
    required int secondsSinceLastFailure,
  }) {
    final blocked =
        consecutiveFailures >= failureThreshold &&
        secondsSinceLastFailure < windowSeconds;
    return LockoutResult(
      decision: blocked
          ? LockoutDecision.blockedAttemptLimit
          : LockoutDecision.allowed,
    );
  }

  /// True iff further activation attempts are currently blocked.
  bool isBlocked({
    required int consecutiveFailures,
    required int secondsSinceLastFailure,
  }) {
    return classify(
      consecutiveFailures: consecutiveFailures,
      secondsSinceLastFailure: secondsSinceLastFailure,
    ).isBlocked;
  }
}

// ---------------------------------------------------------------------------
// AUDIT_SYSTEM — ACTIVATION PERSISTENCE ROUND-TRIP HELPER (Task 14.5)
//
// Pure, testable model of the encrypted-device-store round-trip that backs
// Req 8.3: "WHEN License_Activation succeeds, THE Audit_System SHALL verify
// that the activation result is persisted to encrypted device storage and
// retained across application restarts."
//
// The real persistence mechanism (platform secure storage + OS-level
// encryption) is owned by the sibling `offline-license-activation` spec. Here
// we only model the *verifiable contract* that mechanism must satisfy, so the
// property suite (Task 14.6 / Property 18) can assert it deterministically:
//
//   1. Round-trip equivalence  — store→restore yields a value equivalent to
//      the original activation value.
//   2. Restart survival        — the restored value survives a simulated
//      application restart (in-memory state dropped, on-disk state kept).
//   3. No plaintext on disk     — the on-disk representation does not contain
//      the plaintext activation payload.
//
// "Encryption" is modeled as a *reversible transform* (a keyed, position-aware
// byte rotation over the UTF-16 code units, then a printable re-encoding). The
// transform's only job for verification purposes is to guarantee the stored
// representation differs from — and never literally contains — the plaintext,
// while remaining perfectly invertible so the round-trip equivalence holds.
// This is NOT a cryptographic primitive and is not used for real secrecy; it
// exists solely to make the persistence contract checkable in pure Dart.
//
// Pure `dart:core` only, matching the rest of this file.
//
// Part of: per-screen-business-type-audit-remediation (Task 14.5)
// _Requirements: 8.3_

/// An immutable, successful License_Activation value to be persisted.
///
/// Modeled as an opaque [payload] string (e.g. the serialized activation
/// token/claims). Equivalence is by payload equality, mirroring how a restored
/// activation is considered "the same" iff it carries the same payload.
class ActivationValue {
  const ActivationValue(this.payload);

  /// The plaintext activation payload that must never appear on disk.
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is ActivationValue && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  @override
  String toString() => 'ActivationValue(${payload.length} chars)';
}

/// A reversible, keyed transform standing in for device-store encryption.
///
/// It maps a plaintext string to a printable "ciphertext" string and back. The
/// transform is position-aware (each code unit is shifted by the key byte at
/// its position, cycling through the key) so repeated characters do not encode
/// to repeated output, and the output is hex-encoded so it is always printable
/// and structurally distinct from arbitrary plaintext.
///
/// This is a *model* of encryption for verification only — it provides
/// invertibility (for round-trip equivalence) and non-identity output (so the
/// plaintext does not survive on disk), nothing more.
class ReversibleObfuscator {
  const ReversibleObfuscator(this.key)
    : assert(key != '', 'key must be non-empty');

  /// The obfuscation key. Must be non-empty.
  final String key;

  /// Encode [plaintext] into a printable hex representation whose underlying
  /// bytes are shifted away from the plaintext's bytes.
  String encode(String plaintext) {
    final buffer = StringBuffer();
    for (var i = 0; i < plaintext.length; i++) {
      final shifted =
          (plaintext.codeUnitAt(i) + key.codeUnitAt(i % key.length)) & 0xFFFF;
      buffer.write(shifted.toRadixString(16).padLeft(4, '0'));
    }
    return buffer.toString();
  }

  /// Invert [encoded] back to the original plaintext.
  String decode(String encoded) {
    final buffer = StringBuffer();
    for (var i = 0; i + 4 <= encoded.length; i += 4) {
      final shifted = int.parse(encoded.substring(i, i + 4), radix: 16);
      final original =
          (shifted - key.codeUnitAt((i ~/ 4) % key.length)) & 0xFFFF;
      buffer.writeCharCode(original);
    }
    return buffer.toString();
  }
}

/// A pure model of an encrypted device store for a single [ActivationValue].
///
/// The store separates two layers of state, exactly like a real device store:
///
///   * [diskRepresentation] — the durable, encrypted-on-disk bytes (modeled as
///     the obfuscated string). This survives a restart.
///   * an in-memory decrypted cache — populated on [store]/[restore], dropped
///     by [simulateRestart] to model process memory being cleared.
///
/// [restore] re-derives the [ActivationValue] from the disk representation, so
/// it works whether or not the in-memory cache is warm.
class EncryptedActivationStore {
  EncryptedActivationStore({ReversibleObfuscator? obfuscator})
    : _obfuscator = obfuscator ?? const ReversibleObfuscator('audit-sys-key');

  final ReversibleObfuscator _obfuscator;

  /// The durable, "encrypted" on-disk representation, or null if nothing has
  /// been persisted yet.
  String? _disk;

  /// The warm in-memory decrypted value, dropped on [simulateRestart].
  ActivationValue? _memory;

  /// Persist [value] to the encrypted store. Writes the obfuscated payload to
  /// disk and warms the in-memory cache.
  void store(ActivationValue value) {
    _disk = _obfuscator.encode(value.payload);
    _memory = value;
  }

  /// Restore the persisted [ActivationValue] by decrypting the disk
  /// representation. Returns null iff nothing has been persisted.
  ///
  /// Restoring also re-warms the in-memory cache, modeling a store that decodes
  /// on first read after a restart.
  ActivationValue? restore() {
    final disk = _disk;
    if (disk == null) return null;
    final value = ActivationValue(_obfuscator.decode(disk));
    _memory = value;
    return value;
  }

  /// Drop in-memory state while keeping the durable disk representation,
  /// modeling an application restart.
  void simulateRestart() {
    _memory = null;
  }

  /// The current on-disk representation (null until something is stored).
  ///
  /// Exposed so verification can assert the stored bytes do not contain the
  /// plaintext payload.
  String? get diskRepresentation => _disk;

  /// Whether an in-memory decrypted value is currently warm. False immediately
  /// after [simulateRestart] until the next [restore].
  bool get hasWarmCache => _memory != null;

  /// Whether the on-disk representation literally contains [plaintext].
  ///
  /// A correct encrypted store returns false for any non-empty plaintext: the
  /// payload must not survive in cleartext on disk.
  bool containsPlaintext(String plaintext) {
    final disk = _disk;
    if (disk == null || plaintext.isEmpty) return false;
    return disk.contains(plaintext);
  }
}

/// The outcome of evaluating an activation persistence round-trip (Req 8.3).
class PersistenceRoundTripResult {
  PersistenceRoundTripResult({
    required this.equivalentAfterRestore,
    required this.survivesRestart,
    required this.plaintextLeaked,
  });

  /// True iff store→restore yielded a value equivalent to the original.
  final bool equivalentAfterRestore;

  /// True iff the restored value survived a simulated restart.
  final bool survivesRestart;

  /// True iff the plaintext payload was found in the on-disk representation.
  final bool plaintextLeaked;

  /// True iff the persistence contract holds: the value round-trips, survives a
  /// restart, and no plaintext leaked to disk.
  bool get isCompliant =>
      equivalentAfterRestore && survivesRestart && !plaintextLeaked;

  @override
  String toString() =>
      'PersistenceRoundTripResult(equivalent=$equivalentAfterRestore, '
      'survivesRestart=$survivesRestart, plaintextLeaked=$plaintextLeaked)';
}

/// Pure classifier for the activation persistence round-trip (Req 8.3).
///
/// Given an original [ActivationValue] and an [EncryptedActivationStore], it
/// drives the full contract — store, restore, simulate a restart, restore
/// again — and reports each of the three properties independently so the
/// property suite (Property 18) can pinpoint exactly which guarantee failed.
class ActivationPersistenceClassifier {
  const ActivationPersistenceClassifier();

  /// Run the round-trip against a fresh-enough [store] and classify the result.
  ///
  /// The [store] is expected to start empty for [original]; the classifier
  /// performs the store/restore/restart sequence itself.
  PersistenceRoundTripResult classify({
    required ActivationValue original,
    required EncryptedActivationStore store,
  }) {
    // 1. Persist, then restore from the warm store.
    store.store(original);
    final restored = store.restore();
    final equivalentAfterRestore = restored == original;

    // 3. Plaintext must not survive on disk (checked against the live disk
    //    representation after a store).
    final plaintextLeaked = store.containsPlaintext(original.payload);

    // 2. Drop in-memory state (restart) and restore purely from disk.
    store.simulateRestart();
    final afterRestart = store.restore();
    final survivesRestart = afterRestart == original;

    return PersistenceRoundTripResult(
      equivalentAfterRestore: equivalentAfterRestore,
      survivesRestart: survivesRestart,
      plaintextLeaked: plaintextLeaked,
    );
  }

  /// Convenience: true iff [original] round-trips, survives a restart, and does
  /// not leak plaintext through the given [store].
  bool roundTripsCleanly({
    required ActivationValue original,
    required EncryptedActivationStore store,
  }) {
    return classify(original: original, store: store).isCompliant;
  }
}
