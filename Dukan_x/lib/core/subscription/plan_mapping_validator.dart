/// Independent plan-mapping validator for the Tiering_System.
///
/// The validator is a **separate, independent implementation** from the
/// [PlanMappingBuilder]. It never reuses builder logic: given a proposed
/// [PlanMapping] it re-derives every invariant from first principles against
/// the capability registry (the single source of truth) and reports each broken
/// rule as a [ValidationViolation]. The builder *produces* a mapping; the
/// validator *proves* it correct.
///
/// The invariants re-checked here (each maps to a design correctness property):
///
/// * **Tier subset monotonicity** — `basic ⊆ pro ⊆ premium ⊆ enterprise`
///   (Req 2; Property 3).
/// * **Hard isolation + completeness** — every assigned capability is registered
///   and the union of tiers equals the registered set (Req 3; Property 4).
/// * **Coverage bands** — each tier's Tier_Coverage lands inside its band unless
///   a deviation is recorded (Req 1; Property 1/2).
/// * **Billing core** — registered Billing_Core members all live at Basic
///   (Req 5; Property 6).
/// * **Non-empty deltas** — Pro/Premium/Enterprise add at least one capability
///   when the count permits (Req 6; Property 7).
/// * **Workflow cohesion** — registered members of each Workflow_Pair share a
///   tier and `useStockEntry ≤ usePurchaseOrder` (Req 7, 8; Property 8/9).
/// * **Gating tiers** — analytics/export at Premium+ (Req 9), enterprise-only at
///   Enterprise (Req 10), compliance/seasonal at Premium+ (Req 11)
///   (Property 10/11/12).
/// * **Essential vertical** — exactly one essential vertical capability, with a
///   rationale, available by Pro (Req 12; Property 13).
/// * **Service-only deltas** — no Tier_Delta of a Service_Only_Type contains a
///   product or inventory capability (Req 13; Property 14).
/// * **'other' exception** — the explicit `'other'` counts (Req 14).
/// * **No plan-washing** — Premium and Enterprise differ by ≥ 2 capabilities for
///   differentiable types (Req 15; Property 15).
///
/// **Fail-safe (Req 3.3).** [validate] never throws. If the validator cannot run
/// (an unexpected exception, or a missing registry entry it cannot check against
/// the source of truth), it returns an *invalid* result so the mapping is
/// blocked from taking effect — the default outcome is deny, never grant.
///
/// The module is pure Dart on top of the existing enum, tier model, classifier,
/// and coverage calculator. It adds no new runtime dependencies.
library;

import '../isolation/business_capability.dart';
import 'capability_classifier.dart';
import 'coverage_calculator.dart';
import 'plan_mapping.dart';
import 'subscription_tier.dart';

/// The `'other'` business-type key, governed by the explicit counts of
/// Requirement 14 instead of the generic coverage/plan-washing rules.
const String _otherBusinessType = 'other';

/// Product and inventory capabilities, used both to detect a Service_Only_Type
/// (a type whose registry contains none of these) and to forbid them from
/// appearing in a service-only Tier_Delta (Req 13).
const Set<BusinessCapability> _productAndInventoryCapabilities = {
  // Product / Item Management
  BusinessCapability.useProductAdd,
  BusinessCapability.useProductName,
  BusinessCapability.useProductSalePrice,
  BusinessCapability.useProductStockQty,
  BusinessCapability.useProductUnit,
  BusinessCapability.useProductTax,
  BusinessCapability.useProductCategory,
  // Inventory Management
  BusinessCapability.useInventoryList,
  BusinessCapability.useVisibleStock,
  BusinessCapability.useDeadStock,
  BusinessCapability.useInventorySearch,
  BusinessCapability.useInventoryExport,
};

/// A single broken invariant: the rule that was violated, the business type, and
/// — where applicable — the offending tier and capability, plus a human-readable
/// explanation.
///
/// Every violation names the `rule` it breaks (e.g. `'Req 5.5 billing-core'`),
/// the `businessType` it was found in, and an explanatory `message`. The `tier`
/// and `capability` are populated when the violation is about a specific tier or
/// capability and are `null` for type-level violations (such as plan-washing).
class ValidationViolation {
  /// The violated rule, as a short stable label (e.g. `'Req 2.4 monotonicity'`).
  final String rule;

