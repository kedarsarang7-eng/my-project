/// Deterministic plan-mapping builder for the Tiering_System.
///
/// [PlanMappingBuilder] turns a business type's Registered_Capability set (read
/// from the `Capability_Registry`, the single source of truth) into a
/// cumulative four-tier [PlanMapping] (Basic → Pro → Premium → Enterprise).
///
/// The build is **deterministic**: the same registry always yields the same
/// mapping, so the human-facing artifacts and the machine-consumable
/// Gating_Config never drift apart. The builder honors every hard constraint of
/// the specification:
///
/// * Billing_Core members live at Basic and never higher (Req 5).
/// * Gating floors/ceilings from the [CapabilityClassifier] bound where each
///   capability may sit — analytics/export and compliance/seasonal at Premium+
///   (Req 9, 11) and bulk/B2B/financial-risk capabilities at Enterprise only
///   (Req 10).
/// * Workflow_Pairs share a tier (Req 7, 8) and `useStockEntry` never unlocks
///   after `usePurchaseOrder` (Req 7.2).
/// * The single most essential vertical capability (and its pair) is available
///   no later than Pro (Req 12).
/// * Tiers are cumulative, so monotonicity is structural (Req 2); Enterprise is
///   always 100% of the registered capabilities (Req 3.4) and adds at least two
///   capabilities over Premium for types large enough to differentiate (Req 15).
/// * Service_Only_Type deltas draw only on workflow/reporting/staff/customer
///   capabilities, never product or inventory capabilities (Req 13).
/// * The generic `'other'` type follows the explicit counts of Req 14.
///
/// Coverage bands (Req 1) are treated as soft targets: the builder lands each
/// tier as close to its band as the hard constraints allow and records a
/// [MappingNoteKind.coverageDeviation] when an exact fit is impossible (Req 1.6).
/// A type with no registered capabilities skips band evaluation entirely
/// (Req 1.7).
///
/// The module is pure Dart on top of the existing enum, tier model, classifier,
/// and coverage calculator; it adds no new runtime dependencies.
library;

import '../isolation/business_capability.dart';
import 'capability_classifier.dart';
import 'coverage_calculator.dart';
import 'plan_mapping.dart';
import 'subscription_tier.dart';

/// Thrown when a type's hard constraints cannot be satisfied simultaneously
/// (for example, a workflow pair whose members have non-overlapping gating
/// ranges). The error carries the business type, an explanation, and the tier
/// involved where relevant.
class BuildInfeasibleError implements Exception {
  /// The business type whose mapping could not be built.
  final String businessType;

  /// A human-readable description of the conflicting constraints.
  final String message;

  /// The tier involved in the conflict, when applicable.
  final SubscriptionTier? tier;

  const BuildInfeasibleError(this.businessType, this.message, {this.tier});

  @override
  String toString() =>
      'BuildInfeasibleError($businessType'
      '${tier == null ? '' : ', ${tier!.name}'}): $message';
}

/// An internal assignment unit: one capability, or a Workflow_Pair's two
/// registered members that must share a tier.
///
/// [lo] and [hi] are the lowest and highest tier the unit may occupy, derived
/// from the gating floor/ceiling of its members (and further constrained for
/// the essential-vertical unit).
class _Unit {
  /// The capabilities in this unit (one, or a pair's two members).
  final List<BusinessCapability> caps;

  /// Lowest legal tier for the unit (max of member floors).
  SubscriptionTier lo;

  /// Highest legal tier for the unit (min of member ceilings).
  SubscriptionTier hi;

  _Unit(this.caps, this.lo, this.hi);

  /// Number of capabilities in the unit (1 or 2).
  int get size => caps.length;

  /// Deterministic ordering key: the lowest enum index among the members.
  int get priority => caps.map((c) => c.index).reduce((a, b) => a < b ? a : b);
}

/// Builds deterministic, cumulative four-tier [PlanMapping]s from the
/// `Capability_Registry`.
class PlanMappingBuilder {
  /// Classifies capabilities into gating categories and floor/ceiling tiers.
  final CapabilityClassifier classifier;

  /// The capability registry treated as the source of truth.
  final Map<String, Set<BusinessCapability>> registry;

  /// Computes Available_Capability_Count and target tier sizes.
  final CoverageCalculator calculator;

