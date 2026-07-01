/// Coverage-gap detection logic for the Certification_System.
///
/// Records a gap iff actual < expected (460 screens, 19 types), stating
/// expected, actual, and non-negative shortfall. Also detects requirements
/// with zero linked test cases.
///
/// Requirements: 1.8, 1.9, 13.3, 13.4
library;

/// A single coverage gap entry.
///
/// A gap exists when actual coverage falls below the expected level.
/// The [shortfall] is always non-negative (expected - actual when actual < expected).
class CoverageGap {
  /// The kind of gap: 'screens', 'businessTypes', or 'requirement'.
  final String kind;

  /// The expected count for this category.
  final int expected;

  /// The actual count observed.
  final int actual;

  /// The shortfall: expected - actual. Always non-negative.
  final int shortfall;

  /// Optional explanation (e.g., requirement ID for zero-test requirements).
  final String? reason;

  CoverageGap({
    required this.kind,
    required this.expected,
    required this.actual,
    required this.shortfall,
    this.reason,
  }) : assert(shortfall >= 0, 'Shortfall must be non-negative'),
       assert(
         shortfall == expected - actual,
         'Shortfall must equal expected - actual',
       );

  @override
  String toString() =>
      'CoverageGap(kind: $kind, expected: $expected, actual: $actual, '
      'shortfall: $shortfall${reason != null ? ', reason: $reason' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoverageGap &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          expected == other.expected &&
          actual == other.actual &&
          shortfall == other.shortfall &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(kind, expected, actual, shortfall, reason);
}

/// Pure logic calculator for coverage gaps.
///
/// This is deterministic, no-IO logic suitable for property-based testing.
class CoverageGapCalculator {
  /// Expected number of screens in the DukanX application (Req 1.8).
  static const int kExpectedScreens = 460;

  /// Expected number of business types (Req 1.9).
  static const int kExpectedBusinessTypes = 19;

  /// Records a gap iff [actual] < [expected].
  ///
  /// Returns a [CoverageGap] with shortfall = expected - actual when a gap
  /// exists, or `null` when coverage meets or exceeds the expected count.
  ///
  /// For screens: expected = 460
  /// For business types: expected = 19
  CoverageGap? checkCount(String kind, int expected, int actual) {
    if (actual < expected) {
      return CoverageGap(
        kind: kind,
        expected: expected,
        actual: actual,
        shortfall: expected - actual,
      );
    }
    return null;
  }

  /// Detect requirements with zero test cases linked.
  ///
  /// Takes a map of requirement ID → list of linked test case IDs.
  /// Returns a [CoverageGap] for each requirement that has an empty
  /// (or absent) test-case list.
  ///
  /// Each gap has kind = 'requirement', expected = 1 (minimum one test),
  /// actual = 0, shortfall = 1, and reason identifying the requirement.
  ///
  /// Requirements: 13.3, 13.4
  List<CoverageGap> detectZeroTestRequirements(
    Map<String, List<String>> requirementToTests,
  ) {
    final gaps = <CoverageGap>[];

    for (final entry in requirementToTests.entries) {
      if (entry.value.isEmpty) {
        gaps.add(
          CoverageGap(
            kind: 'requirement',
            expected: 1,
            actual: 0,
            shortfall: 1,
            reason: 'Requirement ${entry.key} has zero linked test cases',
          ),
        );
      }
    }

    return gaps;
  }

  /// Convenience: check screen count against the expected 460 (Req 1.8).
  CoverageGap? checkScreenCount(int actualScreens) =>
      checkCount('screens', kExpectedScreens, actualScreens);

  /// Convenience: check business type count against the expected 19 (Req 1.9).
  CoverageGap? checkBusinessTypeCount(int actualTypes) =>
      checkCount('businessTypes', kExpectedBusinessTypes, actualTypes);
}
