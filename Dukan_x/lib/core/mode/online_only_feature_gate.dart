// ============================================================================
// ONLINE-ONLY FEATURE GATE — enforces the Online_Only_Feature registry in
// Offline_Lifetime_Mode by preventing execution and returning an unavailable
// indication
// ============================================================================
// Feature: offline-license-activation (Task 13.2)
//
// Requirement 11.10: WHILE the DukanX_App is in Offline_Lifetime_Mode, WHEN a
// user attempts to access an Online_Only_Feature, THE DukanX_App SHALL display
// an indication that the feature is unavailable offline AND SHALL NOT execute
// the feature.
//
// This gate is the enforcement seam that turns the declarative
// `OnlineOnlyFeatureRegistry` (Task 13.1) into actual blocking. It CONSUMES the
// registry — it does NOT rebuild it — and uses the existing `ModeManager`
// (Task 1.2) as the single source of truth for whether the app is currently in
// Offline_Lifetime_Mode.
//
// Behaviour (Requirement 11.10):
//   * Offline + the feature is an Online_Only_Feature → BLOCK: the supplied
//     action is never invoked and a [FeatureUnavailableOffline] indication is
//     returned, carrying the documented reason straight from the registry
//     (Requirement 11.9).
//   * Otherwise (Cloud_Subscription_Mode, OR offline but the feature is NOT
//     online-only and therefore has full offline parity) → ALLOW: execution
//     proceeds exactly as before. Cloud_Subscription_Mode behaviour is
//     preserved unchanged.
//
// Design constraints honoured here (see design.md):
//   * REUSE, DON'T REBUILD. The set of online-only features and each reason
//     come solely from `OnlineOnlyFeatureRegistry`; the active mode comes solely
//     from `ModeManager`. This file adds no feature list and no mode logic.
//   * SERVICE LAYER ONLY. Pure Dart with no Flutter / IO dependency; injected
//     through the existing `service_locator` (`sl`) and never referenced by the
//     widget tree (zero UI changes). The gate decision is pure and
//     deterministic so it can be property-tested (Task 13.4).
//
// Author: DukanX Engineering
// ============================================================================

import 'mode_manager.dart';
import 'online_only_feature_registry.dart';

/// Why the [OnlineOnlyFeatureGate] allowed or blocked a feature.
///
/// Carrying the reason (rather than a bare boolean) lets the service layer tell
/// the user *why* a feature was blocked and lets callers distinguish the two
/// allow paths (cloud mode vs. an offline feature that keeps full parity).
enum FeatureGateReason {
  /// The active Operating_Mode is Cloud_Subscription_Mode, so nothing is
  /// blocked and execution proceeds with the existing online behaviour.
  allowedOnline,

  /// The active Operating_Mode is Offline_Lifetime_Mode but the feature is NOT
  /// an Online_Only_Feature, so it keeps full offline parity and is allowed.
  allowedOfflineCapable,

  /// The active Operating_Mode is Offline_Lifetime_Mode and the feature IS an
  /// Online_Only_Feature, so execution is prevented (Requirement 11.10).
  blockedOnlineOnlyOffline,
}

/// The result of an [OnlineOnlyFeatureGate] decision for a single feature.
///
/// This is the "unavailable indication" the gate returns when it blocks a
/// feature offline (Requirement 11.10). It is also returned (as an allow) when
/// the feature may proceed, so a single type describes every outcome.
class FeatureGateDecision {
  /// Whether the feature is permitted to execute.
  ///
  /// `false` means the feature is an Online_Only_Feature attempted offline and
  /// MUST NOT be executed (Requirement 11.10).
  final bool isAllowed;

  /// The machine-readable reason for the decision.
  final FeatureGateReason reason;

  /// The feature identifier the decision was made for (the registry id, e.g.
  /// `scan_bill_ocr`).
  final String featureId;

  /// The documented offline-unavailable reason from the registry
  /// (Requirement 11.9) when blocked; `null` on an allow.
  final String? unavailableReason;

  const FeatureGateDecision({
    required this.isAllowed,
    required this.reason,
    required this.featureId,
    this.unavailableReason,
  });

  /// Whether the feature was blocked because it is online-only and the app is
  /// offline (Requirement 11.10). The inverse of [isAllowed].
  bool get isBlocked => !isAllowed;

  @override
  String toString() =>
      'FeatureGateDecision(${isAllowed ? 'allow' : 'block'}, '
      'reason: ${reason.name}, feature: $featureId'
      '${unavailableReason == null ? '' : ', because: $unavailableReason'})';
}

/// Thrown by [OnlineOnlyFeatureGate.run] / [OnlineOnlyFeatureGate.runSync] when
/// an Online_Only_Feature is attempted while in Offline_Lifetime_Mode.
///
/// The throwing entry points exist for call sites that wrap an action and want
/// the attempt to abort rather than branch on a result. The action is NEVER
/// invoked before this is thrown, satisfying "SHALL not execute the feature"
/// (Requirement 11.10). The message is the documented registry reason
/// (Requirement 11.9), so it is suitable for the service layer to surface as
/// the "unavailable offline" indication.
class FeatureUnavailableOfflineException implements Exception {
  /// The feature identifier that was blocked.
  final String featureId;

