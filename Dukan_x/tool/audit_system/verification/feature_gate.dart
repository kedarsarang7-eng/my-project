// AUDIT_SYSTEM — FEATURE-GATE CLASSIFIER (Task 16.1)
//
// Pure decision logic for verifying that a Screen's Feature_Gate locks or
// unlocks each feature correctly based on the active Subscription_Plan's
// entitlements, while keeping every feature name visible (Req 10.1–10.5).
//
// The rules implemented here:
//   * A feature is UNLOCKED if and only if it is included in the active plan's
//     entitlements; otherwise it is LOCKED (Req 10.1, 10.3, 10.4 / Property 24).
//   * Every feature name defined for a Business_Type remains VISIBLE regardless
//     of plan — locked features are shown in a locked state, never hidden or
//     removed (Req 10.2 / Property 25).
//   * The lock/unlock decision is mode-invariant: identical online and offline
//     for the same entitlements (Req 10.5 / Property 26).
//
// SCOPE: This file implements ONLY plan-entitlement-based gating, visibility,
// and mode-invariance. The RBAC override and the Cognito→DynamoDB entitlement
// resolution precedence (Properties 27, 28, 29) are a SEPARATE task (16.5).
// The types below are intentionally structured so that task can extend the
// classifier — e.g. by adding an RBAC role/permission parameter to `classify`
// and an entitlement-resolution step ahead of it — without reshaping the
// existing plan-entitlement contract.
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core. `ConnectivityMode` is reused from the
// sibling `connectivity_routing.dart` classifier rather than redeclared, to
// keep a single source of truth for the online/offline state.
//
// Part of: per-screen-business-type-audit-remediation (Task 16.1)
// _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

import 'connectivity_routing.dart' show ConnectivityMode;

export 'connectivity_routing.dart' show ConnectivityMode;

/// The lock/unlock outcome the Feature_Gate assigns to a single feature.
enum FeatureGateDecision {
  /// The feature is outside the active plan: its Sidebar_Entry is shown but
  /// non-interactive, with a lock indicator and an upsell prompt (Req 10.3).
  locked,

  /// The feature is included in the active plan: its Sidebar_Entry is
  /// interactive and opens the feature, with no lock indicator and no upsell
  /// prompt (Req 10.4).
  unlocked,
}

/// The set of feature names a Business_Type defines, together with the subset
/// the active Subscription_Plan entitles.
///
/// [allFeatures] is the complete catalog of feature names for the Business_Type
/// — every one of these SHALL remain visible regardless of plan (Req 10.2).
/// [entitledFeatures] is the subset the active plan unlocks; it is normalized
/// to the intersection with [allFeatures] so an entitlement naming a feature
/// the Business_Type does not define has no effect.
class PlanEntitlements {
  PlanEntitlements({
    required Set<String> allFeatures,
    required Set<String> entitledFeatures,
  }) : allFeatures = Set.unmodifiable(allFeatures),
       entitledFeatures = Set.unmodifiable(
         entitledFeatures.where(allFeatures.contains).toSet(),
       );

  /// Every feature name defined for the Business_Type. All remain visible.
  final Set<String> allFeatures;

  /// The subset of [allFeatures] the active Subscription_Plan unlocks.
  final Set<String> entitledFeatures;

  /// True iff [feature] is unlocked by the active plan's entitlements.
  bool entitles(String feature) => entitledFeatures.contains(feature);

  /// True iff [feature] is a feature name defined for the Business_Type.
  bool defines(String feature) => allFeatures.contains(feature);

  @override
  String toString() =>
      'PlanEntitlements(all=${allFeatures.length}, '
      'entitled=${entitledFeatures.length})';
}

/// The outcome of classifying a single feature against a [PlanEntitlements] set
/// under a given [ConnectivityMode].
///
/// A feature is always [visible]; [decision] reports whether it is locked or
/// unlocked. The decision depends only on the plan entitlements (and, in a
/// future task, the RBAC role) — never on [mode] (Req 10.5).
class FeatureGateResult {
  FeatureGateResult({
    required this.feature,
    required this.mode,
    required this.decision,
  });

  /// The feature name that was classified.
  final String feature;

  /// The connectivity mode in effect when the decision was computed. Retained
  /// for reporting and mode-invariance checks; it does not affect [decision].
  final ConnectivityMode mode;

  /// Whether the feature is locked or unlocked under the active plan.
  final FeatureGateDecision decision;

  /// Whether the feature name is visible. Always `true`: feature names are
  /// never hidden or removed, only locked or unlocked (Req 10.2).
  bool get visible => true;

