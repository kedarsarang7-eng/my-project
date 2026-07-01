// ============================================================================
// OFFLINE GATING ENGINE — License_Token → existing plan/feature gating
// ============================================================================
// Feature: offline-license-activation (Tasks 10.1 + 10.2)
//
// The Offline_Gating_Engine enforces plan-tier and business-vertical feature
// access in Offline_Lifetime_Mode. It is a THIN ADAPTER, not a new gating
// system: it derives the granted Plan_Tier, the allowed business types, and the
// feature flags from the decrypted License_Token (Requirement 10.1) and then
// delegates every access decision to the EXISTING, already-validated gating
// engine — `TierGating` on top of `PlanMappingBuilder` + the capability
// classifier (Requirement 10.2).
//
// Because all real tier/vertical resolution is delegated to the existing
// engine:
//   * Gating is enforced per Plan_Tier and per Business_Vertical for free, by
//     reuse, not reimplementation (Requirement 10.6).
//   * Existing capabilities keep their pre-feature tier assignment; this engine
//     introduces NO tier logic and NO new tier assignments (Requirement 10.7).
//
// TASK 10.1 — derivation + delegation: deriving the granted tier / allowed
// business types / feature flags from the token and asking the existing engine.
//
// TASK 10.2 — override, above-tier denial, and vertical denial. Access is now
// resolved through three ordered gates, each producing a [FeatureAccessDecision]
// that carries a clear, machine-readable reason rather than a bare boolean:
//   1. Super-admin override grants EVERY feature regardless of the granted tier
//      and the active vertical (Requirement 10.8).
//   2. A Business_Vertical absent from the token's `allowedBusinessTypes` is
//      denied with a "not included in the license" reason (Requirement 10.9).
//   3. Otherwise the per-tier, per-vertical decision is delegated to the
//      existing `TierGating` (cumulative Basic→Pro→Premium→Enterprise gating,
//      Requirements 10.3/10.4). A feature that sits ABOVE the granted tier is
//      denied with a "requires a higher tier" reason, and the granted tier is
//      NEVER modified by the denial (Requirement 10.5).
//
// No new tier logic is introduced anywhere: the cumulative tier semantics, the
// hard-isolation registry, and the validated Gating_Config remain the single
// source of truth.
//
// Pure service-layer Dart with no Flutter / IO dependency.
// ============================================================================

import '../isolation/business_capability.dart';
import '../licensing/plan_tier.dart' as licensing;
import '../subscription/registry_integrity.dart';
import '../subscription/subscription_tier.dart';
import 'license_token.dart';

/// The reason an [OfflineGatingEngine] resolved a feature-access decision.
///
/// Carrying the reason (rather than a bare boolean) lets the service layer tell
/// the user *why* a feature is unavailable. In particular it distinguishes an
/// above-tier denial (Requirement 10.5) from a vertical that is not part of the
/// license at all (Requirement 10.9).
enum FeatureAccessReason {
  /// The granted Plan_Tier permits the capability for the active vertical
  /// (Requirements 10.3, 10.4).
  granted,

  /// The License_Token carries the super-admin override, which grants every
  /// feature regardless of the granted tier and the active vertical
  /// (Requirement 10.8).
  superAdminOverride,

  /// The active Business_Vertical is not among the license's allowed business
  /// types, so none of its features are accessible (Requirement 10.9).
  businessVerticalNotLicensed,

  /// The capability belongs to the active vertical but sits above the granted
  /// Plan_Tier; a higher tier is required (Requirement 10.5). The granted tier
  /// is not modified by this denial.
  requiresHigherTier,

  /// The capability is not part of the active vertical's feature set at any
  /// tier (hard isolation); it can never be granted for this vertical.
  notRegisteredForVertical,

  /// The capability identifier did not resolve to a known feature.
  unknownCapability,
}