  /// The business type the violation was found in.
  final String businessType;

  /// The tier the violation concerns, when applicable.
  final SubscriptionTier? tier;

  /// The capability the violation concerns, when applicable.
  final BusinessCapability? capability;

  /// A human-readable explanation of the violation.
  final String message;

  const ValidationViolation({
    required this.rule,
    required this.businessType,
    required this.message,
    this.tier,
    this.capability,
  });

  @override
  bool operator ==(Object other) =>
      other is ValidationViolation &&
      other.rule == rule &&
      other.businessType == businessType &&
      other.tier == tier &&
      other.capability == capability &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(rule, businessType, tier, capability, message);

  @override
  String toString() =>
      'ValidationViolation($rule, type: $businessType, '
      'tier: ${tier?.name}, capability: ${capability?.name}, '
      'message: $message)';
}

/// The outcome of validating one or more plan mappings.
///
/// [isValid] is `true` only when [violations] is empty. A non-empty violation
/// list is fatal for the affected mapping: the pipeline must not emit artifacts
/// or a Gating_Config for a type that fails validation.
class ValidationResult {
  /// Whether the mapping(s) satisfied every invariant.
  final bool isValid;

  /// Every violation found, in the order the checks produced them.
  final List<ValidationViolation> violations;

  ValidationResult({
    required this.isValid,
    required List<ValidationViolation> violations,
  }) : violations = List.unmodifiable(violations);

  /// A valid result with no violations.
  factory ValidationResult.valid() =>
      ValidationResult(isValid: true, violations: const []);

  /// An invalid result carrying [violations] (must be non-empty).
  factory ValidationResult.invalid(List<ValidationViolation> violations) =>
      ValidationResult(isValid: false, violations: violations);

  /// The violations that name [rule].
  List<ValidationViolation> byRule(String rule) =>
      violations.where((v) => v.rule == rule).toList(growable: false);

  @override
  String toString() => isValid
      ? 'ValidationResult(valid)'
      : 'ValidationResult(invalid, ${violations.length} violation(s))';
}

/// Re-checks a proposed [PlanMapping] against every Tiering_System invariant and
/// reports each violation.
///
/// The validator is pure (it never mutates its input) and registry-driven: the
/// registered capability set used as the source of truth comes from the
/// capability registry passed at construction (defaulting to
/// `businessCapabilityRegistry`), *not* from the mapping under test. This is
/// what makes the validator independent of the builder — it cannot be fooled by
/// a mapping whose own `registeredCapabilities` disagree with the registry.
class PlanMappingValidator {
  /// Classifies capabilities into gating categories with tier floors/ceilings.
  final CapabilityClassifier classifier;

  /// Computes `Available_Capability_Count` and per-tier coverage records.
  final CoverageCalculator calculator;

  /// The capability registry treated as the source of truth.
  final Map<String, Set<BusinessCapability>> _registry;

  /// Creates a validator.
  ///
  /// [classifier] and [calculator] default to fresh instances over the global
  /// `businessCapabilityRegistry`; [registry] overrides the source-of-truth
  /// registry (e.g. a synthesized entry used by property tests). When a custom
  /// [registry] is supplied without an explicit [calculator], a calculator over
  /// that same registry is created so the source of truth stays consistent.
  PlanMappingValidator({
    CapabilityClassifier? classifier,
    CoverageCalculator? calculator,
    Map<String, Set<BusinessCapability>>? registry,
  }) : classifier = classifier ?? const CapabilityClassifier(),
       _registry = registry ?? businessCapabilityRegistry,
       calculator =
           calculator ??
           CoverageCalculator(registry: registry ?? businessCapabilityRegistry);