  /// True iff the feature is unlocked (interactive, no lock/upsell).
  bool get isUnlocked => decision == FeatureGateDecision.unlocked;

  /// True iff the feature is locked (non-interactive, lock indicator + upsell).
  bool get isLocked => decision == FeatureGateDecision.locked;

  @override
  String toString() =>
      'FeatureGateResult($feature, ${mode.name}, ${decision.name}, '
      'visible=$visible)';
}

/// Pure classifier that decides whether a feature is locked or unlocked based
/// solely on the active Subscription_Plan's entitlements, and confirms that all
/// feature names remain visible (Req 10.1–10.5 / Properties 24, 25, 26).
///
/// EXTENSION POINT (Task 16.5): the plan-entitlement decision computed here is
/// the baseline. The RBAC override (Property 27) layers an additional denial on
/// top of an `unlocked` baseline, and entitlement resolution (Properties 28,
/// 29) supplies the [PlanEntitlements] passed in. Both can be added by wrapping
/// or extending [classify] without changing the entitlement contract below.
class FeatureGateClassifier {
  const FeatureGateClassifier();

  /// The lock/unlock decision for [feature] under [entitlements], independent
  /// of connectivity.
  ///
  /// Unlocked **if and only if** the plan entitles the feature; otherwise
  /// locked (Req 10.1, 10.3, 10.4 / Property 24). Because the result depends
  /// only on [entitlements], the decision is identical online and offline
  /// (Req 10.5 / Property 26).
  FeatureGateDecision decisionFor(
    String feature,
    PlanEntitlements entitlements,
  ) {
    return entitlements.entitles(feature)
        ? FeatureGateDecision.unlocked
        : FeatureGateDecision.locked;
  }

  /// Classify a single [feature] under [entitlements] for the given [mode],
  /// returning the decision plus the always-true visibility flag.
  ///
  /// [mode] is recorded on the result for reporting but does not influence the
  /// decision (Req 10.5).
  FeatureGateResult classify(
    String feature,
    PlanEntitlements entitlements,
    ConnectivityMode mode,
  ) {
    return FeatureGateResult(
      feature: feature,
      mode: mode,
      decision: decisionFor(feature, entitlements),
    );
  }

  /// Classify every feature name defined for the Business_Type under [mode],
  /// preserving the full feature set. The returned map's key set always equals
  /// `entitlements.allFeatures`, so no feature name is dropped (Req 10.2).
  Map<String, FeatureGateResult> classifyAll(
    PlanEntitlements entitlements,
    ConnectivityMode mode,
  ) {
    return {
      for (final feature in entitlements.allFeatures)
        feature: classify(feature, entitlements, mode),
    };
  }

  /// The set of feature names that would be rendered in the sidebar for
  /// [entitlements]. Equals the full defined feature set regardless of which
  /// features are entitled — used to confirm zero feature names are hidden
  /// (Req 10.2 / Property 25).
  Set<String> visibleFeatureNames(PlanEntitlements entitlements) {
    return Set.unmodifiable(entitlements.allFeatures);
  }

  /// True iff every feature name defined for the Business_Type remains visible
  /// under [entitlements] — i.e. the rendered set equals the full defined set,
  /// with none hidden or removed (Req 10.2 / Property 25).
  bool allFeatureNamesVisible(PlanEntitlements entitlements) {
    final visible = visibleFeatureNames(entitlements);
    return visible.length == entitlements.allFeatures.length &&
        entitlements.allFeatures.every(visible.contains);
  }
}

// ===========================================================================
// AUDIT_SYSTEM — RBAC OVERRIDE + ENTITLEMENT-RESOLUTION PRECEDENCE (Task 16.5)
//
// Extends the plan-entitlement baseline above with the two remaining
// Feature_Gate concerns identified as the task-16.5 extension point:
//
//   * RBAC OVERRIDE (Req 10.6, 12.2 / Property 27): a feature is granted **if
//     and only if** the active plan entitles it AND the active RBAC role holds
//     the permission required for that feature. An RBAC denial therefore
//     overrides a plan-unlocked feature — the feature is locked when the role
//     lacks permission even though the plan includes it.
//
//   * ENTITLEMENT-RESOLUTION PRECEDENCE (Req 10.7 / Property 28): the active
//     Subscription_Plan is resolved from Cognito claims when present, and
//     otherwise from the DynamoDB plan record, as defined by the
//     `subscription-plan-tiers` spec.
//
//   * BOTH SOURCES UNAVAILABLE (Req 10.8 / Property 29): when BOTH Cognito
//     claims and the DynamoDB plan record are unavailable, every plan-gated
//     feature is denied, all feature names stay visible in their locked state,
//     and a resolution error is surfaced — zero premium access is granted.
//
// This layer REUSES the existing PlanEntitlements, FeatureGateDecision, and
// ConnectivityMode types and the FeatureGateClassifier as the entitlement
// baseline; it adds the RBAC denial on top rather than reshaping that contract.
// Like the rest of the file it is PURE, dependency-light Dart.
//
// Part of: per-screen-business-type-audit-remediation (Task 16.5)
// _Requirements: 10.6, 10.7, 10.8, 12.2_
// ===========================================================================

