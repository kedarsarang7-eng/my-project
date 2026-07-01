// ============================================================================
// PRODUCT DECISION — flag-only governance record + validator (R27)
// ============================================================================
// Phase 4 of the pharmacy remediation deliberately does NOT implement the seven
// deferred capabilities (credit limits, loyalty points, delivery challan,
// online store catalog, proforma invoice, e-Way bill, multi-firm). Instead it
// tracks a governance decision for each: a record whose `status` is exactly
// "deferred" or "scheduled", and whose state may only change through a complete
// sign-off (approver identity + decision timestamp).
//
// This is a GOVERNANCE ARTIFACT — a value object + validator that guards a
// tracked record — NOT a runtime feature. It exists so that none of the seven
// capabilities is implemented, removed, or hidden without a recorded sign-off
// (R27.4), and so that an approved ("scheduled") capability becomes a new
// requirement subject to the cross-cutting constraints R1–R5 (R27.5).
//
// Requirements:
//   - R27.1 : maintain a record for each of the seven capabilities, each with
//             a status that is EXACTLY "deferred" or "scheduled".
//   - R27.2 : creating/updating a record requires a complete sign-off
//             (non-empty approver identity + present decision timestamp)
//             BEFORE the record is persisted/accepted.
//   - R27.3 : an incomplete sign-off (or invalid status) is rejected, the
//             prior state is retained unchanged, and an error is returned.
//   - R27.4 : enforced by R27.2/R27.3 — no state change without a sign-off.
//   - R27.5 : a "scheduled" decision is the trigger for a new requirement that
//             must then satisfy R1–R5 (documented; out of scope for this code).
//
// Pharmacy-scoped, additive: nothing here changes the other 18 verticals
// (Requirement 5.3).
// ============================================================================

/// The seven product capabilities that are flagged-only (deferred) for the
/// pharmacy vertical and tracked by a governance decision (R27.1).
enum ProductCapability {
  creditLimits,
  loyaltyPoints,
  deliveryChallan,
  onlineStoreCatalog,
  proformaInvoice,
  eWayBill,
  multiFirm,
}

/// Stable wire/string keys for [ProductCapability] used in the tracked
/// governance artifact and for (de)serialization.
extension ProductCapabilityKey on ProductCapability {
  String get key {
    switch (this) {
      case ProductCapability.creditLimits:
        return 'creditLimits';
      case ProductCapability.loyaltyPoints:
        return 'loyaltyPoints';
      case ProductCapability.deliveryChallan:
        return 'deliveryChallan';
      case ProductCapability.onlineStoreCatalog:
        return 'onlineStoreCatalog';
      case ProductCapability.proformaInvoice:
        return 'proformaInvoice';
      case ProductCapability.eWayBill:
        return 'eWayBill';
      case ProductCapability.multiFirm:
        return 'multiFirm';
    }
  }

  /// Resolve a capability from its stable [key]; returns `null` when no
  /// capability matches.
  static ProductCapability? fromKey(String? key) {
    if (key == null) return null;
    for (final capability in ProductCapability.values) {
      if (capability.key == key) return capability;
    }
    return null;
  }
}

/// The only two statuses a product decision may hold (R27.1).
///
/// The wire form is EXACTLY the lowercase strings `"deferred"` / `"scheduled"`;
/// any other value is rejected by [ProductDecisionValidator].
enum ProductDecisionStatus { deferred, scheduled }

/// Wire/string mapping for [ProductDecisionStatus].
extension ProductDecisionStatusValue on ProductDecisionStatus {
  String get value {
    switch (this) {
      case ProductDecisionStatus.deferred:
        return 'deferred';
      case ProductDecisionStatus.scheduled:
        return 'scheduled';
    }
  }

  /// Parse a status string, accepting ONLY the exact values `"deferred"` and
  /// `"scheduled"`. Returns `null` for anything else (including null, empty, a
  /// differently-cased value, or surrounding whitespace) so the validator can
  /// reject it (R27.1, R27.3).
  static ProductDecisionStatus? parse(String? raw) {
    switch (raw) {
      case 'deferred':
        return ProductDecisionStatus.deferred;
      case 'scheduled':
        return ProductDecisionStatus.scheduled;
      default:
        return null;
    }
  }
}

/// A complete sign-off: the approver's identity plus the moment the decision
/// was made. A [SignOff] instance is, by construction, always complete — both
/// fields are non-null and the identity is non-empty (validated in the
/// factory). Incomplete sign-off attempts never produce a [SignOff]; they are
/// surfaced as a [ProductDecisionError] by the validator (R27.2, R27.3).
class SignOff {
  /// The non-empty identity of the approver who authorized the decision.
  final String approverIdentity;

  /// The moment the decision was made/approved (always present).
  final DateTime decisionTimestamp;

  const SignOff._(this.approverIdentity, this.decisionTimestamp);

  /// Build a [SignOff] from raw inputs, returning `null` when the sign-off is
  /// incomplete: a missing/blank approver identity or a missing decision
  /// timestamp (R27.2). The approver identity is trimmed before storage.
  static SignOff? tryCreate({
    String? approverIdentity,
    DateTime? decisionTimestamp,
  }) {
    final identity = approverIdentity?.trim();
    if (identity == null || identity.isEmpty) return null;
    if (decisionTimestamp == null) return null;
    return SignOff._(identity, decisionTimestamp);
  }

  Map<String, dynamic> toJson() => {
    'approverIdentity': approverIdentity,
    'decisionTimestamp': decisionTimestamp.toUtc().toIso8601String(),
  };

  @override
  String toString() =>
      'SignOff(approver: $approverIdentity, at: '
      '${decisionTimestamp.toUtc().toIso8601String()})';
}

