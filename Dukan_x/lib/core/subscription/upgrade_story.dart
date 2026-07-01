/// Upgrade_Story generation and per-type Plan_Mapping assembly for the
/// Tiering_System (Req 16).
///
/// The plan-mapping builder produces the cumulative four-tier [PlanMapping] for
/// a business type. This file turns that mapping into the human-facing artifact
/// the product, sales, and pricing teams consume:
///
/// * [UpgradeStoryGenerator] — produces exactly three [UpgradeStory] values per
///   type (Basic→Pro, Pro→Premium, Premium→Enterprise) whose added capabilities
///   equal the higher tier's Tier_Delta (Req 16.2, 16.4).
/// * [PlanArtifact] — bundles a [PlanMapping] with its three Upgrade_Stories so
///   each of the 19 target types ships as one complete, non-pending artifact
///   (Req 16.1, 16.3).
///
/// The [UpgradeStory] model itself lives in `plan_mapping.dart` and is reused
/// here rather than redefined. This module is pure Dart over the existing tier
/// model and capability enum; it adds no runtime dependencies and never invents
/// capabilities — every added capability is read straight from the mapping's
/// recorded Tier_Delta, so the narratives can never drift from the gating data.
library;

import '../isolation/business_capability.dart';
import 'plan_mapping.dart';
import 'subscription_tier.dart';

/// A per-type artifact: one [PlanMapping] together with the three
/// Upgrade_Stories that describe its tier transitions (Req 16.1, 16.2).
///
/// The bundle is what downstream consumers (pricing pages, sales decks) read:
/// the four cumulative tier sets plus the reason a customer of this type moves
/// up each step. It is immutable — the story list is wrapped in an unmodifiable
/// view.
class PlanArtifact {
  /// The cumulative four-tier mapping for this business type.
  final PlanMapping mapping;

  /// The three Upgrade_Stories in ascending order:
  /// Basic→Pro, Pro→Premium, Premium→Enterprise.
  final List<UpgradeStory> upgradeStories;

  /// Creates an immutable artifact. [upgradeStories] is wrapped in an
  /// unmodifiable view.
  PlanArtifact({
    required this.mapping,
    required List<UpgradeStory> upgradeStories,
  }) : upgradeStories = List.unmodifiable(upgradeStories);

  /// The business-type key this artifact describes (e.g. `'grocery'`).
  String get businessType => mapping.businessType;

  @override
  String toString() =>
      'PlanArtifact($businessType, stories: ${upgradeStories.length})';
}

/// Generates Upgrade_Stories and assembles per-type [PlanArtifact]s from
/// validated [PlanMapping]s.
///
/// The generator is stateless and deterministic: given the same mapping it
/// always produces the same stories, so the artifact never drifts from the
/// Gating_Config built from the same mapping. Each story's
/// [UpgradeStory.addedCapabilities] is exactly the higher tier's Tier_Delta as
/// recorded on the mapping (Req 16.4), and every story carries a non-empty,
/// human-readable narrative.
class UpgradeStoryGenerator {
  /// Creates a stateless generator. Instances are interchangeable.
  const UpgradeStoryGenerator();

  /// The four tiers in ascending order; consecutive entries form the three
  /// tier transitions an Upgrade_Story describes.
  static const List<SubscriptionTier> _orderedTiers = [
    SubscriptionTier.basic,
    SubscriptionTier.pro,
    SubscriptionTier.premium,
    SubscriptionTier.enterprise,
  ];

