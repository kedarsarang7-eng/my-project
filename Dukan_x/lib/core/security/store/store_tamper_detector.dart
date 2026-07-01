// ============================================================================
// STORE_TAMPER_DETECTOR — detect a swapped/tampered Local_Store (Req 17.12)
// ============================================================================
// Feature: offline-license-activation (Task 18.2 — Security_Layer)
//
// The Local_Store is encrypted with SQLCipher using a key the Security_Layer
// derives from the machine binding (Fingerprint_Hash + tenant id + app secret —
// see `local_store_crypto.dart`, Req 8.3). That binding is exactly what makes a
// SWAP or a TAMPER detectable:
//
//   * SWAPPED store  — a database file copied from a DIFFERENT machine (or a
//     different tenant) was dropped in place. It will NOT authenticate under
//     the key derived from THIS machine's binding (the SQLCipher page MAC /
//     `PRAGMA cipher_integrity_check` fails), OR it authenticates but the
//     binding fingerprint it records does not match this machine.
//   * TAMPERED store — the encrypted bytes were modified. SQLCipher's per-page
//     authentication (HMAC) fails to open / read the database.
//
// This module is split, by design, into:
//
//   1. A PURE, DETERMINISTIC decision function — [StoreTamperDecision.decide] —
//      that maps a small, fully-described [StoreAuthProbe] to an outcome. This
//      is the property-test surface (task 18.5 / design Property 37): no I/O, no
//      Flutter, no clocks.
//   2. A thin [StoreTamperDetector] that performs the actual probe (open the
//      store under the derived key, run the integrity check, compare the
//      recorded binding) and feeds the probe into the pure decision. The probe
//      step is injectable so it can be exercised with test doubles.
//
// REUSE, DON'T REBUILD: the key is derived through the centralised
// `LocalStoreEncryption` / `OfflineKeyDerivation` seam (task 18.1); no new key
// logic is introduced here. Enforcement of the resulting read-only forensic
// mode is owned by `StoreForensicGate`; this module only DETECTS and DECIDES.
//
// SECURITY (Req 17.10): no method here logs or returns key/secret material. The
// probe carries only booleans and an already-masked binding comparison.
//
// PURE DART for the decision core: no Flutter imports, so it composes cleanly
// with unit/property tests.
//
// Author: DukanX Engineering
// ============================================================================

/// The outcome of evaluating a Local_Store against this machine's binding.
enum StoreTamperStatus {
  /// The store authenticated under the machine-derived key and its recorded
  /// binding matches — safe for normal read/write use.
  intact,

  /// The store was swapped or tampered with (failed authentication/integrity,
  /// or a mismatched binding). Read-only forensic mode MUST be entered
  /// (Req 17.12).
  tampered,

  /// No Local_Store is present yet, or encryption is not configured on this
  /// installation (e.g. an existing unencrypted install, or before activation).
  /// There is nothing to authenticate, so this is NOT treated as tamper.
  notApplicable,
}

/// A small, fully-described snapshot of the facts the pure decision needs.
///
/// Every field is a plain boolean (no secrets, no handles) so the decision is
/// trivially deterministic and property-testable.
class StoreAuthProbe {
  /// Whether a Local_Store database file exists on disk.
  final bool storeExists;

  /// Whether the Security_Layer has a SQLCipher key configured for this
  /// installation. When false, the store is opened unencrypted exactly as
  /// legacy installs do, so there is no binding to authenticate against.
  final bool encryptionConfigured;

  /// Whether the store opened AND passed SQLCipher's authenticated integrity
  /// check under the machine-derived key. False when the bytes were tampered
  /// with or the file came from another machine/tenant (wrong key).
  final bool authenticatedUnderMachineKey;

  /// Whether the binding identifier recorded inside the store matches the one
  /// derived from THIS machine. A store that authenticates but records a
  /// different binding is a swap and must be treated as tampered.
  ///
  /// `true` when no separate binding record is used (authentication alone is
  /// the binding check); only an explicit MISMATCH sets this `false`.
  final bool bindingMatches;

  const StoreAuthProbe({
    required this.storeExists,
    required this.encryptionConfigured,
    required this.authenticatedUnderMachineKey,
    this.bindingMatches = true,
  });

  @override
  String toString() =>
      'StoreAuthProbe(exists: $storeExists, encrypted: $encryptionConfigured, '
      'authenticated: $authenticatedUnderMachineKey, '
      'bindingMatches: $bindingMatches)';
}

/// Pure, deterministic decision: classify a [StoreAuthProbe] (Req 17.12).
///
/// This is the property surface (design Property 37): identical inputs always
/// yield identical outputs, with no side effects.
class StoreTamperDecision {
  const StoreTamperDecision._();

  /// Maps a probe to a [StoreTamperStatus].
  ///
  /// Decision order:
  ///   1. No store on disk, OR encryption not configured → [notApplicable].
  ///      There is no machine-bound encrypted store to authenticate, so this is
  ///      a fresh/legacy install, never a tamper.
  ///   2. The store fails authentication under the machine key → [tampered]
  ///      (swapped from another machine/tenant, or bytes modified).
  ///   3. The store authenticates but its recorded binding does not match this
  ///      machine → [tampered] (a swapped store that happens to share a key
  ///      space but was bound elsewhere).
  ///   4. Otherwise → [intact].
  static StoreTamperStatus decide(StoreAuthProbe probe) {
    if (!probe.storeExists || !probe.encryptionConfigured) {
      return StoreTamperStatus.notApplicable;
    }
    if (!probe.authenticatedUnderMachineKey) {
      return StoreTamperStatus.tampered;
    }
    if (!probe.bindingMatches) {
      return StoreTamperStatus.tampered;
    }
    return StoreTamperStatus.intact;
  }
}

/// Result returned by [StoreTamperDetector.detect].
class StoreTamperResult {
  final StoreTamperStatus status;

  const StoreTamperResult(this.status);

  /// True only when the store was detected as swapped/tampered (Req 17.12).
  bool get isTampered => status == StoreTamperStatus.tampered;

  /// True when the store authenticated and its binding matched.
  bool get isIntact => status == StoreTamperStatus.intact;

  @override
  String toString() => 'StoreTamperResult($status)';
}

/// Signature of the injectable probe step that authenticates the Local_Store
/// under the machine-derived key and reports the facts the decision needs.
///
/// Implementations perform the real SQLCipher open + integrity check; tests
/// supply a double. The probe MUST NOT throw — it captures an authentication
/// failure as `authenticatedUnderMachineKey: false`.
typedef StoreAuthProbeRunner = Future<StoreAuthProbe> Function();

/// Detects a swapped/tampered Local_Store by probing its authentication under
/// the machine-derived key and applying the pure [StoreTamperDecision].
///
/// The detector is intentionally thin: all the classification logic lives in
/// the pure decision so it can be property-tested without I/O. Only the probe
/// touches the database.
class StoreTamperDetector {
  final StoreAuthProbeRunner _probeRunner;

  StoreTamperDetector({required StoreAuthProbeRunner probeRunner})
    : _probeRunner = probeRunner;

  /// Runs the probe and classifies the result (Req 17.12). Never throws: a
  /// probe failure is surfaced through the probe as a non-authenticated store.
  Future<StoreTamperResult> detect() async {
    final probe = await _probeRunner();
    return StoreTamperResult(StoreTamperDecision.decide(probe));
  }
}