  /// Creates a builder.
  ///
  /// Defaults to the global `businessCapabilityRegistry`, a stateless
  /// [CapabilityClassifier], and a [CoverageCalculator] bound to the same
  /// registry. An explicit [registry] (e.g. a synthesized entry from a property
  /// test) can be injected without mutating global state.
  factory PlanMappingBuilder({
    CapabilityClassifier classifier = const CapabilityClassifier(),
    Map<String, Set<BusinessCapability>>? registry,
    CoverageCalculator? calculator,
  }) {
    final reg = registry ?? businessCapabilityRegistry;
    return PlanMappingBuilder._(
      classifier,
      reg,
      calculator ?? CoverageCalculator(registry: reg),
    );
  }

  PlanMappingBuilder._(this.classifier, this.registry, this.calculator);

  /// The generic business type governed by the explicit counts of Req 14.
  static const String otherType = 'other';

  /// Product capabilities (registry section 1). Used for the Service_Only_Type
  /// delta rule (Req 13.2): service-only deltas must avoid these.
  static const Set<BusinessCapability> productCapabilities = {
    BusinessCapability.useProductAdd,
    BusinessCapability.useProductName,
    BusinessCapability.useProductSalePrice,
    BusinessCapability.useProductStockQty,
    BusinessCapability.useProductUnit,
    BusinessCapability.useProductTax,
    BusinessCapability.useProductCategory,
  };

  /// Inventory capabilities (registry section 2). Used for the
  /// Service_Only_Type delta rule (Req 13.2).
  static const Set<BusinessCapability> inventoryCapabilities = {
    BusinessCapability.useInventoryList,
    BusinessCapability.useVisibleStock,
    BusinessCapability.useDeadStock,
    BusinessCapability.useInventorySearch,
    BusinessCapability.useInventoryExport,
  };

  /// Priority order for selecting the single most essential vertical capability
  /// (Req 12.1). The first entry that is a Registered_Capability whose gating
  /// floor is no higher than Pro (and is not Billing_Core) is chosen.
  ///
  /// Entries are ordered from the most vertical-defining capabilities to more
  /// generic ones. Gated capabilities (e.g. `useFuelManagement`) may appear in
  /// spirit but are filtered out by the floor check, so the essential capability
  /// can always be placed at Pro or below.
  static const List<BusinessCapability> _essentialPriority = [
    // Restaurant
    BusinessCapability.useKOT,
    BusinessCapability.useTableManagement,
    BusinessCapability.useKitchenDisplay,
    BusinessCapability.useWaiterLinking,
    // Petrol pump (fuel/shift management are gated, so pump readings anchor it)
    BusinessCapability.usePumpReadings,
    BusinessCapability.useVehicleDetails,
    BusinessCapability.useTankerEntry,
    // Pharmacy
    BusinessCapability.usePrescription,
    BusinessCapability.useSaltSearch,
    // Clinic
    BusinessCapability.usePatientRegistry,
    BusinessCapability.useAppointments,
    BusinessCapability.useConsultationBilling,
    // School ERP
    BusinessCapability.useStudentRegistry,
    BusinessCapability.useFeeCollection,
    BusinessCapability.useAttendanceTracking,
    // Decoration & catering
    BusinessCapability.useEventBooking,
    BusinessCapability.useVenueManagement,
    BusinessCapability.useDecorationThemes,
    BusinessCapability.useCateringMenu,
    // Book store
    BusinessCapability.useISBN,
    BusinessCapability.usePublisherReturns,
    // Jewellery
    BusinessCapability.useLoyaltyPoints,
    // Service / auto parts / computer / mobile (repairs)
    BusinessCapability.useJobSheets,
    BusinessCapability.useRepairStatus,
    BusinessCapability.useServiceStatus,
    BusinessCapability.useLaborCharges,
    // Electronics / mobile
    BusinessCapability.useIMEI,
    BusinessCapability.useWarranty,
    BusinessCapability.useBuyback,
    BusinessCapability.useExchange,
    // Clothing
    BusinessCapability.useVariants,
    BusinessCapability.useTailoringNotes,
    // Hardware
    BusinessCapability.useDimensions,
    BusinessCapability.useLooseQuantities,
    // Broker / mandi
    BusinessCapability.useCommission,
    BusinessCapability.useCrateManagement,
    BusinessCapability.useFarmerLinking,
    BusinessCapability.useDailyRates,
    // Wholesale / B2B
    BusinessCapability.useMultiUnit,
    BusinessCapability.useTransportDetails,
    // Generic fallbacks
    BusinessCapability.useBarcodeScanner,
    BusinessCapability.useStockManagement,
    BusinessCapability.useScanOCR,
    BusinessCapability.useVoiceInput,
    BusinessCapability.useLowStockAlerts,
  ];