/// An immutable, validated governance decision for a single capability
/// (R27.1). Only obtainable via [ProductDecisionValidator]; an instance is
/// therefore guaranteed to carry a valid status and a complete sign-off.
class ProductDecision {
  final ProductCapability capability;
  final ProductDecisionStatus status;
  final SignOff signOff;

  const ProductDecision._({
    required this.capability,
    required this.status,
    required this.signOff,
  });

  Map<String, dynamic> toJson() => {
    'capability': capability.key,
    'status': status.value,
    'signOff': signOff.toJson(),
  };

  @override
  String toString() =>
      'ProductDecision(${capability.key}: ${status.value}, $signOff)';
}

/// Why a product-decision change was rejected (R27.3). Carries a stable [code]
/// for programmatic handling and a human-readable [message].
class ProductDecisionError implements Exception {
  /// `INVALID_STATUS` or `INCOMPLETE_SIGNOFF`.
  final String code;
  final String message;

  const ProductDecisionError._(this.code, this.message);

  /// The status was not exactly `"deferred"` or `"scheduled"` (R27.1).
  const ProductDecisionError.invalidStatus(this.message)
    : code = 'INVALID_STATUS';

  /// The sign-off was missing an approver identity and/or a decision timestamp
  /// (R27.2).
  const ProductDecisionError.incompleteSignOff(this.message)
    : code = 'INCOMPLETE_SIGNOFF';

  @override
  String toString() => 'ProductDecisionError[$code]: $message';
}

/// The outcome of validating a product-decision change: either a valid
/// [decision] or an [error]. Exactly one of the two is non-null.
class ProductDecisionResult {
  final ProductDecision? decision;
  final ProductDecisionError? error;

  const ProductDecisionResult._({this.decision, this.error});

  factory ProductDecisionResult.ok(ProductDecision decision) =>
      ProductDecisionResult._(decision: decision);

  factory ProductDecisionResult.failure(ProductDecisionError error) =>
      ProductDecisionResult._(error: error);

  bool get isValid => error == null;
}

/// Validates a proposed product-decision change before it may be persisted
/// (R27.2, R27.3). Stateless and pure — it never mutates anything; persistence
/// and prior-state retention are the [ProductDecisionRegistry]'s job.
class ProductDecisionValidator {
  const ProductDecisionValidator();

  /// Validate a proposed decision built from raw inputs.
  ///
  /// Rejects, in order:
  ///   1. a status that is not exactly `"deferred"`/`"scheduled"` (R27.1), and
  ///   2. an incomplete sign-off — missing/blank approver identity or missing
  ///      decision timestamp (R27.2).
  ///
  /// Returns a valid [ProductDecisionResult] only when both checks pass.
  ProductDecisionResult validate({
    required ProductCapability capability,
    required String? status,
    required String? approverIdentity,
    required DateTime? decisionTimestamp,
  }) {
    final parsedStatus = ProductDecisionStatusValue.parse(status);
    if (parsedStatus == null) {
      return ProductDecisionResult.failure(
        ProductDecisionError.invalidStatus(
          'Status must be exactly "deferred" or "scheduled" (got '
          '${status == null ? 'null' : '"$status"'}).',
        ),
      );
    }

    final signOff = SignOff.tryCreate(
      approverIdentity: approverIdentity,
      decisionTimestamp: decisionTimestamp,
    );
    if (signOff == null) {
      return ProductDecisionResult.failure(
        const ProductDecisionError.incompleteSignOff(
          'A complete sign-off is required before a product decision can be '
          'recorded: provide a non-empty approver identity and a decision '
          'timestamp.',
        ),
      );
    }

    return ProductDecisionResult.ok(
      ProductDecision._(
        capability: capability,
        status: parsedStatus,
        signOff: signOff,
      ),
    );
  }
}

/// In-memory governance register for the seven product decisions. Guarantees
/// the R27 invariants:
///   - a decision is persisted only through a valid, fully-signed-off change
///     (R27.2);
///   - a rejected change leaves the prior state untouched and surfaces an
///     error (R27.3, R27.4).
///
/// This backs the tracked governance artifact; it is not wired into any
/// runtime feature flow.
class ProductDecisionRegistry {
  final ProductDecisionValidator _validator;
  final Map<ProductCapability, ProductDecision> _decisions = {};

  ProductDecisionRegistry({ProductDecisionValidator? validator})
    : _validator = validator ?? const ProductDecisionValidator();

  /// The current decision recorded for [capability], or `null` when none has
  /// been recorded yet (the capability remains deferred-by-default with no
  /// sign-off on record — R27.4).
  ProductDecision? decisionFor(ProductCapability capability) =>
      _decisions[capability];

  /// An immutable snapshot of all recorded decisions.
  Map<ProductCapability, ProductDecision> get decisions =>
      Map.unmodifiable(_decisions);

  /// Validate and, only on success, persist a decision change for [capability].
  ///
  /// On a valid, fully-signed-off change the registry stores the new decision
  /// and returns it (R27.2). On an invalid status or incomplete sign-off the
  /// registry makes NO change — any previously recorded decision is retained
  /// exactly as-is — and returns the error (R27.3, R27.4).
  ProductDecisionResult record({
    required ProductCapability capability,
    required String? status,
    required String? approverIdentity,
    required DateTime? decisionTimestamp,
  }) {
    final result = _validator.validate(
      capability: capability,
      status: status,
      approverIdentity: approverIdentity,
      decisionTimestamp: decisionTimestamp,
    );

    if (result.isValid) {
      // Persist only after a complete, valid sign-off (R27.2).
      _decisions[capability] = result.decision!;
    }
    // On failure we intentionally leave `_decisions` untouched so the prior
    // state is retained (R27.3).
    return result;
  }
}