/// The outcome of an offline feature-access check, carrying both the allow/deny
/// result and a clear [reason]/[message] explaining it.
///
/// This is the decision type Task 10.2 introduces so the gating layer can
/// surface *why* access was denied — an above-tier denial (Requirement 10.5)
/// versus a vertical that is not included in the license (Requirement 10.9) —
/// instead of returning an opaque boolean. [OfflineGatingEngine.isFeatureAccessible]
/// remains for callers that only need the boolean.
class FeatureAccessDecision {
  /// Whether access to the capability is granted.
  final bool isAllowed;

  /// The machine-readable reason for the decision.
  final FeatureAccessReason reason;

  /// The capability identifier the decision was made for.
  final String capability;

  /// The active Business_Vertical the decision was made for.
  final String businessVertical;

  /// The Plan_Tier granted by the License_Token at the time of the decision.
  ///
  /// The denial paths never modify this value (Requirement 10.5); it is carried
  /// only so callers can report the current grant alongside the reason.
  final SubscriptionTier grantedTier;

  /// A clear, human-readable explanation suitable for the service layer to
  /// surface to the user.
  final String message;

  const FeatureAccessDecision({
    required this.isAllowed,
    required this.reason,
    required this.capability,
    required this.businessVertical,
    required this.grantedTier,
    required this.message,
  });

  @override
  String toString() =>
      'FeatureAccessDecision(${isAllowed ? 'allow' : 'deny'}, '
      'reason: ${reason.name}, capability: $capability, '
      'vertical: $businessVertical, tier: ${grantedTier.name})';
}

/// Resolves offline feature access from a decrypted [LicenseToken] by reusing
/// the existing plan/feature gating engine.
///
/// Implementations derive the granted tier, allowed business types, and feature
/// flags from the token (Requirement 10.1) and resolve access through the
/// existing `PlanMappingBuilder`/`TierGating` pipeline (Requirement 10.2). They
/// add no new tier logic of their own (Requirement 10.7).
abstract class OfflineGatingEngine {
  /// Whether [capability] is accessible for [businessVertical] under the
  /// engine's active License_Token.
  ///
  /// The granted Plan_Tier is derived from the token and handed, together with
  /// the capability and vertical, to the existing gating engine — so the
  /// decision is enforced per Plan_Tier and per Business_Vertical by reuse
  /// (Requirements 10.2, 10.6).
  bool isFeatureAccessible(
    String capability, {
    required String businessVertical,
  });

  /// Resolves access to [capability] for [businessVertical] and returns a
  /// [FeatureAccessDecision] carrying the allow/deny result together with a
  /// clear reason.
  ///
  /// Three ordered gates produce the decision (Task 10.2):
  ///   1. A super-admin override grants every feature regardless of the granted
  ///      tier and the active vertical (Requirement 10.8).
  ///   2. A Business_Vertical absent from the token's allowed business types is
  ///      denied with a "not included in the license" reason (Requirement 10.9).
  ///   3. Otherwise the per-tier, per-vertical decision is delegated to the
  ///      existing tier-gating engine (Requirements 10.2, 10.3, 10.4). A
  ///      capability that sits above the granted tier is denied with a
  ///      "requires a higher tier" reason, without modifying the granted tier
  ///      (Requirement 10.5).
  FeatureAccessDecision resolveAccess(
    String capability, {
    required String businessVertical,
  });

  /// The granted [SubscriptionTier] derived from [token]'s `plan` field
  /// (Requirement 10.1). Reuses the existing plan-label normalization, so legacy
  /// aliases resolve exactly as the cloud path resolves them; it defines no new
  /// tier ordering.
  SubscriptionTier grantedTier(LicenseToken token);

  /// The allowed business verticals derived from [token]'s `allowedBusinessTypes`
  /// (Requirement 10.1).
  List<String> allowedBusinessTypes(LicenseToken token);

  /// The explicit feature flags derived from [token]'s `features`
  /// (Requirement 10.1).
  List<String> featureFlags(LicenseToken token);