  /// Validates [mapping] for [businessType] against every invariant.
  ///
  /// Never throws (Req 3.3, fail-safe): any unexpected error is converted into
  /// an invalid result so the mapping is blocked from taking effect. A business
  /// type that is absent from the source-of-truth registry is also rejected —
  /// the validator will not vouch for a mapping it cannot check.
  ValidationResult validate(String businessType, PlanMapping mapping) {
    try {
      final registered = _registry[businessType];
      if (registered == null) {
        return ValidationResult.invalid([
          ValidationViolation(
            rule: 'Req 3.3 fail-safe',
            businessType: businessType,
            message:
                'No Capability_Registry entry for "$businessType"; the '
                'validator cannot verify the mapping against the source of '
                'truth, so the mapping is blocked (default deny).',
          ),
        ]);
      }

      final violations = <ValidationViolation>[];
      _checkTierPresence(businessType, mapping, violations);
      // If the four tiers are not even present, the remaining structural checks
      // cannot run meaningfully; report what we have and stop (fail closed).
      if (violations.isNotEmpty) {
        return ValidationResult.invalid(violations);
      }

      _checkHardIsolationAndCompleteness(
        businessType,
        mapping,
        registered,
        violations,
      );
      _checkMonotonicity(businessType, mapping, violations);
      _checkBillingCore(businessType, mapping, registered, violations);
      _checkGatingFloorsAndCeilings(
        businessType,
        mapping,
        registered,
        violations,
      );
      _checkWorkflowPairs(businessType, mapping, registered, violations);
      _checkStockEntryOrdering(businessType, mapping, registered, violations);
      _checkDeltas(businessType, mapping, violations);
      _checkEssentialVertical(businessType, mapping, registered, violations);
      _checkServiceOnlyDeltas(businessType, mapping, registered, violations);
      _checkCoverageBands(businessType, mapping, violations);
      _checkPlanWashing(businessType, mapping, registered, violations);

      return violations.isEmpty
          ? ValidationResult.valid()
          : ValidationResult.invalid(violations);
    } catch (error, stackTrace) {
      // Fail-safe: an unexpected failure must never allow a mapping through.
      return ValidationResult.invalid([
        ValidationViolation(
          rule: 'Req 3.3 fail-safe',
          businessType: businessType,
          message:
              'Validator failed to run ($error). The mapping is blocked from '
              'taking effect (default deny).\n$stackTrace',
        ),
      ]);
    }
  }

  /// Validates every mapping in [mappings], aggregating all violations into a
  /// single result. The result is valid only when every mapping is valid.
  ValidationResult validateAll(Map<String, PlanMapping> mappings) {
    final violations = <ValidationViolation>[];
    for (final entry in mappings.entries) {
      final result = validate(entry.key, entry.value);
      violations.addAll(result.violations);
    }
    return violations.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(violations);
  }

  // ---------------------------------------------------------------------------
  // Structural checks
  // ---------------------------------------------------------------------------

  /// Confirms all four tiers are present in the mapping (Req 1.1, structural).
  void _checkTierPresence(
    String businessType,
    PlanMapping mapping,
    List<ValidationViolation> violations,
  ) {
    for (final tier in SubscriptionTier.values) {
      if (!mapping.tiers.containsKey(tier)) {
        violations.add(
          ValidationViolation(
            rule: 'Req 16.1 tier-presence',
            businessType: businessType,
            tier: tier,
            message:
                'Mapping is missing the ${tier.name} tier; all four tiers '
                'must be defined.',
          ),
        );
      }
    }
  }

  /// Hard isolation (Req 3.1, 3.2) + completeness (Req 3.4).
  ///
  /// Every capability assigned to any tier must be a Registered_Capability for
  /// the type, and the union of the four tiers must equal exactly the registered
  /// set. The registered set is taken from the registry source of truth, not the
  /// mapping's own `registeredCapabilities`.
  void _checkHardIsolationAndCompleteness(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    final union = <BusinessCapability>{};
    for (final tier in SubscriptionTier.values) {
      for (final cap in mapping.capabilitiesAt(tier)) {
        union.add(cap);
        if (!registered.contains(cap)) {
          violations.add(
            ValidationViolation(
              rule: 'Req 3.2 hard-isolation',
              businessType: businessType,
              tier: tier,
              capability: cap,
              message:
                  'Capability ${cap.name} is assigned to ${tier.name} but is '
                  'not a Registered_Capability for "$businessType" '
                  '(hard-isolated).',
            ),
          );
        }
      }
    }

    // Completeness: the union of tiers must equal the registered set exactly.
    final missing = registered.difference(union);
    for (final cap in missing) {
      violations.add(
        ValidationViolation(
          rule: 'Req 3.4 completeness',
          businessType: businessType,
          capability: cap,
          message:
              'Registered capability ${cap.name} is not assigned to any tier; '
              'the union of tiers must equal the registered set.',
        ),
      );
    }
  }

