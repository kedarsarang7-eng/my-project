/// Plan mapping data models for the Tiering_System.
///
/// This file defines the pure-Dart value types that describe how a single
/// business type's registered capabilities are partitioned into the four
/// ordered subscription tiers (Basic → Pro → Premium → Enterprise):
///
/// * [PlanMapping]  — the central per-type artifact: cumulative capability sets
///   per tier, per-tier deltas, the essential vertical capability, workflow-pair
///   tiers, and recorded deviations/exceptions.
/// * [MappingNote]  — a small value type recording a single deviation or
///   exception encountered while building a mapping (Req 1.6, 5.3, 6.3, 14.5,
///   15.x).
/// * [UpgradeStory] — the narrative for one tier transition, whose added
///   capabilities equal the higher tier's Tier_Delta (Req 16).
///
/// These are data models only. The builder, validator, coverage calculator, and
/// artifact generators live in their own files and consume these types. The
/// models stay immutable: collections passed in are wrapped as unmodifiable
/// views so a constructed value cannot be mutated after the fact.
library;

import '../isolation/business_capability.dart';
import 'subscription_tier.dart';

/// The category of a [MappingNote].
///
/// Each value identifies a kind of recorded deviation or documented exception
/// that the Tiering_System is allowed to make, with traceability back to the
/// requirement that permits it.
enum MappingNoteKind {
  /// A tier's coverage could not land inside its band exactly, so the closest
  /// ordering-preserving size was chosen (Req 1.6).
  coverageDeviation,

  /// A registered subset of Billing_Core was placed at Basic while one or more
  /// Billing_Core members are absent from the registry (Req 5.3).
  billingCoreException,

  /// A tier's Tier_Delta is empty because the Available_Capability_Count is too
  /// small to create a non-empty delta (Req 6.3).
  emptyDelta,

  /// The `'other'` type's documented exception to the no-plan-washing and
  /// Enterprise-distinct-addition rules (Req 14.5).
  otherTypeException,

  /// A documented exemption from the no-plan-washing rule for a type that
  /// cannot differentiate Premium from Enterprise (Req 15.x).
  planWashingException,
}

/// A single recorded deviation or exception captured while building a
/// [PlanMapping].
///
/// Notes make the mapping self-describing: every place where the Tiering_System
/// departs from the ideal coverage band, or invokes a documented exception, is
/// recorded here with enough context (the [kind], and optionally the affected
/// [tier] and [capability]) plus a human-readable [message] explaining why.
///
/// The type is immutable and serialization-friendly: it carries only a small
/// enum, two optional enum-valued fields, and a string.
class MappingNote {
  /// The category of this note.
  final MappingNoteKind kind;

  /// The tier this note refers to, when applicable.
  final SubscriptionTier? tier;

  /// The capability this note refers to, when applicable.
  final BusinessCapability? capability;

  /// A human-readable explanation of the deviation or exception.
  final String message;

  const MappingNote({
    required this.kind,
    required this.message,
    this.tier,
    this.capability,
  });

  @override
  bool operator ==(Object other) =>
      other is MappingNote &&
      other.kind == kind &&
      other.tier == tier &&
      other.capability == capability &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, tier, capability, message);

  @override
  String toString() =>
      'MappingNote(${kind.name}, tier: ${tier?.name}, '
      'capability: ${capability?.name}, message: $message)';
}

/// The per-type plan mapping: how one business type's registered capabilities
/// are assigned across the four ordered subscription tiers.
///
/// Tiers are stored as **cumulative** capability sets, so monotonicity is
/// structural rather than merely asserted. The intended invariant is:
///
/// ```
/// basic ⊆ pro ⊆ premium ⊆ enterprise == registeredCapabilities
/// ```
///
/// This class is a pure data model; it does not enforce the invariant itself
/// (the validator does). It stores the assignment plus the supporting facts the
/// downstream artifact generators and the Gating_Config need.
class PlanMapping {
  /// The business-type key from `Capability_Registry` (e.g. `'grocery'`).
  final String businessType;

  /// Cumulative capability set per tier.
  ///
  /// Each tier's set includes every capability of every lower tier. Intended
  /// invariant: `basic ⊆ pro ⊆ premium ⊆ enterprise == registeredCapabilities`.
  final Map<SubscriptionTier, Set<BusinessCapability>> tiers;