  /// Builds plan mappings for every registered business type.
  ///
  /// Runs [buildFor] across all `Capability_Registry` keys so any build-time
  /// infeasibility surfaces up front, before artifacts are generated.
  Map<String, PlanMapping> buildAll() {
    final result = <String, PlanMapping>{};
    for (final type in registry.keys) {
      result[type] = buildFor(type);
    }
    return result;
  }

  /// Builds the cumulative four-tier [PlanMapping] for a single [businessType].
  ///
  /// Dispatches to the `'other'` special case (Req 14), the empty-registry path
  /// (Req 1.7), or the standard tiering algorithm.
  PlanMapping buildFor(String businessType) {
    final registered = registry[businessType] ?? const <BusinessCapability>{};
    if (businessType == otherType) {
      return _buildOther(businessType, registered);
    }
    if (registered.isEmpty) {
      return _buildEmpty(businessType);
    }
    return _buildStandard(businessType, registered);
  }

  // ---------------------------------------------------------------------------
  // Standard tiering algorithm.
  // ---------------------------------------------------------------------------

  PlanMapping _buildStandard(String type, Set<BusinessCapability> registered) {
    final n = registered.length;

    // Target cumulative tier sizes from the coverage calculator. These are
    // non-decreasing and Enterprise is exactly the full count.
    final cumTarget = <SubscriptionTier, int>{
      for (final record in calculator.recommendedSizes(n))
        record.tier: record.chosenSize,
    };
    cumTarget[SubscriptionTier.enterprise] = n;

    // Build assignment units: Workflow_Pairs with both members registered form
    // one unit; every other registered capability is its own unit.
    final units = <_Unit>[];
    final grouped = <BusinessCapability>{};
    for (final pair in workflowPairs) {
      final members = pair.where(registered.contains).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      if (members.length == 2) {
        units.add(_makeUnit(type, members));
        grouped.addAll(members);
      }
    }
    final singletons = registered.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final cap in singletons) {
      if (grouped.contains(cap)) continue;
      units.add(_makeUnit(type, [cap]));
    }

    // Identify the essential vertical capability and constrain its unit to Pro
    // or below (Req 12.2, 12.4).
    final essential = _selectEssential(registered);
    if (essential == null) {
      // Every registered capability is gated above Pro, so Req 12.2 (the
      // essential vertical capability must be available no later than Pro)
      // cannot be satisfied and no Basic/Pro tier can be populated. This is a
      // genuine hard-constraint conflict, surfaced up front rather than emitting
      // a mapping the validator would reject.
      throw BuildInfeasibleError(
        type,
        'no registered capability can be placed at Pro_Tier or below, so an '
        'essential vertical capability cannot be selected (Req 12.2); every '
        'capability is gated above Pro.',
        tier: SubscriptionTier.pro,
      );
    }
    final essentialUnit = units.firstWhere((u) => u.caps.contains(essential));
    if (essentialUnit.lo.index <= SubscriptionTier.pro.index) {
      essentialUnit.hi = _minTier(essentialUnit.hi, SubscriptionTier.pro);
    }
    final level = <_Unit, SubscriptionTier>{};

    // Fill Basic, Pro, then Premium in order; leftovers fall to Enterprise.
    for (final tier in const [
      SubscriptionTier.basic,
      SubscriptionTier.pro,
      SubscriptionTier.premium,
    ]) {
      // Force units that cannot legally go any higher (hi == tier). This places
      // Billing_Core at Basic and the essential unit by Pro.
      for (final unit in units) {
        if (level.containsKey(unit)) continue;
        if (unit.hi == tier) {
          if (unit.lo.index > tier.index) {
            throw BuildInfeasibleError(
              type,
              'capabilities ${unit.caps.map((c) => c.name).toList()} have a '
              'gating floor above their ceiling',
              tier: tier,
            );
          }
          level[unit] = tier;
        }
      }

      // Fill remaining capacity toward the cumulative target.
      final target = cumTarget[tier] ?? _capCount(level, tier);
      final eligible = units
          .where(
            (u) =>
                !level.containsKey(u) &&
                u.lo.index <= tier.index &&
                tier.index <= u.hi.index &&
                // Reserve the essential unit for Pro so the Pro delta is
                // meaningful: never consume it during the Basic fill.
                !(tier == SubscriptionTier.basic &&
                    identical(u, essentialUnit)),
          )
          .toList();
      _placeToTarget(level, tier, eligible, target);
    }

