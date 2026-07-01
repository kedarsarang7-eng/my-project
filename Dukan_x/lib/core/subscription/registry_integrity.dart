/// Registry-entry integrity guard for the Tiering_System.
///
/// Before a (string-keyed) capability-registry entry for a business type is
/// accepted, every identifier it names must resolve to an existing
/// [BusinessCapability] enum member. This guard validates a proposed entry,
/// rejects any identifier that is not defined in the enum, and reports exactly
/// which identifiers are undefined.
///
/// This implements the hard-isolation safeguard for newly registered business
/// types (Requirement 4.9): a proposed entry that references an identifier not
/// defined in the `BusinessCapability` enum is rejected and the undefined
/// identifier is reported. It also underpins Requirement 4.2, which requires
/// new entries to be built only from enum members that already exist.
///
/// The module is pure Dart on top of the existing enum and has no other
/// dependencies.
library;

import '../isolation/business_capability.dart';

/// The outcome of validating a proposed registry entry against the
/// [BusinessCapability] enum.
///
/// An entry is [isValid] only when every proposed identifier resolves to an
/// enum member, i.e. when [undefinedIdentifiers] is empty.
class RegistryIntegrityResult {
  /// Whether every proposed identifier resolved to an existing
  /// [BusinessCapability] member.
  final bool isValid;

  /// The identifiers from the proposed entry that do not name any
  /// [BusinessCapability] member, in the order they were first encountered.
  ///
  /// Empty when the entry is valid.
  final List<String> undefinedIdentifiers;

  /// The [BusinessCapability] members that the valid identifiers resolved to,
  /// in the order they were first encountered.
  ///
  /// When the entry is invalid this still contains the capabilities for the
  /// identifiers that *were* recognised, so callers can inspect the partial
  /// resolution if useful.
  final List<BusinessCapability> resolvedCapabilities;

  const RegistryIntegrityResult({
    required this.isValid,
    required this.undefinedIdentifiers,
    required this.resolvedCapabilities,
  });

  /// The set of resolved capabilities, deduplicated.
  ///
  /// Convenience helper to map the valid names back to enum members for use as
  /// an actual registry entry once the proposal has been accepted.
  Set<BusinessCapability> toCapabilitySet() => resolvedCapabilities.toSet();

  @override
  String toString() {
    if (isValid) {
      return 'RegistryIntegrityResult(valid, '
          '${resolvedCapabilities.length} capabilities)';
    }
    return 'RegistryIntegrityResult(invalid, undefined: '
        '${undefinedIdentifiers.join(', ')})';
  }
}

/// Validates that a proposed registry entry names only identifiers that exist
/// in the [BusinessCapability] enum.
///
/// The guard is stateless apart from a cached lookup of enum members by their
/// `name`, built once from [BusinessCapability.values].
class RegistryIntegrityGuard {
  /// Lookup from a [BusinessCapability]'s `name` to the enum member itself.
  ///
  /// Built from [BusinessCapability.values] so it always reflects the current
  /// enum, with no hard-coded list to drift out of sync.
  final Map<String, BusinessCapability> _byName;

  RegistryIntegrityGuard()
    : _byName = {
        for (final capability in BusinessCapability.values)
          capability.name: capability,
      };

  /// The set of valid identifier names — the `name` of every
  /// [BusinessCapability] member.
  Set<String> get validIdentifierNames => _byName.keys.toSet();

  /// Whether [identifier] names an existing [BusinessCapability] member.
  bool isDefined(String identifier) => _byName.containsKey(identifier);

  /// Resolves [identifier] to its [BusinessCapability] member, or `null` when
  /// the identifier is not defined in the enum.
  BusinessCapability? resolve(String identifier) => _byName[identifier];

  /// Validates a proposed registry entry expressed as a collection of
  /// capability-name strings.
  ///
  /// Every identifier in [proposedIdentifiers] is checked against the set of
  /// valid [BusinessCapability] names. The result reports whether the entry is
  /// valid, which identifiers (if any) are undefined, and the capabilities the
  /// recognised identifiers resolved to.
  ///
  /// Order is preserved and duplicates are collapsed: an identifier that
  /// appears more than once is reported at most once in either
  /// [RegistryIntegrityResult.undefinedIdentifiers] or
  /// [RegistryIntegrityResult.resolvedCapabilities].
  RegistryIntegrityResult validateEntry(Iterable<String> proposedIdentifiers) {
    final undefined = <String>[];
    final resolved = <BusinessCapability>[];
    final seenUndefined = <String>{};
    final seenResolved = <BusinessCapability>{};

    for (final identifier in proposedIdentifiers) {
      final capability = _byName[identifier];
      if (capability == null) {
        if (seenUndefined.add(identifier)) {
          undefined.add(identifier);
        }
      } else {
        if (seenResolved.add(capability)) {
          resolved.add(capability);
        }
      }
    }

    return RegistryIntegrityResult(
      isValid: undefined.isEmpty,
      undefinedIdentifiers: List.unmodifiable(undefined),
      resolvedCapabilities: List.unmodifiable(resolved),
    );
  }
}