  /// The distinct registered capabilities for this type (the source of truth).
  ///
  /// Equals the Enterprise tier's capability set.
  final Set<BusinessCapability> registeredCapabilities;

  /// The Tier_Delta per tier: the capabilities a tier adds relative to the
  /// next-lower tier.
  ///
  /// For Basic the delta is the Basic set itself (nothing lower exists).
  final Map<SubscriptionTier, Set<BusinessCapability>> deltas;

  /// The single most essential vertical capability for this type, or `null`
  /// when the type has no registered capabilities (Req 12).
  final BusinessCapability? essentialVerticalCapability;

  /// The rationale for selecting [essentialVerticalCapability] (Req 12.3).
  final String essentialVerticalRationale;

  /// The Workflow_Pairs present for this type and the tier they share.
  ///
  /// Keyed by a stable pair label (e.g. `'usePurchaseOrder+useSupplierBill'`)
  /// mapped to the shared tier (Req 7.4, Req 8).
  final Map<String, SubscriptionTier> workflowPairTiers;

  /// Recorded deviations and documented exceptions for this mapping
  /// (Req 1.6, 5.3, 6.3, 14.5, 15.x).
  final List<MappingNote> notes;

  /// Creates an immutable plan mapping.
  ///
  /// All collection arguments are wrapped in unmodifiable views (including the
  /// inner capability sets of [tiers] and [deltas]) so the resulting value
  /// cannot be mutated through the references passed in.
  PlanMapping({
    required this.businessType,
    required Map<SubscriptionTier, Set<BusinessCapability>> tiers,
    required Set<BusinessCapability> registeredCapabilities,
    required Map<SubscriptionTier, Set<BusinessCapability>> deltas,
    required this.essentialVerticalCapability,
    required this.essentialVerticalRationale,
    required Map<String, SubscriptionTier> workflowPairTiers,
    required List<MappingNote> notes,
  }) : tiers = Map.unmodifiable({
         for (final entry in tiers.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       registeredCapabilities = Set.unmodifiable(registeredCapabilities),
       deltas = Map.unmodifiable({
         for (final entry in deltas.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       workflowPairTiers = Map.unmodifiable(workflowPairTiers),
       notes = List.unmodifiable(notes);

  /// The cumulative capability set granted at [tier].
  ///
  /// Returns an empty (unmodifiable) set when the tier was not recorded, which
  /// only happens for malformed mappings.
  Set<BusinessCapability> capabilitiesAt(SubscriptionTier tier) =>
      tiers[tier] ?? const <BusinessCapability>{};

  /// The Tier_Delta recorded for [tier] (capabilities added vs. the next-lower
  /// tier). Returns an empty set when no delta was recorded.
  Set<BusinessCapability> deltaAt(SubscriptionTier tier) =>
      deltas[tier] ?? const <BusinessCapability>{};

  /// The number of distinct registered capabilities (Available_Capability_Count).
  int get availableCount => registeredCapabilities.length;

  @override
  String toString() =>
      'PlanMapping($businessType, available: $availableCount, '
      'notes: ${notes.length})';
}

/// A narrative explaining why a business of a given type upgrades from one tier
/// to the next-higher tier.
///
/// The [addedCapabilities] are exactly the Tier_Delta of [to] — the capabilities
/// that become available on crossing from [from] to [to] (Req 16.4). The
/// [narrative] is a short human-facing explanation built from those additions.
class UpgradeStory {
  /// The lower tier the customer is upgrading from.
  final SubscriptionTier from;

  /// The higher tier the customer is upgrading to.
  final SubscriptionTier to;

  /// The capabilities unlocked by the upgrade — equal to the Tier_Delta of
  /// [to].
  final Set<BusinessCapability> addedCapabilities;

  /// A short, human-readable reason for the upgrade.
  final String narrative;

  /// Creates an immutable upgrade story. [addedCapabilities] is wrapped in an
  /// unmodifiable view.
  UpgradeStory({
    required this.from,
    required this.to,
    required Set<BusinessCapability> addedCapabilities,
    required this.narrative,
  }) : addedCapabilities = Set.unmodifiable(addedCapabilities);

  @override
  String toString() =>
      'UpgradeStory(${from.name} → ${to.name}, '
      'adds ${addedCapabilities.length})';
}