  /// Produces exactly three Upgrade_Stories for [mapping] — one per tier
  /// transition (Basic→Pro, Pro→Premium, Premium→Enterprise) — in ascending
  /// order (Req 16.2).
  ///
  /// Each story's added capabilities equal the Tier_Delta recorded for the
  /// higher tier of the transition (Req 16.4). When a transition adds no
  /// capabilities (a registry too small to differentiate the tiers, e.g. the
  /// `'other'` type), the story still carries a non-empty narrative that says
  /// so.
  List<UpgradeStory> generate(PlanMapping mapping) {
    final stories = <UpgradeStory>[];
    for (var i = 0; i < _orderedTiers.length - 1; i++) {
      final from = _orderedTiers[i];
      final to = _orderedTiers[i + 1];
      final added = mapping.deltaAt(to);
      stories.add(
        UpgradeStory(
          from: from,
          to: to,
          addedCapabilities: added,
          narrative: _narrative(mapping.businessType, from, to, added),
        ),
      );
    }
    return stories;
  }

  /// Assembles the complete per-type artifact: the [mapping] plus its three
  /// Upgrade_Stories (Req 16.1).
  PlanArtifact assemble(PlanMapping mapping) =>
      PlanArtifact(mapping: mapping, upgradeStories: generate(mapping));

  /// Assembles a [PlanArtifact] for every mapping, keyed by business type.
  ///
  /// Used to produce the artifacts for all 19 target types at once from the
  /// builder's `buildAll` output (Req 16.1, 16.3).
  Map<String, PlanArtifact> assembleAll(Map<String, PlanMapping> mappings) => {
    for (final entry in mappings.entries) entry.key: assemble(entry.value),
  };

  // ---------------------------------------------------------------------------
  // Narrative rendering.
  // ---------------------------------------------------------------------------

  /// Builds a short, human-readable reason for one tier transition expressed in
  /// terms of the capabilities the higher tier adds (Req 16.4).
  String _narrative(
    String businessType,
    SubscriptionTier from,
    SubscriptionTier to,
    Set<BusinessCapability> added,
  ) {
    final fromName = _tierLabel(from);
    final toName = _tierLabel(to);
    if (added.isEmpty) {
      return 'Upgrading "$businessType" from $fromName to $toName adds no new '
          'capabilities; the registry is too small to differentiate these '
          'tiers.';
    }
    // Deterministic order so the narrative is reproducible.
    final labels = (added.toList()..sort((a, b) => a.index.compareTo(b.index)))
        .map(_humanize)
        .toList();
    final noun = added.length == 1 ? 'capability' : 'capabilities';
    return 'Upgrading "$businessType" from $fromName to $toName unlocks '
        '${added.length} $noun: ${_joinReadable(labels)}.';
  }

  /// The display label for a tier, e.g. `SubscriptionTier.basic` → `'Basic'`.
  String _tierLabel(SubscriptionTier tier) {
    final name = tier.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Turns a [BusinessCapability] identifier into a human-readable label.
  ///
  /// Drops the leading `use` prefix and inserts spaces at camelCase word
  /// boundaries while keeping acronyms intact, e.g.:
  ///
  /// * `useInvoiceCreate` → `'Invoice Create'`
  /// * `usePurchaseOrder` → `'Purchase Order'`
  /// * `useISBN`          → `'ISBN'`
  /// * `useEventStaffAllocation` → `'Event Staff Allocation'`
  String _humanize(BusinessCapability cap) {
    var name = cap.name;
    if (name.startsWith('use') && name.length > 3) {
      name = name.substring(3);
    }
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (i > 0 && _isUpper(ch)) {
        final prevLower = _isLower(name[i - 1]);
        final nextLower = i + 1 < name.length && _isLower(name[i + 1]);
        // Space before an uppercase letter that starts a new word: either it
        // follows a lowercase letter, or it begins a word after an acronym
        // (the next letter is lowercase).
        if (prevLower || nextLower) buffer.write(' ');
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  bool _isUpper(String ch) => ch != ch.toLowerCase() && ch == ch.toUpperCase();

  bool _isLower(String ch) => ch != ch.toUpperCase() && ch == ch.toLowerCase();

  /// Joins labels into a readable list: `'A'`, `'A and B'`, or `'A, B, and C'`.
  String _joinReadable(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head, and ${items.last}';
  }
}