  /// The documented offline-unavailable reason from the registry.
  final String reason;

  const FeatureUnavailableOfflineException({
    required this.featureId,
    required this.reason,
  });

  @override
  String toString() =>
      'FeatureUnavailableOfflineException(feature: $featureId): $reason';
}

/// Enforces Requirement 11.10: blocks any Online_Only_Feature while the app is
/// in Offline_Lifetime_Mode and allows everything else.
///
/// The gate is a thin, pure decision layer built entirely on existing pieces:
///   * the active Operating_Mode comes from the injected [ModeManager]
///     (Task 1.2), and
///   * the online-only set and each unavailable reason come from the
///     [OnlineOnlyFeatureRegistry] (Task 13.1).
///
/// It introduces no feature list and no mode logic of its own. Service layer
/// only — never referenced by the widget tree.
class OnlineOnlyFeatureGate {
  final ModeManager _modeManager;

  /// Creates a gate bound to the [modeManager] that owns the active mode.
  const OnlineOnlyFeatureGate(ModeManager modeManager)
    : _modeManager = modeManager;

  /// Whether the app is currently in Offline_Lifetime_Mode, read synchronously
  /// from the [ModeManager] so the gate decision stays pure and fast.
  bool get _isOffline =>
      _modeManager.activeMode == OperatingMode.offlineLifetime;

  /// Whether the feature named [featureId] is permitted to execute right now.
  ///
  /// Returns `false` only when the feature is a registered Online_Only_Feature
  /// AND the app is in Offline_Lifetime_Mode (Requirement 11.10). In every other
  /// case — Cloud_Subscription_Mode, or an offline-capable feature — returns
  /// `true`. Equivalent to `evaluate(featureId).isAllowed`.
  bool isFeatureAllowed(String featureId) => evaluate(featureId).isAllowed;

  /// Resolves the gate decision for [featureId] without executing anything.
  ///
  /// This is the pure, deterministic core (Task 13.4 property-tests it): the
  /// outcome is a total function of the active mode and the registry. When the
  /// decision is a block, the returned [FeatureGateDecision.unavailableReason]
  /// is the documented registry reason (Requirement 11.9).
  FeatureGateDecision evaluate(String featureId) {
    // Cloud_Subscription_Mode is the untouched baseline: never block anything.
    if (!_isOffline) {
      return FeatureGateDecision(
        isAllowed: true,
        reason: FeatureGateReason.allowedOnline,
        featureId: featureId,
      );
    }

    // Offline: only features the registry flags as online-only are blocked.
    // Features absent from the registry keep full offline parity (billing,
    // GST, inventory, reports, printing, …) and are allowed.
    if (!OnlineOnlyFeatureRegistry.isOnlineOnly(featureId)) {
      return FeatureGateDecision(
        isAllowed: true,
        reason: FeatureGateReason.allowedOfflineCapable,
        featureId: featureId,
      );
    }

    // Offline + online-only → block and carry the documented reason (11.9).
    return FeatureGateDecision(
      isAllowed: false,
      reason: FeatureGateReason.blockedOnlineOnlyOffline,
      featureId: featureId,
      unavailableReason: OnlineOnlyFeatureRegistry.unavailableOfflineReason(
        featureId,
      ),
    );
  }

  /// Runs the asynchronous [action] for [featureId] only if the gate allows it.
  ///
  /// When the feature is an Online_Only_Feature attempted offline, [action] is
  /// NOT invoked and a [FeatureUnavailableOfflineException] carrying the
  /// documented reason is thrown instead (Requirement 11.10). Otherwise the
  /// action runs and its value is returned unchanged, preserving existing
  /// behaviour.
  Future<T> run<T>(String featureId, Future<T> Function() action) {
    _guard(featureId);
    return action();
  }

  /// Synchronous counterpart to [run] for non-async features.
  ///
  /// When blocked, [action] is NOT invoked and a
  /// [FeatureUnavailableOfflineException] is thrown (Requirement 11.10).
  T runSync<T>(String featureId, T Function() action) {
    _guard(featureId);
    return action();
  }

  /// Throws a [FeatureUnavailableOfflineException] when [featureId] is blocked,
  /// before any action runs. Used by [run]/[runSync] so the "SHALL not execute"
  /// guarantee holds — the throw happens prior to invoking the action.
  void _guard(String featureId) {
    final decision = evaluate(featureId);
    if (decision.isBlocked) {
      throw FeatureUnavailableOfflineException(
        featureId: featureId,
        reason:
            decision.unavailableReason ??
            'This feature is unavailable in Offline_Lifetime_Mode.',
      );
    }
  }
}