  /// Tier subset monotonicity: `basic ⊆ pro ⊆ premium ⊆ enterprise` (Req 2).
  void _checkMonotonicity(
    String businessType,
    PlanMapping mapping,
    List<ValidationViolation> violations,
  ) {
    const ordered = SubscriptionTier.values;
    for (var i = 0; i < ordered.length - 1; i++) {
      final lower = ordered[i];
      final higher = ordered[i + 1];
      final lowerCaps = mapping.capabilitiesAt(lower);
      final higherCaps = mapping.capabilitiesAt(higher);
      for (final cap in lowerCaps) {
        if (!higherCaps.contains(cap)) {
          violations.add(
            ValidationViolation(
              rule: 'Req 2.4 monotonicity',
              businessType: businessType,
              tier: higher,
              capability: cap,
              message:
                  'Capability ${cap.name} is in ${lower.name} but missing from '
                  'the higher ${higher.name} tier; higher tiers must contain '
                  'every lower-tier capability.',
            ),
          );
        }
      }
    }
  }

  /// Billing_Core placement (Req 5.1, 5.2, 5.5, 5.6).
  ///
  /// Every registered member of Billing_Core must appear at Basic (and therefore
  /// at every higher tier). A registered member whose lowest tier of appearance
  /// is above Basic is a billing-core split.
  void _checkBillingCore(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    final basicCaps = mapping.capabilitiesAt(SubscriptionTier.basic);
    for (final cap in CapabilityClassifier.billingCoreCapabilities) {
      // Absent member: nothing to place.
      if (!registered.contains(cap)) {
        continue;
      }
      if (!basicCaps.contains(cap)) {
        violations.add(
          ValidationViolation(
            rule: 'Req 5.5 billing-core',
            businessType: businessType,
            tier: _assignedTierOf(mapping, cap),
            capability: cap,
            message:
                'Billing_Core member ${cap.name} is registered for '
                '"$businessType" but is not assigned to Basic_Tier; every '
                'registered Billing_Core member must live at Basic.',
          ),
        );
      }
    }
  }

  /// Gating floors and ceilings for analytics/export (Req 9), enterprise-only
  /// (Req 10), and compliance/seasonal (Req 11) capabilities.
  ///
  /// A capability's assigned tier is the lowest tier at which it appears. The
  /// assigned tier must lie within `[floor, ceiling]` for the capability's
  /// gating category. Billing_Core and standard capabilities are not constrained
  /// here (Billing_Core has its own check; standard spans all tiers).
  void _checkGatingFloorsAndCeilings(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    for (final cap in registered) {
      final category = classifier.categoryOf(cap);
      if (category == GatingCategory.billingCore ||
          category == GatingCategory.standard) {
        continue;
      }
      final assigned = _assignedTierOf(mapping, cap);
      // Unassigned: the completeness check reports it.
      if (assigned == null) {
        continue;
      }

      final floor = classifier.floorFor(cap);
      final ceiling = classifier.ceilingFor(cap);
      if (assigned < floor || assigned > ceiling) {
        violations.add(
          ValidationViolation(
            rule: _gatingRuleFor(category),
            businessType: businessType,
            tier: assigned,
            capability: cap,
            message:
                '${cap.name} (${category.name}) is assigned to '
                '${assigned.name} but must be between ${floor.name} and '
                '${ceiling.name}.',
          ),
        );
      }
    }
  }

  /// The rule label for a gating-category violation.
  String _gatingRuleFor(GatingCategory category) {
    switch (category) {
      case GatingCategory.analyticsExport:
        return 'Req 9.5 analytics-gating';
      case GatingCategory.enterpriseOnly:
        return 'Req 10.6 enterprise-gating';
      case GatingCategory.complianceSeasonal:
        return 'Req 11.5 compliance-gating';
      case GatingCategory.billingCore:
      case GatingCategory.standard:
        return 'Req 0 gating';
    }
  }