    // Everything not yet placed unlocks at Enterprise (Req 3.4: union == R).
    for (final unit in units) {
      level.putIfAbsent(unit, () => SubscriptionTier.enterprise);
    }

    // Repairs that enforce remaining hard constraints. The Enterprise-distinct
    // repair is told which registered capabilities the stock-entry ordering
    // (Req 7.2) constrains, so it never promotes useStockEntry above
    // usePurchaseOrder while restoring the Enterprise delta.
    _repairStockEntryOrder(level, units, registered);
    _repairPremiumNonEmpty(level, units, essentialUnit, registered);
    _repairEnterpriseDistinct(level, units, essentialUnit, registered);

    return _assemble(type, registered, level, essential, n);
  }

  /// Greedily assigns units from [eligible] to [tier] until the cumulative
  /// capability count reaches [target].
  ///
  /// Prefers, in priority order, a unit that fits the remaining capacity
  /// exactly; when none fits it takes the smallest unit to minimise overshoot.
  /// Any resulting band miss is recorded later as a coverage deviation.
  void _placeToTarget(
    Map<_Unit, SubscriptionTier> level,
    SubscriptionTier tier,
    List<_Unit> eligible,
    int target,
  ) {
    eligible.sort((a, b) => a.priority.compareTo(b.priority));
    var cum = _capCount(level, tier);
    while (cum < target && eligible.isNotEmpty) {
      final remaining = target - cum;
      _Unit pick;
      final fitting = eligible.where((u) => u.size <= remaining).toList();
      if (fitting.isNotEmpty) {
        pick = fitting.first; // already priority-sorted
      } else {
        // No unit fits exactly; take the smallest (ties broken by priority).
        eligible.sort((a, b) {
          final bySize = a.size.compareTo(b.size);
          return bySize != 0 ? bySize : a.priority.compareTo(b.priority);
        });
        pick = eligible.first;
      }
      level[pick] = tier;
      eligible.remove(pick);
      cum += pick.size;
      eligible.sort((a, b) => a.priority.compareTo(b.priority));
    }
  }

  /// Builds a unit from [members], computing its legal `[lo, hi]` tier range.
  _Unit _makeUnit(String type, List<BusinessCapability> members) {
    var lo = SubscriptionTier.basic;
    var hi = SubscriptionTier.enterprise;
    for (final cap in members) {
      final floor = classifier.floorFor(cap);
      final ceiling = classifier.ceilingFor(cap);
      if (floor.index > lo.index) lo = floor;
      if (ceiling.index < hi.index) hi = ceiling;
    }
    if (lo.index > hi.index) {
      throw BuildInfeasibleError(
        type,
        'workflow pair ${members.map((c) => c.name).toList()} has '
        'non-overlapping gating ranges (floor ${lo.name} > ceiling ${hi.name})',
      );
    }
    return _Unit(members, lo, hi);
  }

  /// Total capabilities placed at a tier no higher than [upTo].
  int _capCount(Map<_Unit, SubscriptionTier> level, SubscriptionTier upTo) {
    var count = 0;
    level.forEach((unit, tier) {
      if (tier.index <= upTo.index) count += unit.size;
    });
    return count;
  }

  /// Ensures `useStockEntry` never unlocks at a higher tier than
  /// `usePurchaseOrder` (Req 7.2). If it does, lowers stock entry to the
  /// purchase-order tier (always legal: stock entry is a standard capability).
  void _repairStockEntryOrder(
    Map<_Unit, SubscriptionTier> level,
    List<_Unit> units,
    Set<BusinessCapability> registered,
  ) {
    if (!registered.contains(BusinessCapability.useStockEntry) ||
        !registered.contains(BusinessCapability.usePurchaseOrder)) {
      return;
    }
    final stockUnit = units.firstWhere(
      (u) => u.caps.contains(BusinessCapability.useStockEntry),
    );
    final purchaseUnit = units.firstWhere(
      (u) => u.caps.contains(BusinessCapability.usePurchaseOrder),
    );
    final stockTier = level[stockUnit]!;
    final purchaseTier = level[purchaseUnit]!;
    if (stockTier.index > purchaseTier.index) {
      level[stockUnit] = _clampTier(purchaseTier, stockUnit.lo, stockUnit.hi);
    }
  }

  /// The current tier of the unit that owns [cap], or `null` when [cap] is not
  /// registered for the type. Used by the repairs to honor the stock-entry
  /// ordering constraint (Req 7.2) while they move units between tiers.
  SubscriptionTier? _tierOfCapability(
    Map<_Unit, SubscriptionTier> level,
    List<_Unit> units,
    Set<BusinessCapability> registered,
    BusinessCapability cap,
  ) {
    if (!registered.contains(cap)) return null;
    for (final unit in units) {
      if (unit.caps.contains(cap)) return level[unit];
    }
    return null;
  }

  /// Ensures the Premium delta is non-empty when capabilities remain to fill it,
  /// by pulling one Enterprise-level unit down to Premium (Req 6.1).
  ///
  /// The pulled-down unit is never the `usePurchaseOrder` unit while
  /// `useStockEntry` sits above Premium, because lowering purchase order below
  /// stock entry would re-break the Req 7.2 ordering. Skipping it falls through
  /// to the next candidate (the stock-entry unit itself is always safe to pull
  /// down), so Premium is still filled.
  void _repairPremiumNonEmpty(
    Map<_Unit, SubscriptionTier> level,
    List<_Unit> units,
    _Unit? essentialUnit,
    Set<BusinessCapability> registered,
  ) {
    final premiumCount = units
        .where((u) => level[u] == SubscriptionTier.premium)
        .length;
    if (premiumCount > 0) return;
    final stockTier = _tierOfCapability(
      level,
      units,
      registered,
      BusinessCapability.useStockEntry,
    );
    final candidates =
        units
            .where(
              (u) =>
                  level[u] == SubscriptionTier.enterprise &&
                  u.lo.index <= SubscriptionTier.premium.index &&
                  !identical(u, essentialUnit) &&
                  // Req 7.2: don't drop purchase order below stock entry.
                  !(u.caps.contains(BusinessCapability.usePurchaseOrder) &&
                      stockTier != null &&
                      stockTier.index > SubscriptionTier.premium.index),
            )
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
    if (candidates.isNotEmpty) {
      level[candidates.first] = SubscriptionTier.premium;
    }
  }

  /// Ensures Enterprise adds at least two capabilities over Premium for types
  /// large enough to differentiate (Req 15.1, 15.2), by moving units up toward
  /// Enterprise while keeping the Premium delta non-empty and the stock-entry
  /// ordering intact (Req 7.2).
  ///
  /// Two moves are used, in order of preference:
  ///
  /// 1. **Promote** the highest-index movable Premium unit to Enterprise. This
  ///    is taken whenever Premium can spare a unit (it has at least two), so its
  ///    delta stays non-empty.
  /// 2. **Refill** Premium by raising a movable Pro unit when Premium has only
  ///    one unit (promoting it directly would empty the Premium delta). The
  ///    raise gives Premium a second unit so a promotion can follow on the next
  ///    iteration. It is only taken when Pro keeps at least one unit (so the Pro
  ///    delta stays non-empty).
  ///
  /// A move is never applied when it would lift `useStockEntry` above the tier
  /// of `usePurchaseOrder`; raising the purchase-order unit higher is always
  /// safe because it only relaxes the ordering. When neither move can run the
  /// registry is too small to differentiate, and [_assemble] records a
  /// plan-washing exemption (Req 15.5-style), so the builder never emits a
  /// mapping its own validator would reject.
  void _repairEnterpriseDistinct(
    Map<_Unit, SubscriptionTier> level,
    List<_Unit> units,
    _Unit? essentialUnit,
    Set<BusinessCapability> registered,
  ) {
    const ent = SubscriptionTier.enterprise;
    const prem = SubscriptionTier.premium;
    const pro = SubscriptionTier.pro;

    int enterpriseCaps() =>
        units.where((u) => level[u] == ent).fold(0, (sum, u) => sum + u.size);

    final hasOrdering =
        registered.contains(BusinessCapability.useStockEntry) &&
        registered.contains(BusinessCapability.usePurchaseOrder);

    // Raising [unit] to [target] is unsafe only when it lifts the stock-entry
    // unit above the current tier of the purchase-order unit (Req 7.2). Raising
    // the purchase-order unit itself never breaks the ordering.
    bool raiseBreaksOrdering(_Unit unit, SubscriptionTier target) {
      if (!hasOrdering) return false;
      if (!unit.caps.contains(BusinessCapability.useStockEntry)) return false;
      final purchaseTier = _tierOfCapability(
        level,
        units,
        registered,
        BusinessCapability.usePurchaseOrder,
      );
      return purchaseTier == null || target.index > purchaseTier.index;
    }

    // Bound the loop defensively: every successful move strictly raises a unit,
    // so it always terminates well within this many iterations.
    var guard = 0;
    while (enterpriseCaps() < 2 && guard++ < units.length * 2 + 4) {
      final premiumUnits = units.where((u) => level[u] == prem).toList();
      final promotable =
          premiumUnits
              .where(
                (u) =>
                    u.hi == ent &&
                    !identical(u, essentialUnit) &&
                    !raiseBreaksOrdering(u, ent),
              )
              .toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));

      // Preferred move: promote a Premium unit while Premium keeps a unit.
      if (premiumUnits.length >= 2 && promotable.isNotEmpty) {
        level[promotable.first] = ent;
        continue;
      }

      // Fallback move: raise a Pro unit to Premium so the next iteration can
      // promote without emptying the Premium delta. (Every non-billing,
      // non-essential unit has an Enterprise ceiling, so a unit raised here is
      // promotable on the following pass.)
      final proUnits = units.where((u) => level[u] == pro).toList();
      final raisable =
          proUnits
              .where(
                (u) =>
                    u.hi.index >= prem.index &&
                    !identical(u, essentialUnit) &&
                    !raiseBreaksOrdering(u, prem),
              )
              .toList()
            ..sort((a, b) => b.priority.compareTo(a.priority));
      if (proUnits.length >= 2 && raisable.isNotEmpty) {
        level[raisable.first] = prem;
        continue;
      }

      // Neither move is possible: the count is too small to differentiate.
      break;
    }
  }

  /// Assembles the final [PlanMapping] from a unit→tier assignment: cumulative
  /// tier sets, per-tier deltas, workflow-pair tiers, and recorded notes.
  PlanMapping _assemble(
    String type,
    Set<BusinessCapability> registered,
    Map<_Unit, SubscriptionTier> level,
    BusinessCapability? essential,
    int n,
  ) {
    // Cumulative tier sets: a unit at tier T contributes to T and every higher
    // tier, so basic ⊆ pro ⊆ premium ⊆ enterprise structurally (Req 2).
    final tiers = <SubscriptionTier, Set<BusinessCapability>>{
      for (final tier in SubscriptionTier.values) tier: <BusinessCapability>{},
    };
    level.forEach((unit, unitTier) {
      for (final tier in SubscriptionTier.values) {
        if (tier.index >= unitTier.index) {
          tiers[tier]!.addAll(unit.caps);
        }
      }
    });

    final deltas = _deltasOf(tiers);
    final workflowPairTiers = _workflowPairTiers(registered, level);
    final notes = <MappingNote>[];

    // Coverage deviations (Req 1.6).
    for (final record in calculator.evaluate(tiers, n)) {
      if (!record.withinBand) {
        notes.add(
          MappingNote(
            kind: MappingNoteKind.coverageDeviation,
            tier: record.tier,
            message:
                record.deviationReason ??
                '${record.tier.name} coverage '
                    '${record.coveragePercent.toStringAsFixed(1)}% is outside '
                    'its target band ${record.band}.',
          ),
        );
      }
    }

    // Partial Billing_Core: registered subset placed at Basic, absent members
    // recorded as a hard-isolation exception (Req 5.3).
    final billingPresent = CapabilityClassifier.billingCoreCapabilities
        .where(registered.contains)
        .toList();
    if (billingPresent.isNotEmpty &&
        billingPresent.length <
            CapabilityClassifier.billingCoreCapabilities.length) {
      final absent = CapabilityClassifier.billingCoreCapabilities
          .where((c) => !registered.contains(c))
          .map((c) => c.name)
          .toList();
      notes.add(
        MappingNote(
          kind: MappingNoteKind.billingCoreException,
          tier: SubscriptionTier.basic,
          message:
              'Billing_Core members ${absent.join(', ')} are hard-isolated for '
              '"$type"; only the registered members were placed at Basic_Tier.',
        ),
      );
    }

    // Empty deltas where the count could not produce one (Req 6.3).
    for (final tier in const [
      SubscriptionTier.pro,
      SubscriptionTier.premium,
      SubscriptionTier.enterprise,
    ]) {
      if (deltas[tier]!.isEmpty) {
        notes.add(
          MappingNote(
            kind: MappingNoteKind.emptyDelta,
            tier: tier,
            message:
                'Available_Capability_Count ($n) is too small to give '
                '${tier.name}_Tier a non-empty delta.',
          ),
        );
      }
    }

    // Plan-washing exemption when Premium and Enterprise could not be given a
    // two-capability distinction. The Enterprise-distinct repair already moves
    // every unit it legally can toward Enterprise, so a delta still short of
    // two here means the Available_Capability_Count is genuinely too small to
    // differentiate (Req 15.5-style exemption). Recording it keeps the builder
    // self-consistent without weakening the rule for differentiable types,
    // which always reach a two-capability Enterprise delta.
    if (deltas[SubscriptionTier.enterprise]!.length < 2) {
      notes.add(
        MappingNote(
          kind: MappingNoteKind.planWashingException,
          message:
              'Available_Capability_Count ($n) is too small to give '
              'Enterprise_Tier two distinct capabilities over Premium_Tier for '
              '"$type".',
        ),
      );
    }

    final rationale = essential == null
        ? 'No registered capabilities; no essential vertical capability.'
        : '${essential.name} is the defining vertical capability for "$type" '
              'and is guaranteed available no later than Pro_Tier.';

    return PlanMapping(
      businessType: type,
      tiers: tiers,
      registeredCapabilities: registered,
      deltas: deltas,
      essentialVerticalCapability: essential,
      essentialVerticalRationale: rationale,
      workflowPairTiers: workflowPairTiers,
      notes: notes,
    );
  }

  // ---------------------------------------------------------------------------
  // 'other' special case (Req 14).
  // ---------------------------------------------------------------------------

  PlanMapping _buildOther(String type, Set<BusinessCapability> registered) {
    final all = registered.toList()..sort((a, b) => a.index.compareTo(b.index));

    // Basic = exactly three: the registered Billing_Core members first, then
    // the lowest-index remaining capabilities (Req 14.2, plus Req 5).
    final billingPresent =
        CapabilityClassifier.billingCoreCapabilities
            .where(registered.contains)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final basic = <BusinessCapability>{...billingPresent};
    for (final cap in all) {
      if (basic.length >= 3) break;
      basic.add(cap);
    }

    final full = {...registered};
    final tiers = <SubscriptionTier, Set<BusinessCapability>>{
      SubscriptionTier.basic: basic,
      SubscriptionTier.pro: {...full},
      SubscriptionTier.premium: {...full},
      SubscriptionTier.enterprise: {...full},
    };
    final deltas = _deltasOf(tiers);

    final essential = _selectEssential(registered);
    final rationale = essential == null
        ? 'No essential vertical capability for the generic "other" type.'
        : '${essential.name} anchors the generic "other" type at Basic_Tier.';

    final notes = <MappingNote>[
      const MappingNote(
        kind: MappingNoteKind.otherTypeException,
        message:
            'The "other" type uses the fixed Req 14 mapping (Basic = 3, '
            'Pro = Premium = Enterprise = all 6) and is an explicit exception '
            'to the no-plan-washing and Enterprise distinct-addition rules.',
      ),
    ];
    // Partial Billing_Core: 'other' registers create+list but not search.
    final absent = CapabilityClassifier.billingCoreCapabilities
        .where((c) => !registered.contains(c))
        .map((c) => c.name)
        .toList();
    if (billingPresent.isNotEmpty && absent.isNotEmpty) {
      notes.add(
        MappingNote(
          kind: MappingNoteKind.billingCoreException,
          tier: SubscriptionTier.basic,
          message:
              'Billing_Core members ${absent.join(', ')} are hard-isolated for '
              '"other"; only the registered members were placed at Basic_Tier.',
        ),
      );
    }

    return PlanMapping(
      businessType: type,
      tiers: tiers,
      registeredCapabilities: registered,
      deltas: deltas,
      essentialVerticalCapability: essential,
      essentialVerticalRationale: rationale,
      workflowPairTiers: _workflowPairTiers(registered, const {}),
      notes: notes,
    );
  }

  // ---------------------------------------------------------------------------
  // Empty-registry case (Req 1.7).
  // ---------------------------------------------------------------------------

  PlanMapping _buildEmpty(String type) {
    final tiers = <SubscriptionTier, Set<BusinessCapability>>{
      for (final tier in SubscriptionTier.values) tier: <BusinessCapability>{},
    };
    // A zero-capability type cannot produce any Tier_Delta, so the higher tiers
    // are unavoidably empty and Premium/Enterprise cannot differ. Record the
    // same small-count exemptions the standard path uses (Req 6.3, 15.x) so the
    // builder never emits a mapping its own validator would reject.
    final notes = <MappingNote>[
      for (final tier in const [
        SubscriptionTier.pro,
        SubscriptionTier.premium,
        SubscriptionTier.enterprise,
      ])
        MappingNote(
          kind: MappingNoteKind.emptyDelta,
          tier: tier,
          message:
              'No registered capabilities for "$type"; ${tier.name}_Tier has '
              'an empty Tier_Delta (Req 6.3).',
        ),
      MappingNote(
        kind: MappingNoteKind.planWashingException,
        message:
            'No registered capabilities for "$type"; Premium_Tier and '
            'Enterprise_Tier cannot be differentiated (Req 15.x).',
      ),
    ];
    return PlanMapping(
      businessType: type,
      tiers: tiers,
      registeredCapabilities: const <BusinessCapability>{},
      deltas: _deltasOf(tiers),
      essentialVerticalCapability: null,
      essentialVerticalRationale:
          'No registered capabilities for "$type"; coverage-band evaluation '
          'is skipped (Req 1.7).',
      workflowPairTiers: const {},
      notes: notes,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers.
  // ---------------------------------------------------------------------------

  /// Per-tier deltas from cumulative tier sets. Basic's delta is its own set.
  Map<SubscriptionTier, Set<BusinessCapability>> _deltasOf(
    Map<SubscriptionTier, Set<BusinessCapability>> tiers,
  ) {
    final basic = tiers[SubscriptionTier.basic] ?? const {};
    final pro = tiers[SubscriptionTier.pro] ?? const {};
    final premium = tiers[SubscriptionTier.premium] ?? const {};
    final enterprise = tiers[SubscriptionTier.enterprise] ?? const {};
    return {
      SubscriptionTier.basic: {...basic},
      SubscriptionTier.pro: pro.difference(basic),
      SubscriptionTier.premium: premium.difference(pro),
      SubscriptionTier.enterprise: enterprise.difference(premium),
    };
  }

  /// The tier shared by each fully-registered Workflow_Pair (Req 7.4, 8).
  ///
  /// Keyed by a stable `'memberA+memberB'` label. When [level] is empty (the
  /// `'other'` path) the pair tier is read from the cumulative assignment by
  /// scanning, which is unnecessary there since `'other'` registers no pairs.
  Map<String, SubscriptionTier> _workflowPairTiers(
    Set<BusinessCapability> registered,
    Map<_Unit, SubscriptionTier> level,
  ) {
    final result = <String, SubscriptionTier>{};
    for (final pair in workflowPairs) {
      final members = pair.where(registered.contains).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (members.length != 2) continue;
      final unitEntry = level.entries.firstWhere(
        (e) => e.key.caps.toSet().containsAll(members),
        orElse: () => MapEntry(
          _Unit(members, SubscriptionTier.basic, SubscriptionTier.enterprise),
          SubscriptionTier.basic,
        ),
      );
      result[members.map((c) => c.name).join('+')] = unitEntry.value;
    }
    return result;
  }

  /// Selects the single most essential vertical capability for a type: the
  /// highest-priority Registered_Capability whose gating floor is no higher than
  /// Pro and that is not Billing_Core (Req 12.1). Falls back to the
  /// lowest-index eligible capability, then to any capability placeable at Pro.
  BusinessCapability? _selectEssential(Set<BusinessCapability> registered) {
    bool eligible(BusinessCapability cap) =>
        classifier.floorFor(cap).index <= SubscriptionTier.pro.index &&
        !CapabilityClassifier.billingCoreCapabilities.contains(cap);

    for (final cap in _essentialPriority) {
      if (registered.contains(cap) && eligible(cap)) return cap;
    }
    final fallback = registered.where(eligible).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (fallback.isNotEmpty) return fallback.first;

    // Last resort: any capability that can sit at Pro or below (e.g. a type of
    // only Billing_Core members).
    final placeable =
        registered
            .where(
              (c) => classifier.floorFor(c).index <= SubscriptionTier.pro.index,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return placeable.isEmpty ? null : placeable.first;
  }

  /// The lower of two tiers by order.
  SubscriptionTier _minTier(SubscriptionTier a, SubscriptionTier b) =>
      a.index <= b.index ? a : b;

  /// [tier] clamped into the inclusive range `[lo, hi]`.
  SubscriptionTier _clampTier(
    SubscriptionTier tier,
    SubscriptionTier lo,
    SubscriptionTier hi,
  ) {
    if (tier.index < lo.index) return lo;
    if (tier.index > hi.index) return hi;
    return tier;
  }
}