/// An RBAC role derived from the authenticated user's Cognito groups/claims,
/// carrying the set of permissions it holds (Req 12.2).
///
/// A feature that requires a permission is RBAC-granted only when this role
/// holds that exact permission; otherwise the feature is RBAC-denied even when
/// the active plan would unlock it (Req 10.6 / Property 27).
class RbacRole {
  RbacRole({required this.name, required Set<String> permissions})
    : permissions = Set.unmodifiable(permissions);

  /// Human-readable role name (e.g. "owner", "cashier"). Reporting only.
  final String name;

  /// The permissions this role holds. A feature's required permission must be
  /// present here for the role to be granted that feature.
  final Set<String> permissions;

  /// True iff this role holds [permission].
  bool holds(String permission) => permissions.contains(permission);

  @override
  String toString() => 'RbacRole($name, permissions=${permissions.length})';
}

/// Which entitlement source a Subscription_Plan was resolved from, in the
/// Cognito-claims-then-DynamoDB precedence order (Req 10.7 / Property 28).
enum EntitlementSourceKind {
  /// Resolved from Cognito claims (highest precedence, used when present).
  cognitoClaims,

  /// Resolved from the DynamoDB plan record (fallback when claims are absent).
  dynamoRecord,

  /// Neither source was available — entitlements could not be resolved.
  none,
}

/// The availability of the two entitlement sources for a Screen: the
/// Cognito-claims plan and the DynamoDB plan record. Either may be absent
/// (modeled as `null`); when both are absent, resolution fails (Req 10.8).
///
/// Each present source carries a full [PlanEntitlements] so resolution simply
/// selects which one governs — it never merges them.
class EntitlementSources {
  EntitlementSources({this.cognitoClaims, this.dynamoRecord});

  /// The plan entitlements carried by Cognito claims, or `null` if claims are
  /// unavailable.
  final PlanEntitlements? cognitoClaims;

  /// The plan entitlements carried by the DynamoDB plan record, or `null` if
  /// the record is unavailable.
  final PlanEntitlements? dynamoRecord;

  /// True iff Cognito claims are present.
  bool get cognitoAvailable => cognitoClaims != null;

  /// True iff a DynamoDB plan record is present.
  bool get dynamoAvailable => dynamoRecord != null;

  /// True iff at least one entitlement source is available.
  bool get anyAvailable => cognitoAvailable || dynamoAvailable;

  /// True iff BOTH entitlement sources are unavailable (Req 10.8 trigger).
  bool get bothUnavailable => !cognitoAvailable && !dynamoAvailable;

  @override
  String toString() =>
      'EntitlementSources(cognito=$cognitoAvailable, dynamo=$dynamoAvailable)';
}

/// The outcome of resolving [EntitlementSources] into a single governing
/// Subscription_Plan, recording which source won and whether resolution failed
/// (Req 10.7, 10.8 / Properties 28, 29).
class EntitlementResolution {
  EntitlementResolution._({required this.entitlements, required this.source});

  /// The resolved plan entitlements, or `null` when both sources were
  /// unavailable.
  final PlanEntitlements? entitlements;

  /// Which source the entitlements were resolved from (or [EntitlementSourceKind.none]).
  final EntitlementSourceKind source;

  /// True iff a Subscription_Plan was successfully resolved.
  bool get resolved => entitlements != null;

  /// True iff resolution failed because both sources were unavailable. Callers
  /// SHALL surface an indication that entitlements could not be resolved
  /// (Req 10.8 / Property 29).
  bool get resolutionError => entitlements == null;

  @override
  String toString() =>
      'EntitlementResolution(${source.name}, '
      '${resolved ? 'resolved' : 'unresolved'})';
}

