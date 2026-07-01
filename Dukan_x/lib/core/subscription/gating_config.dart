/// Machine-consumable Gating_Config for the Tiering_System.
///
/// The Gating_Config is the serializable representation of the Plan_Mapping
/// that drives gating logic in `business_capability.dart` without manual
/// transcription (Req 19). It maps, for each business type, every subscription
/// tier to the cumulative set of [BusinessCapability] values granted at that
/// tier:
///
/// ```
/// (businessType, tier) → Set<BusinessCapability>
/// ```
///
/// Serialization uses the **exact** `BusinessCapability` enum identifier names
/// (Req 19.2), tiers stay cumulative — `basic ⊆ pro ⊆ premium ⊆ enterprise`
/// (Req 19.5) — and every granted capability is validated to be a
/// Registered_Capability for its type (Req 19.3). A config that grants a
/// capability which is not registered for its type, or that names an identifier
/// that does not resolve to a `BusinessCapability`, is rejected with the
/// offending entry reported via [GatingConfigError] (Req 19.4).
///
/// The JSON shape is:
///
/// ```json
/// {
///   "version": 1,
///   "tierOrder": ["basic", "pro", "premium", "enterprise"],
///   "grants": {
///     "grocery": {
///       "basic":      ["useInvoiceCreate", "..."],
///       "pro":        ["...superset of basic..."],
///       "premium":    ["...superset of pro..."],
///       "enterprise": ["...all registered capabilities..."]
///     }
///   }
/// }
/// ```
library;

import '../isolation/business_capability.dart';
import 'plan_mapping.dart';
import 'registry_integrity.dart';
import 'subscription_tier.dart';

/// The JSON schema version emitted by [GatingConfig.toJson].
const int _gatingConfigVersion = 1;

/// Shared enum-name ↔ value lookup, built once from `BusinessCapability.values`.
///
/// Reused for robust, drift-free resolution of identifier strings back to enum
/// members (Req 19.2) and for reporting identifiers that do not resolve.
final RegistryIntegrityGuard _capabilityGuard = RegistryIntegrityGuard();

/// Lookup from a [SubscriptionTier]'s `name` to the enum member itself.
final Map<String, SubscriptionTier> _tiersByName = {
  for (final tier in SubscriptionTier.values) tier.name: tier,
};

/// Thrown when a Gating_Config is rejected while building or decoding.
///
/// Carries enough context to identify the offending entry (Req 19.4): the
/// [businessType], the [tier], and the [capabilityName] involved, where
/// applicable, plus a human-readable [message].
class GatingConfigError implements Exception {
  /// The business type whose entry was rejected, or empty for structural
  /// errors that are not tied to a single type.
  final String businessType;

  /// The tier whose grant set was rejected, when applicable.
  final SubscriptionTier? tier;

  /// The offending capability identifier, when applicable.
  final String? capabilityName;

  /// A human-readable description of why the config was rejected.
  final String message;

  const GatingConfigError(
    this.message, {
    this.businessType = '',
    this.tier,
    this.capabilityName,
  });

  @override
  String toString() {
    final context = <String>[
      if (businessType.isNotEmpty) 'type: $businessType',
      if (tier != null) 'tier: ${tier!.name}',
      if (capabilityName != null) 'capability: $capabilityName',
    ];
    final suffix = context.isEmpty ? '' : ' (${context.join(', ')})';
    return 'GatingConfigError: $message$suffix';
  }
}

/// The serializable map of `(businessType, tier) → Set<BusinessCapability>`
/// that drives capability gating (Req 19).
///
/// Instances are immutable: [grants] and its nested maps and sets are
/// unmodifiable views. Build one from validated plan mappings with
/// [GatingConfig.fromMappings], or decode one from JSON with
/// [GatingConfig.fromJson]; both paths validate registration (Req 19.3) and
/// cumulative tier order (Req 19.5).
class GatingConfig {
  /// The JSON schema version this config was created with.
  final int version;

  /// `grants[businessType][tier]` = the cumulative capabilities granted at that
  /// tier. Higher tiers are supersets of lower tiers for the same type.
  final Map<String, Map<SubscriptionTier, Set<BusinessCapability>>> grants;

