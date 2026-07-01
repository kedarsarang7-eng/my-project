// ============================================================================
// STORE_FORENSIC_GATE — service-layer flag for tamper/swap read-only mode
// ============================================================================
// Feature: offline-license-activation (Task 18.2 — Security_Layer, Req 17.12)
//
// PURPOSE
// -------
// When the Local_Store is detected as swapped or tampered with (it does not
// authenticate under the machine-derived SQLCipher key, or its recorded binding
// does not match this machine), the application enters a READ-ONLY FORENSIC
// MODE: reads are permitted so an operator can inspect the data, but EVERY write
// is blocked, and the tamper condition is reported (Req 17.12).
//
// This gate is the single, service-layer flag the write path consults — exactly
// the way `grace_period_gate.dart` is the seam the bill-creation path consults
// for the Read_Only grace state. It is deliberately tiny: it holds the current
// tamper flag, broadcasts changes, and answers one yes/no question the write
// path needs: [isWriteBlocked].
//
// WHY A SEPARATE SEAM (REUSE, DON'T REBUILD)
// ------------------------------------------
// The tamper *detection* lives in the Security_Layer (`OfflineSecurityLayer`,
// task 18.1) which runs `StoreTamperDetector` during the offline Startup_
// Sequence. The *enforcement* must reach every write chokepoint without coupling
// the detector to the repository layer or the widget tree. This gate is the
// decoupling point, mirroring `GracePeriodGate`:
//
//   OfflineSecurityLayer.detectStoreTamper()  ──markTampered()──▶  StoreForensicGate
//                                                                        │
//                                                                  isWriteBlocked
//                                                                        │
//                                            ┌───────────────────────────┴──────────┐
//                                     SyncFoundation.recordWrite            BillsRepository
//                                     (all offline writes)                  (create/update/delete)
//
// All switching stays at the service layer, so the Flutter widget tree is
// untouched (zero UI changes) and Cloud_Subscription_Mode is unaffected (the
// gate is never armed unless the offline Security_Layer detects store tamper).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';

/// Service-layer holder + broadcaster of the Local_Store tamper/forensic flag.
///
/// A process-wide singleton (mirroring `GracePeriodGate.instance`) so any
/// service can observe and query it without plumbing a reference through the
/// widget tree.
class StoreForensicGate {
  StoreForensicGate._();

  /// The single shared instance.
  static final StoreForensicGate instance = StoreForensicGate._();

  bool _tampered = false;
  String? _reason;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  /// Human-readable reason surfaced when a write is blocked by the gate. Kept
  /// here so the message lives in exactly one place and reads consistently
  /// wherever a blocked write is reported. Carries NO secret/key material
  /// (Req 17.10).
  static const String writeBlockedReason =
      'This installation has entered read-only forensic mode because the local '
      'data store appears to have been swapped or tampered with. Existing '
      'records can be viewed, but no changes can be saved. Please contact '
      'support to restore a verified backup.';

  /// Whether the Local_Store has been detected as swapped or tampered with.
  bool get isTampered => _tampered;

  /// True while the installation is in read-only forensic mode — i.e. reads are
  /// permitted but ALL writes must be blocked (Req 17.12). Every write
  /// chokepoint consults this.
  bool get isWriteBlocked => _tampered;

  /// The reported tamper reason, or null while intact. Never contains secrets.
  String? get tamperReason => _reason;

  /// Emits whenever the forensic flag transitions to a *different* value, so
  /// listeners (e.g. a future status indicator wired purely at the service
  /// layer) can react without polling.
  Stream<bool> get onChanged => _controller.stream;

  /// Arms read-only forensic mode after the Security_Layer detects that the
  /// Local_Store was swapped or tampered with (Req 17.12).
  ///
  /// Called by [OfflineSecurityLayer.detectStoreTamper]. Emits on [onChanged]
  /// only when the flag actually changes so repeated detections do not spam
  /// listeners. The [reason] MUST NOT contain any secret/key/license material.
  void markTampered(String reason) {
    _reason = reason;
    if (_tampered) return;
    _tampered = true;
    _controller.add(true);
  }

  /// Clears the forensic flag (e.g. after a verified backup is restored and the
  /// store re-authenticates). Production code only clears through a fresh,
  /// successful detection pass; exposed so recovery flows can lift the lock.
  void clear() {
    _reason = null;
    if (!_tampered) return;
    _tampered = false;
    _controller.add(false);
  }

  /// Resets the gate for test isolation only.
  void resetForTesting() {
    _tampered = false;
    _reason = null;
  }
}