/// Why a feature ended up locked (or that it is unlocked), so reporting can
/// distinguish a plan gap from an RBAC denial from a resolution failure.
enum FeatureGateLockReason {
  /// The feature is unlocked — no lock reason applies.
  none,

  /// Locked because the active plan does not entitle the feature
  /// (Req 10.1, 10.3 / Property 24).
  planEntitlement,

  /// Locked because the active RBAC role lacks the required permission, which
  /// overrides a plan that would otherwise unlock the feature
  /// (Req 10.6, 12.2 / Property 27).
  rbacDenied,

  /// Locked because entitlements could not be resolved — both Cognito claims
  /// and the DynamoDB plan record were unavailable (Req 10.8 / Property 29).
  entitlementResolutionFailed,
}

/// The combined RBAC + entitlement outcome for a single feature: always
/// visible, locked or unlocked, with the [lockReason] and resolved
/// [entitlementSource] retained for reporting.
class RbacFeatureGateResult {
  RbacFeatureGateResult({
    required this.feature,
    required this.mode,
    required this.decision,
    required this.lockReason,
    required this.entitlementSource,
  });

  /// The feature name that was classified.
  final String feature;

  /// The connectivity mode in effect. Recorded for reporting and
  /// mode-invariance checks; it never affects [decision] (Req 10.5).
  final ConnectivityMode mode;

  /// Whether the feature is locked or unlocked under plan + RBAC.
  final FeatureGateDecision decision;

  /// Why the feature is locked, or [FeatureGateLockReason.none] if unlocked.
  final FeatureGateLockReason lockReason;

  /// Which source the governing plan was resolved from.
  final EntitlementSourceKind entitlementSource;

  /// Feature names are never hidden or removed, only locked or unlocked
  /// (Req 10.2 / Property 25). Always `true`.
  bool get visible => true;

  /// True iff the feature is unlocked (plan entitles AND RBAC grants).
  bool get isUnlocked => decision == FeatureGateDecision.unlocked;

  /// True iff the feature is locked for any reason.
  bool get isLocked => decision == FeatureGateDecision.locked;

  /// True iff this feature is locked specifically because the RBAC role lacked
  /// permission while the plan included it (an RBAC override).
  bool get isRbacDenied => lockReason == FeatureGateLockReason.rbacDenied;

  /// True iff this feature is locked because entitlements could not be resolved
  /// (Req 10.8 / Property 29).
  bool get isResolutionError =>
      lockReason == FeatureGateLockReason.entitlementResolutionFailed;

  @override
  String toString() =>
      'RbacFeatureGateResult($feature, ${mode.name}, ${decision.name}, '
      '${lockReason.name}, source=${entitlementSource.name})';
}

/// Combined classifier that layers the RBAC override and entitlement-resolution
/// precedence on top of the plan-entitlement baseline computed by
/// [FeatureGateClassifier] (Req 10.6, 10.7, 10.8, 12.2 / Properties 27, 28, 29).
///
/// Access is granted **if and only if** the resolved plan entitles the feature
/// AND the active RBAC role holds the feature's required permission. When both
/// entitlement sources are unavailable, every feature is denied while remaining
/// visible in its locked state.
class RbacFeatureGateClassifier {
  const RbacFeatureGateClassifier({
    FeatureGateClassifier base = const FeatureGateClassifier(),
  }) : _base = base;

  /// The plan-entitlement baseline this layer builds on.
  final FeatureGateClassifier _base;

  /// Resolve [sources] into a single governing Subscription_Plan, preferring
  /// Cognito claims and falling back to the DynamoDB plan record; if neither is
  /// available, the result reports a resolution error (Req 10.7, 10.8 /
  /// Properties 28, 29).
  EntitlementResolution resolve(EntitlementSources sources) {
    final cognito = sources.cognitoClaims;
    if (cognito != null) {
      return EntitlementResolution._(
        entitlements: cognito,
        source: EntitlementSourceKind.cognitoClaims,
      );
    }
    final dynamo = sources.dynamoRecord;
    if (dynamo != null) {
      return EntitlementResolution._(
        entitlements: dynamo,
        source: EntitlementSourceKind.dynamoRecord,
      );
    }
    return EntitlementResolution._(
      entitlements: null,
      source: EntitlementSourceKind.none,
    );
  }

  /// True iff [role] is RBAC-granted [feature]: either the feature requires no
  /// permission ([requiredPermission] is `null`) or the role holds it.
  bool rbacGrants(RbacRole role, {String? requiredPermission}) {
    return requiredPermission == null || role.holds(requiredPermission);
  }