  GatingConfig._(
    Map<String, Map<SubscriptionTier, Set<BusinessCapability>>> grants, {
    this.version = _gatingConfigVersion,
  }) : grants =
           // Explicit type arguments are required on every nested
           // `unmodifiable` call: `Map.unmodifiable`/`Set.unmodifiable` take a
           // `dynamic`-typed argument, so without them the inner views are
           // inferred as `UnmodifiableMapView<dynamic, dynamic>` and the outer
           // construction throws a runtime cast error.
           Map<
             String,
             Map<SubscriptionTier, Set<BusinessCapability>>
           >.unmodifiable({
             for (final typeEntry in grants.entries)
               typeEntry.key:
                   Map<SubscriptionTier, Set<BusinessCapability>>.unmodifiable({
                     for (final tierEntry in typeEntry.value.entries)
                       tierEntry.key: Set<BusinessCapability>.unmodifiable(
                         tierEntry.value,
                       ),
                   }),
           });

  /// The cumulative capabilities granted to [businessType] at [tier].
  ///
  /// Returns an empty (unmodifiable) set when the type or tier is unknown,
  /// which keeps the default gating outcome "denied".
  Set<BusinessCapability> capabilitiesFor(
    String businessType,
    SubscriptionTier tier,
  ) => grants[businessType]?[tier] ?? const <BusinessCapability>{};

  /// Builds a Gating_Config directly from validated plan [mappings].
  ///
  /// Reads each mapping's cumulative tier sets, then validates that every
  /// granted capability is registered for its type (Req 19.3) and that the
  /// tiers remain cumulative (Req 19.5). Rejects with a [GatingConfigError]
  /// reporting the offending entry otherwise (Req 19.4).
  ///
  /// [registry] defaults to the global [businessCapabilityRegistry]; it can be
  /// overridden for testing.
  factory GatingConfig.fromMappings(
    Map<String, PlanMapping> mappings, {
    Map<String, Set<BusinessCapability>>? registry,
  }) {
    final grants = <String, Map<SubscriptionTier, Set<BusinessCapability>>>{};
    for (final entry in mappings.entries) {
      final mapping = entry.value;
      grants[entry.key] = {
        for (final tier in SubscriptionTier.values)
          tier: mapping.capabilitiesAt(tier).toSet(),
      };
    }
    _validateGrants(grants, registry ?? businessCapabilityRegistry);
    return GatingConfig._(grants);
  }

  /// Decodes a Gating_Config from its [json] representation.
  ///
  /// Every capability identifier string must resolve to a [BusinessCapability]
  /// (Req 19.2) and be registered for its type (Req 19.3); the tiers must stay
  /// cumulative (Req 19.5). Any violation is rejected with a [GatingConfigError]
  /// naming the offending entry (Req 19.4).
  ///
  /// [registry] defaults to the global [businessCapabilityRegistry]; it can be
  /// overridden for testing.
  factory GatingConfig.fromJson(
    Map<String, dynamic> json, {
    Map<String, Set<BusinessCapability>>? registry,
  }) {
    final rawVersion = json['version'];
    final version = rawVersion is int ? rawVersion : _gatingConfigVersion;

    final rawGrants = json['grants'];
    if (rawGrants is! Map) {
      throw const GatingConfigError(
        'Gating_Config is missing a "grants" object.',
      );
    }

    final grants = <String, Map<SubscriptionTier, Set<BusinessCapability>>>{};
    for (final typeEntry in rawGrants.entries) {
      final businessType = typeEntry.key.toString();
      final rawTierMap = typeEntry.value;
      if (rawTierMap is! Map) {
        throw GatingConfigError(
          'Grants for a business type must be an object of tier → capability '
          'list.',
          businessType: businessType,
        );
      }

      final tierSets = <SubscriptionTier, Set<BusinessCapability>>{
        for (final tier in SubscriptionTier.values)
          tier: <BusinessCapability>{},
      };

      for (final tierEntry in rawTierMap.entries) {
        final tierName = tierEntry.key.toString();
        final tier = _tiersByName[tierName];
        if (tier == null) {
          throw GatingConfigError(
            'Unknown tier "$tierName"; expected one of '
            '${_tiersByName.keys.join(', ')}.',
            businessType: businessType,
          );
        }

        final rawCaps = tierEntry.value;
        if (rawCaps is! List) {
          throw GatingConfigError(
            'Capabilities for a tier must be a list of enum identifier names.',
            businessType: businessType,
            tier: tier,
          );
        }

        final caps = <BusinessCapability>{};
        for (final rawName in rawCaps) {
          final name = rawName.toString();
          final capability = _capabilityGuard.resolve(name);
          if (capability == null) {
            // The identifier does not resolve to any BusinessCapability member.
            throw GatingConfigError(
              'Identifier "$name" does not resolve to a BusinessCapability.',
              businessType: businessType,
              tier: tier,
              capabilityName: name,
            );
          }
          caps.add(capability);
        }
        tierSets[tier] = caps;
      }
      grants[businessType] = tierSets;
    }

    _validateGrants(grants, registry ?? businessCapabilityRegistry);
    return GatingConfig._(grants, version: version);
  }

