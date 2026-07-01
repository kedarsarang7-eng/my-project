// ============================================================================
// GRACE-PERIOD GATE — service-layer seam for Read_Only / Locked enforcement
// ============================================================================
// Feature: offline-license-activation (Task 5.3)
//
// PURPOSE
// -------
// This is the single, service-layer mechanism that the rest of the app reacts
// to when the License_Validator's Grace_Period_State enters Read_Only or
// Locked. It is deliberately tiny: it holds the *current* [GracePeriodState],
// broadcasts changes, and answers two yes/no questions the service layer needs:
//
//   * [isBillCreationBlocked] — true while Read_Only or Locked (Req 7.8, 7.9,
//     7.13). Bill-creation chokepoints consult this to block any creation
//     attempt.
//   * [isLocked] — true while Locked (Req 7.13). Write chokepoints consult this
//     to block editing until reactivation completes.
//
// WHY A SEPARATE SEAM (REUSE, DON'T REBUILD)
// ------------------------------------------
// The design wires Read_Only/Locked into the EXISTING
// `license_invalid_listener.dart` and the EXISTING bill chokepoints rather than
// inventing parallel gating. But the License_Validator's stateful background
// loop (Task 5.2) and the widget-tree listener (this task) must not depend on
// each other directly. This gate is the decoupling point:
//
//   License_Validator (5.2)  ──apply()/bindTo()──▶  GracePeriodGate  ◀──reads──┐
//                                                         │                     │
//                                                  onStateChanged          isBillCreationBlocked /
//                                                         │                  isLocked
//                                                         ▼                     │
//                                            license_invalid_listener   BillsRepository (service layer)
//
// The gate reuses the [GracePeriodState] enum from `license_validator.dart`; it
// defines NO new state logic of its own. All switching stays at the service
// layer, so the Flutter widget tree is untouched (zero UI changes).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';

import 'license_validator.dart';

/// Service-layer holder + broadcaster of the active [GracePeriodState].
///
/// A process-wide singleton (mirroring the `RestSyncEngine.instance` pattern
/// already used for license invalidation) so any service or the
/// `license_invalid_listener.dart` can observe and query it without plumbing a
/// reference through the widget tree.
class GracePeriodGate {
  GracePeriodGate._();

  /// The single shared instance.
  static final GracePeriodGate instance = GracePeriodGate._();

  GracePeriodState _state = GracePeriodState.normal;

  final StreamController<GracePeriodState> _controller =
      StreamController<GracePeriodState>.broadcast();

  StreamSubscription<GracePeriodState>? _sourceSub;

  /// Human-readable reason surfaced when a write is blocked by the gate. Kept
  /// here so the message lives in exactly one place and reads consistently
  /// wherever a blocked attempt is reported.
  static const String billCreationBlockedReason =
      'New bills cannot be created because your license needs revalidation. '
      'Please reconnect to the internet and revalidate your license to continue.';

  static const String lockedWriteBlockedReason =
      'Editing is disabled because your license has expired. '
      'Please complete reactivation to continue.';

  /// The current Grace_Period_State (defaults to [GracePeriodState.normal]
  /// until the License_Validator reports otherwise).
  GracePeriodState get state => _state;

  /// Emits whenever the Grace_Period_State transitions to a *different* value.
  ///
  /// Consumed by `license_invalid_listener.dart` (Task 5.3) to drive the
  /// existing Read_Only / Locked behaviour.
  Stream<GracePeriodState> get onStateChanged => _controller.stream;

  /// True while new bills must not be created — i.e. Read_Only (Req 7.8, 7.9)
  /// or Locked (Req 7.13). Bill-creation service chokepoints consult this to
  /// block any creation attempt.
  bool get isBillCreationBlocked =>
      _state == GracePeriodState.readOnly || _state == GracePeriodState.locked;

  /// True while all record creation AND editing must be blocked — i.e. Locked
  /// (Req 7.13). Write chokepoints (update/delete) consult this.
  bool get isLocked => _state == GracePeriodState.locked;

  /// Applies a new Grace_Period_State.
  ///
  /// Called by the License_Validator (Task 5.2) after each background
  /// validation classifies the current state. Emits on [onStateChanged] only
  /// when the value actually changes, so repeated identical classifications do
  /// not spam listeners.
  void apply(GracePeriodState next) {
    if (next == _state) return;
    _state = next;
    _controller.add(next);
  }

  /// Convenience seam for the License_Validator: forwards every value from its
  /// `state` stream into [apply]. Returns the subscription so the caller may
  /// cancel it; also retained internally so a later [bindTo] replaces the
  /// previous binding cleanly.
  StreamSubscription<GracePeriodState> bindTo(Stream<GracePeriodState> source) {
    _sourceSub?.cancel();
    final sub = source.listen(apply);
    _sourceSub = sub;
    return sub;
  }

  /// Resets the gate to [GracePeriodState.normal]. Intended for test isolation
  /// only — production code transitions state exclusively through [apply].
  void resetForTesting() {
    _state = GracePeriodState.normal;
  }
}