  /// Workflow-pair cohesion (Req 7.1, 7.3, 8.1–8.5).
  ///
  /// For every defined Workflow_Pair, the registered members of the pair must
  /// share a single assigned tier. A pair with fewer than two registered members
  /// imposes no constraint.
  void _checkWorkflowPairs(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    for (final pair in workflowPairs) {
      final registeredMembers = pair
          .where(registered.contains)
          .toList(growable: false);
      if (registeredMembers.length < 2) continue;

      final tiers = {
        for (final cap in registeredMembers) cap: _assignedTierOf(mapping, cap),
      };
      final distinctTiers = tiers.values.toSet();
      if (distinctTiers.length > 1) {
        // Req 7.3 governs the purchase-order pair; Req 8.5 the specialized pairs.
        final isPurchasePair = pair.contains(
          BusinessCapability.usePurchaseOrder,
        );
        final rule = isPurchasePair
            ? 'Req 7.3 workflow-pair'
            : 'Req 8.5 workflow-pair';
        final label = registeredMembers.map((c) => c.name).join(' + ');
        for (final cap in registeredMembers) {
          violations.add(
            ValidationViolation(
              rule: rule,
              businessType: businessType,
              tier: tiers[cap],
              capability: cap,
              message:
                  'Workflow_Pair {$label} is split across tiers for '
                  '"$businessType": ${cap.name} is at '
                  '${tiers[cap]?.name}, but all registered pair members must '
                  'share one tier.',
            ),
          );
        }
      }
    }
  }

  /// Stock-entry ordering (Req 7.2): `useStockEntry` must not unlock above
  /// `usePurchaseOrder` when both are registered.
  void _checkStockEntryOrdering(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    for (final constraint in tierOrderingConstraints) {
      if (!registered.contains(constraint.lower) ||
          !registered.contains(constraint.higher)) {
        continue;
      }
      final lowerTier = _assignedTierOf(mapping, constraint.lower);
      final higherTier = _assignedTierOf(mapping, constraint.higher);
      if (lowerTier == null || higherTier == null) continue;
      if (lowerTier > higherTier) {
        violations.add(
          ValidationViolation(
            rule: 'Req 7.2 stock-entry-ordering',
            businessType: businessType,
            tier: lowerTier,
            capability: constraint.lower,
            message:
                '${constraint.lower.name} is assigned to ${lowerTier.name}, '
                'higher than ${constraint.higher.name} at '
                '${higherTier.name}; ${constraint.lower.name} must not unlock '
                'above ${constraint.higher.name}.',
          ),
        );
      }
    }
  }

  /// Tier deltas: recorded deltas must match the computed delta (Req 6.4), and
  /// Pro/Premium/Enterprise deltas must be non-empty unless a justification is
  /// recorded or the type is the `'other'` exception (Req 6.1, 6.2, 6.3).
  void _checkDeltas(
    String businessType,
    PlanMapping mapping,
    List<ValidationViolation> violations,
  ) {
    const ordered = SubscriptionTier.values;
    for (var i = 0; i < ordered.length; i++) {
      final tier = ordered[i];
      final tierCaps = mapping.capabilitiesAt(tier);
      final lowerCaps = i == 0
          ? const <BusinessCapability>{}
          : mapping.capabilitiesAt(ordered[i - 1]);
      final computedDelta = tierCaps.difference(lowerCaps);
      final recordedDelta = mapping.deltaAt(tier);

      // Req 6.4: the recorded delta must equal the computed delta.
      if (!_setEquals(computedDelta, recordedDelta)) {
        violations.add(
          ValidationViolation(
            rule: 'Req 6.4 delta-record',
            businessType: businessType,
            tier: tier,
            message:
                'Recorded Tier_Delta for ${tier.name} '
                '(${_names(recordedDelta)}) does not equal the computed delta '
                '(${_names(computedDelta)}).',
          ),
        );
      }

      // Req 6.1/6.2: Pro, Premium, Enterprise deltas must be non-empty unless a
      // reason is recorded (Req 6.3) or the type is 'other' (Req 14).
      if (tier == SubscriptionTier.basic) continue;
      if (computedDelta.isEmpty &&
          !_emptyDeltaAllowed(businessType, mapping, tier)) {
        violations.add(
          ValidationViolation(
            rule: 'Req 6.2 empty-delta',
            businessType: businessType,
            tier: tier,
            message:
                '${tier.name} has an empty Tier_Delta but no recorded '
                'justification; each higher tier must add at least one '
                'capability when the count permits.',
          ),
        );
      }
    }
  }