  /// Serializes this config to a stable JSON map using exact enum identifier
  /// names (Req 19.2).
  ///
  /// Capability lists are ordered by enum declaration index so the output is
  /// deterministic and round-trips through [GatingConfig.fromJson].
  Map<String, dynamic> toJson() => {
    'version': version,
    'tierOrder': [for (final tier in SubscriptionTier.values) tier.name],
    'grants': {
      for (final typeEntry in grants.entries)
        typeEntry.key: {
          for (final tier in SubscriptionTier.values)
            tier.name: _sortedNames(typeEntry.value[tier]),
        },
    },
  };

  /// Capability `name`s for [caps], ordered by enum declaration index.
  static List<String> _sortedNames(Set<BusinessCapability>? caps) {
    final list = (caps ?? const <BusinessCapability>{}).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return [for (final capability in list) capability.name];
  }

  /// Validates [grants] against [registry]: every granted capability must be a
  /// Registered_Capability for its type (Req 19.3), and tiers must be
  /// cumulative — `basic ⊆ pro ⊆ premium ⊆ enterprise` (Req 19.5). Throws a
  /// [GatingConfigError] naming the offending entry on the first violation
  /// (Req 19.4).
  static void _validateGrants(
    Map<String, Map<SubscriptionTier, Set<BusinessCapability>>> grants,
    Map<String, Set<BusinessCapability>> registry,
  ) {
    for (final typeEntry in grants.entries) {
      final businessType = typeEntry.key;
      final registered = registry[businessType];
      if (registered == null) {
        throw GatingConfigError(
          'Business type "$businessType" is not present in the '
          'Capability_Registry, so its grants cannot be validated.',
          businessType: businessType,
        );
      }

      // Req 19.3 / 19.4: every granted capability must be registered.
      for (final tierEntry in typeEntry.value.entries) {
        for (final capability in tierEntry.value) {
          if (!registered.contains(capability)) {
            throw GatingConfigError(
              'Capability "${capability.name}" is not a Registered_Capability '
              'for "$businessType".',
              businessType: businessType,
              tier: tierEntry.key,
              capabilityName: capability.name,
            );
          }
        }
      }

      // Req 19.5: consecutive tiers must form a cumulative chain.
      for (var i = 1; i < SubscriptionTier.values.length; i++) {
        final lower = SubscriptionTier.values[i - 1];
        final higher = SubscriptionTier.values[i];
        final lowerCaps =
            typeEntry.value[lower] ?? const <BusinessCapability>{};
        final higherCaps =
            typeEntry.value[higher] ?? const <BusinessCapability>{};
        for (final capability in lowerCaps) {
          if (!higherCaps.contains(capability)) {
            throw GatingConfigError(
              'Tier order is not cumulative: "${capability.name}" is granted '
              'at ${lower.name} but missing at ${higher.name}.',
              businessType: businessType,
              tier: higher,
              capabilityName: capability.name,
            );
          }
        }
      }
    }
  }

  @override
  String toString() =>
      'GatingConfig(version: $version, types: ${grants.length})';
}