  /// Whether [vertical] is among the allowed business types derived from
  /// [token] (Requirement 10.1). A token whose allowed list contains the
  /// wildcard `'*'` admits every vertical.
  ///
  /// This is the membership derivation only; denying a vertical's features
  /// *with a reason* is wired in Task 10.2.
  bool isBusinessVerticalAllowed(String vertical, LicenseToken token);
}

/// Default [OfflineGatingEngine] that adapts a single active [LicenseToken] to
/// the existing `TierGating` engine.
///
/// The engine holds the active token so [isFeatureAccessible] can derive the
/// granted tier without the UI/repository layer ever passing tier or token
/// around (the design keeps this at the service layer). The pure derivation
/// helpers ([grantedTier], [allowedBusinessTypes], [featureFlags],
/// [isBusinessVerticalAllowed]) accept any token so they can be reused by the
/// validator and tests.
class DefaultOfflineGatingEngine implements OfflineGatingEngine {
  /// The decrypted License_Token whose grants this engine enforces.
  final LicenseToken token;

  /// Resolves a capability identifier string to its [BusinessCapability]
  /// member, reusing the same name lookup the Gating_Config uses. Shared so the
  /// engine never builds its own enum table that could drift.
  final RegistryIntegrityGuard _capabilityGuard;

  /// Creates an engine bound to the active [token].
  DefaultOfflineGatingEngine(
    this.token, {
    RegistryIntegrityGuard? capabilityGuard,
  }) : _capabilityGuard = capabilityGuard ?? RegistryIntegrityGuard();

  @override
  bool isFeatureAccessible(
    String capability, {
    required String businessVertical,
  }) => resolveAccess(capability, businessVertical: businessVertical).isAllowed;

  @override
  FeatureAccessDecision resolveAccess(
    String capability, {
    required String businessVertical,
  }) {
    // The granted tier is derived once from the token (Requirement 10.1) and is
    // carried on every decision purely for reporting. NONE of the denial paths
    // below ever modify it (Requirement 10.5).
    final tier = grantedTier(token);

    // ---- Gate 1: super-admin override grants everything (Requirement 10.8) --
    // The override bypasses both the tier ladder and the vertical membership
    // check, so it is evaluated first and unconditionally allows access.
    if (token.superAdminOverride) {
      return FeatureAccessDecision(
        isAllowed: true,
        reason: FeatureAccessReason.superAdminOverride,
        capability: capability,
        businessVertical: businessVertical,
        grantedTier: tier,
        message:
            'Access granted by the super-admin override on the license, which '
            'permits all features regardless of plan tier or business vertical.',
      );
    }

    // ---- Gate 2: the active vertical must be licensed (Requirement 10.9) ----
    // A vertical absent from the token's allowedBusinessTypes has none of its
    // features available; deny with a clear "not included in the license"
    // reason before any tier resolution.
    if (!isBusinessVerticalAllowed(businessVertical, token)) {
      return FeatureAccessDecision(
        isAllowed: false,
        reason: FeatureAccessReason.businessVerticalNotLicensed,
        capability: capability,
        businessVertical: businessVertical,
        grantedTier: tier,
        message:
            'The "$businessVertical" business vertical is not included in this '
            'license, so its features are unavailable.',
      );
    }

    // Resolve the capability identifier to its enum member. An unknown
    // identifier cannot be granted, so deny (the existing engine's fail-safe).
    final cap = _capabilityGuard.resolve(capability);
    if (cap == null) {
      return FeatureAccessDecision(
        isAllowed: false,
        reason: FeatureAccessReason.unknownCapability,
        capability: capability,
        businessVertical: businessVertical,
        grantedTier: tier,
        message: 'Unknown feature "$capability"; access denied.',
      );
    }

    // ---- Gate 3: delegate the per-tier, per-vertical decision (10.2–10.4) ---
    // The cumulative Basic→Pro→Premium→Enterprise gating is resolved entirely
    // by the existing engine; no tier logic is reimplemented here.
    if (TierGating.isAllowedAtTier(businessVertical, cap, tier)) {
      return FeatureAccessDecision(
        isAllowed: true,
        reason: FeatureAccessReason.granted,
        capability: capability,
        businessVertical: businessVertical,
        grantedTier: tier,
        message:
            'Feature "$capability" is granted at the ${tier.name} tier for '
            '"$businessVertical".',
      );
    }

    // Denied by the tier gate. Distinguish "above the granted tier" (the
    // capability belongs to the vertical but needs a higher tier — Requirement
    // 10.5) from "not part of the vertical at all" (hard isolation forbids it).
    if (_isRegisteredForVertical(cap, businessVertical)) {
      return FeatureAccessDecision(
        isAllowed: false,
        reason: FeatureAccessReason.requiresHigherTier,
        capability: capability,
        businessVertical: businessVertical,
        grantedTier: tier,
        message:
            'Feature "$capability" requires a higher plan tier than the granted '
            '${tier.name} tier; the granted tier is unchanged.',
      );
    }

    return FeatureAccessDecision(
      isAllowed: false,
      reason: FeatureAccessReason.notRegisteredForVertical,
      capability: capability,
      businessVertical: businessVertical,
      grantedTier: tier,
      message:
          'Feature "$capability" is not part of the "$businessVertical" '
          'vertical and cannot be granted at any tier.',
    );
  }