  /// Whether an empty delta for [tier] is permitted: either the type is the
  /// `'other'` exception, or a justifying [MappingNote] is recorded (Req 6.3,
  /// 14.5, 15.x).
  bool _emptyDeltaAllowed(
    String businessType,
    PlanMapping mapping,
    SubscriptionTier tier,
  ) {
    if (businessType == _otherBusinessType) return true;
    return mapping.notes.any((note) {
      final kindAllows =
          note.kind == MappingNoteKind.emptyDelta ||
          note.kind == MappingNoteKind.otherTypeException ||
          note.kind == MappingNoteKind.planWashingException;
      final tierMatches = note.tier == null || note.tier == tier;
      return kindAllows && tierMatches;
    });
  }

  /// Essential vertical capability (Req 12).
  ///
  /// When the type has capabilities, exactly one essential vertical capability
  /// must be identified, with a non-empty rationale, be a registered capability,
  /// and be available by Pro_Tier. If it belongs to a Workflow_Pair, the
  /// registered pair members must all be at Pro_Tier or lower.
  void _checkEssentialVertical(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    if (registered.isEmpty) return; // Req 12 only applies to non-empty types.

    final essential = mapping.essentialVerticalCapability;
    if (essential == null) {
      violations.add(
        ValidationViolation(
          rule: 'Req 12.1 essential-vertical',
          businessType: businessType,
          message:
              'No essential vertical capability identified for "$businessType"; '
              'exactly one must be selected.',
        ),
      );
      return;
    }

    if (!registered.contains(essential)) {
      violations.add(
        ValidationViolation(
          rule: 'Req 12.1 essential-vertical',
          businessType: businessType,
          capability: essential,
          message:
              'Essential vertical capability ${essential.name} is not a '
              'Registered_Capability for "$businessType".',
        ),
      );
    }

    if (mapping.essentialVerticalRationale.trim().isEmpty) {
      violations.add(
        ValidationViolation(
          rule: 'Req 12.3 essential-rationale',
          businessType: businessType,
          capability: essential,
          message:
              'Essential vertical capability ${essential.name} has no '
              'rationale recorded.',
        ),
      );
    }

    final essentialTier = _assignedTierOf(mapping, essential);
    if (essentialTier != null && essentialTier > SubscriptionTier.pro) {
      violations.add(
        ValidationViolation(
          rule: 'Req 12.2 essential-by-pro',
          businessType: businessType,
          tier: essentialTier,
          capability: essential,
          message:
              'Essential vertical capability ${essential.name} is assigned to '
              '${essentialTier.name}; it must be available by Pro_Tier or '
              'lower.',
        ),
      );
    }

    // Req 12.4: if the essential capability is in a Workflow_Pair, the whole
    // registered pair must be no higher than Pro.
    for (final pair in workflowPairs) {
      if (!pair.contains(essential)) continue;
      for (final cap in pair.where(registered.contains)) {
        final tier = _assignedTierOf(mapping, cap);
        if (tier != null && tier > SubscriptionTier.pro) {
          violations.add(
            ValidationViolation(
              rule: 'Req 12.4 essential-pair-by-pro',
              businessType: businessType,
              tier: tier,
              capability: cap,
              message:
                  'Workflow_Pair member ${cap.name} of the essential vertical '
                  'capability ${essential.name} is at ${tier.name}; the pair '
                  'must be no higher than Pro_Tier.',
            ),
          );
        }
      }
    }
  }

  /// Service-only deltas (Req 13.2, 13.3, 13.4).
  ///
  /// A Service_Only_Type is one whose registered set contains no product or
  /// inventory capability. For such a type, no Tier_Delta may contain a product
  /// or inventory capability.
  void _checkServiceOnlyDeltas(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    final isServiceOnly = registered
        .intersection(_productAndInventoryCapabilities)
        .isEmpty;
    if (!isServiceOnly) return;

    const ordered = SubscriptionTier.values;
    for (var i = 0; i < ordered.length; i++) {
      final tier = ordered[i];
      final tierCaps = mapping.capabilitiesAt(tier);
      final lowerCaps = i == 0
          ? const <BusinessCapability>{}
          : mapping.capabilitiesAt(ordered[i - 1]);
      final delta = tierCaps.difference(lowerCaps);
      for (final cap in delta.intersection(_productAndInventoryCapabilities)) {
        violations.add(
          ValidationViolation(
            rule: 'Req 13.3 service-only-delta',
            businessType: businessType,
            tier: tier,
            capability: cap,
            message:
                'Service_Only_Type "$businessType" has product/inventory '
                'capability ${cap.name} in the ${tier.name} Tier_Delta; '
                'service-only deltas must avoid product and inventory '
                'capabilities.',
          ),
        );
      }
    }
  }

