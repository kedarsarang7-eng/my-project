// ============================================================================
// LICENSE TOKEN — Dart view of the decrypted offline License_Token
// ============================================================================
// Feature: offline-license-activation (Task 10.1)
//
// The License_Token is the RS256-signed license JWT returned by the
// License_Server during activation and stored (encrypted) in the
// Local_License_File. On the Dart side it is the *decrypted* token the
// Activation_Service / License_Validator hand to the service layer.
//
// This model is a MINIMAL, read-only view that carries exactly the unchanged
// `LicenseKeyPayload` fields the Offline_Gating_Engine needs to derive access
// (Requirement 10.1): the granted plan, the allowed business types, the
// explicit feature flags, and the super-admin override. It adds, removes,
// renames, and retypes NO `LicenseKeyPayload` field (Requirement 2.2) — it
// simply mirrors the subset the gating layer reads.
//
// It is pure data with no Flutter / IO dependency, so it is safe to use from
// the service layer and is trivially testable.
// ============================================================================

import 'package:flutter/foundation.dart';

/// A read-only, service-layer view of the decrypted offline License_Token.
///
/// Construct it from the decoded JWT claims with [LicenseToken.fromClaims].
/// The carried fields mirror the unchanged `LicenseKeyPayload`:
///
/// * [plan] — the granted plan tier string (`basic` / `pro` / `premium` /
///   `enterprise`, or a legacy alias the licensing layer already normalizes).
/// * [allowedBusinessTypes] — the subset of business verticals this license
///   permits.
/// * [features] — explicit feature flags carried by the license.
/// * [superAdminOverride] — whether the license bypasses all plan/feature
///   checks.
///
/// [tenantId] is included as the license identity; it is informational for the
/// gating layer.
@immutable
class LicenseToken {
  /// UUID linking the token to exactly one tenant.
  final String tenantId;

  /// The granted plan tier string from the license payload.
  final String plan;

  /// The business verticals this license permits.
  ///
  /// May contain `'*'` for an all-verticals license. Stored verbatim from the
  /// payload; normalization is applied by the gating engine when it queries
  /// membership.
  final List<String> allowedBusinessTypes;

  /// Explicit feature flags carried by the license payload.
  final List<String> features;

  /// Whether this license carries the super-admin override.
  final bool superAdminOverride;

  /// Creates an immutable license-token view. The list fields are wrapped in
  /// unmodifiable views so the token cannot be mutated through the references
  /// passed in.
  LicenseToken({
    required this.tenantId,
    required this.plan,
    required List<String> allowedBusinessTypes,
    required List<String> features,
    required this.superAdminOverride,
  }) : allowedBusinessTypes = List.unmodifiable(allowedBusinessTypes),
       features = List.unmodifiable(features);

  /// Builds a [LicenseToken] from the decoded JWT [claims] of a License_Token.
  ///
  /// Reads only the `LicenseKeyPayload` fields the gating layer needs and
  /// tolerates missing/loosely-typed entries with safe defaults (empty
  /// collections, empty plan, override `false`) so a malformed claim set never
  /// throws here and instead resolves to the most restrictive access downstream.
  factory LicenseToken.fromClaims(Map<String, dynamic> claims) {
    return LicenseToken(
      tenantId: claims['tenantId']?.toString() ?? '',
      plan: claims['plan']?.toString() ?? '',
      allowedBusinessTypes: _stringList(claims['allowedBusinessTypes']),
      features: _stringList(claims['features']),
      superAdminOverride: claims['superAdminOverride'] == true,
    );
  }

  /// Coerces a dynamic JSON value into a `List<String>`, dropping nulls and
  /// returning an empty list for any non-list value.
  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .toList(growable: false);
    }
    return const <String>[];
  }

  @override
  String toString() =>
      'LicenseToken(tenant: $tenantId, plan: $plan, '
      'allowed: ${allowedBusinessTypes.length}, '
      'features: ${features.length}, override: $superAdminOverride)';
}