  @override
  SubscriptionTier grantedTier(LicenseToken token) {
    // Reuse the existing plan-label normalization (handles basic/pro/premium/
    // enterprise plus legacy aliases) and map its 0..3 rank onto the existing
    // four-tier ladder. This introduces no new ordering of its own.
    final rank = licensing.planTierRank(token.plan);
    return SubscriptionTier.values[rank];
  }

  @override
  List<String> allowedBusinessTypes(LicenseToken token) =>
      List.unmodifiable(token.allowedBusinessTypes);

  @override
  List<String> featureFlags(LicenseToken token) =>
      List.unmodifiable(token.features);

  @override
  bool isBusinessVerticalAllowed(String vertical, LicenseToken token) {
    final allowed = token.allowedBusinessTypes;
    // A wildcard license admits every vertical.
    if (allowed.contains('*')) {
      return true;
    }
    final target = _normalizeVertical(vertical);
    for (final entry in allowed) {
      if (_normalizeVertical(entry) == target) {
        return true;
      }
    }
    return false;
  }

  /// Whether [cap] is a Registered_Capability for [vertical] under the
  /// hard-isolation [businessCapabilityRegistry].
  ///
  /// Used only to label a tier-gate denial: a capability that *is* registered
  /// for the vertical but was denied must sit above the granted tier
  /// (Requirement 10.5), whereas one that is not registered is forbidden by
  /// hard isolation at any tier. The registry lookup mirrors the existing
  /// `TierGating` normalization (strip an enum-style `BusinessType.` prefix,
  /// preserve the registry's camelCase keys) so it matches the same source of
  /// truth — no new tier logic is introduced.
  static bool _isRegisteredForVertical(
    BusinessCapability cap,
    String vertical,
  ) {
    final typeKey = vertical.contains('.')
        ? vertical.split('.').last
        : vertical;
    final registered = businessCapabilityRegistry[typeKey];
    return registered != null && registered.contains(cap);
  }

  /// Normalizes a business-vertical string for comparison, mirroring the
  /// normalization the existing isolation layer applies: accepts both raw keys
  /// (`'grocery'`) and enum-style strings (`'BusinessType.grocery'`), and
  /// compares case-insensitively.
  static String _normalizeVertical(String type) {
    final tail = type.contains('.') ? type.split('.').last : type;
    return tail.trim().toLowerCase();
  }
}