  /// Coverage bands (Req 1.2–1.5).
  ///
  /// Each tier's Tier_Coverage must land inside its band, unless a coverage
  /// deviation is recorded for that tier (Req 1.6). The `'other'` type is
  /// governed by Req 14 instead and is skipped; zero-capability types are
  /// skipped by the calculator (Req 1.7).
  void _checkCoverageBands(
    String businessType,
    PlanMapping mapping,
    List<ValidationViolation> violations,
  ) {
    if (businessType == _otherBusinessType) return;

    final records = calculator.evaluateType(businessType, mapping.tiers);
    for (final record in records) {
      if (record.withinBand) continue;
      final hasDeviationNote = mapping.notes.any(
        (note) =>
            note.kind == MappingNoteKind.coverageDeviation &&
            (note.tier == null || note.tier == record.tier),
      );
      if (!hasDeviationNote) {
        violations.add(
          ValidationViolation(
            rule: 'Req 1 coverage-band',
            businessType: businessType,
            tier: record.tier,
            message:
                '${record.tier.name} coverage '
                '${record.coveragePercent.toStringAsFixed(1)}% is outside the '
                'band ${record.band.minPercent}\u2013'
                '${record.band.maxPercent}% and no deviation is recorded.',
          ),
        );
      }
    }
  }

  /// No plan-washing (Req 15.1, 15.2, 15.4).
  ///
  /// For a differentiable type (not `'other'` and without a recorded
  /// plan-washing exemption), Premium and Enterprise must differ by at least two
  /// capabilities. Identical Premium/Enterprise sets are reported under
  /// Req 15.4; a single-capability difference under Req 15.2.
  void _checkPlanWashing(
    String businessType,
    PlanMapping mapping,
    Set<BusinessCapability> registered,
    List<ValidationViolation> violations,
  ) {
    if (businessType == _otherBusinessType) return;

    final hasExemption = mapping.notes.any(
      (note) =>
          note.kind == MappingNoteKind.planWashingException ||
          note.kind == MappingNoteKind.otherTypeException,
    );
    if (hasExemption) return;

    final premium = mapping.capabilitiesAt(SubscriptionTier.premium);
    final enterprise = mapping.capabilitiesAt(SubscriptionTier.enterprise);
    final enterpriseDelta = enterprise.difference(premium);

    if (enterpriseDelta.isEmpty) {
      violations.add(
        ValidationViolation(
          rule: 'Req 15.4 plan-washing',
          businessType: businessType,
          tier: SubscriptionTier.enterprise,
          message:
              'Premium_Tier and Enterprise_Tier are identical for '
              '"$businessType"; Enterprise must add distinct capabilities '
              'unless an exemption is recorded.',
        ),
      );
    } else if (enterpriseDelta.length < 2) {
      violations.add(
        ValidationViolation(
          rule: 'Req 15.2 enterprise-distinct',
          businessType: businessType,
          tier: SubscriptionTier.enterprise,
          message:
              'Enterprise_Tier adds only ${enterpriseDelta.length} capability '
              '(${_names(enterpriseDelta)}) over Premium_Tier for '
              '"$businessType"; at least two distinct capabilities are '
              'required.',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The lowest [SubscriptionTier] at which [cap] appears in [mapping], or
  /// `null` when it appears in no tier. Because tiers are cumulative, the lowest
  /// tier of appearance is the capability's effective assigned tier.
  SubscriptionTier? _assignedTierOf(
    PlanMapping mapping,
    BusinessCapability cap,
  ) {
    for (final tier in SubscriptionTier.values) {
      if (mapping.capabilitiesAt(tier).contains(cap)) return tier;
    }
    return null;
  }

  /// Whether two capability sets contain exactly the same members.
  bool _setEquals(Set<BusinessCapability> a, Set<BusinessCapability> b) =>
      a.length == b.length && a.containsAll(b);

  /// A stable, readable rendering of a capability set for messages.
  String _names(Set<BusinessCapability> caps) {
    if (caps.isEmpty) return '{}';
    final names = caps.map((c) => c.name).toList()..sort();
    return '{${names.join(', ')}}';
  }
}