  /// Whether access to [feature] is granted under [entitlements] and [role].
  ///
  /// Granted **if and only if** the plan entitles the feature AND the role
  /// holds [requiredPermission]; otherwise denied. An RBAC denial overrides a
  /// plan that would unlock the feature (Req 10.6, 12.2 / Property 27).
  bool grantsAccess(
    String feature,
    PlanEntitlements entitlements,
    RbacRole role, {
    String? requiredPermission,
  }) {
    final planUnlocked =
        _base.decisionFor(feature, entitlements) ==
        FeatureGateDecision.unlocked;
    return planUnlocked &&
        rbacGrants(role, requiredPermission: requiredPermission);
  }

  /// Classify [feature] against an already-resolved [resolution] and [role],
  /// returning the combined decision, lock reason, and entitlement source.
  ///
  /// When resolution failed (both sources unavailable) the feature is locked
  /// with [FeatureGateLockReason.entitlementResolutionFailed] (Req 10.8). When
  /// resolved, the plan baseline and RBAC override combine per Property 27.
  /// [mode] is recorded but never affects the decision (Req 10.5 / Property 26).
  RbacFeatureGateResult classify(
    String feature,
    EntitlementResolution resolution,
    RbacRole role,
    ConnectivityMode mode, {
    String? requiredPermission,
  }) {
    final entitlements = resolution.entitlements;
    if (entitlements == null) {
      // Both sources unavailable: deny while keeping the name visible/locked.
      return RbacFeatureGateResult(
        feature: feature,
        mode: mode,
        decision: FeatureGateDecision.locked,
        lockReason: FeatureGateLockReason.entitlementResolutionFailed,
        entitlementSource: EntitlementSourceKind.none,
      );
    }

    final planUnlocked =
        _base.decisionFor(feature, entitlements) ==
        FeatureGateDecision.unlocked;
    final rbacGranted = rbacGrants(
      role,
      requiredPermission: requiredPermission,
    );

    final FeatureGateDecision decision;
    final FeatureGateLockReason reason;
    if (!planUnlocked) {
      decision = FeatureGateDecision.locked;
      reason = FeatureGateLockReason.planEntitlement;
    } else if (!rbacGranted) {
      // Plan unlocks it, but the role lacks permission: RBAC override.
      decision = FeatureGateDecision.locked;
      reason = FeatureGateLockReason.rbacDenied;
    } else {
      decision = FeatureGateDecision.unlocked;
      reason = FeatureGateLockReason.none;
    }

    return RbacFeatureGateResult(
      feature: feature,
      mode: mode,
      decision: decision,
      lockReason: reason,
      entitlementSource: resolution.source,
    );
  }

  /// Classify every feature name in [allFeatures] (the full Business_Type
  /// catalog) under [sources], [role], and [mode]. [requiredPermissions] maps a
  /// feature to the permission it requires; features absent from the map
  /// require no permission.
  ///
  /// [allFeatures] is the source of truth for visibility and is independent of
  /// entitlement resolution, so all names remain visible even when both sources
  /// are unavailable (Req 10.2, 10.8 / Properties 25, 29). The returned map's
  /// key set always equals [allFeatures].
  Map<String, RbacFeatureGateResult> classifyAll({
    required Set<String> allFeatures,
    required EntitlementSources sources,
    required RbacRole role,
    required ConnectivityMode mode,
    Map<String, String> requiredPermissions = const {},
  }) {
    final resolution = resolve(sources);
    return {
      for (final feature in allFeatures)
        feature: classify(
          feature,
          resolution,
          role,
          mode,
          requiredPermission: requiredPermissions[feature],
        ),
    };
  }

  /// True iff every feature name in [allFeatures] remains visible across the
  /// combined classification — none hidden or removed (Req 10.2 / Property 25).
  bool allFeatureNamesVisible({
    required Set<String> allFeatures,
    required EntitlementSources sources,
    required RbacRole role,
    required ConnectivityMode mode,
    Map<String, String> requiredPermissions = const {},
  }) {
    final results = classifyAll(
      allFeatures: allFeatures,
      sources: sources,
      role: role,
      mode: mode,
      requiredPermissions: requiredPermissions,
    );
    return results.length == allFeatures.length &&
        allFeatures.every((f) => results.containsKey(f) && results[f]!.visible);
  }

  /// True iff [sources] resolves successfully (used to gate premium access).
  /// When this is `false`, [classifyAll] denies every feature (Req 10.8).
  bool canResolveEntitlements(EntitlementSources sources) =>
      resolve(sources).resolved;
}
