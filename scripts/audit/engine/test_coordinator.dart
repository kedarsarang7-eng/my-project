/// TestCoordinator — coordinates per-fix test authoring, suite execution,
/// and the deterministic "fixed" classification predicate.
///
/// Pure-logic coordinator that:
/// - Determines which test types are required for a Finding ([authorTests])
/// - Runs the Business_Type_Test_Suite recording per-test results ([runSuite])
/// - Evaluates whether a Finding is classified as fixed ([isFixed])
///
/// The actual test execution is delegated to a [SuiteRunner] abstraction
/// so this component remains testable with mocks.
///
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10
library;

import '../models/audit_engine_models.dart';

// ---------------------------------------------------------------------------
// Test Type enum
// ---------------------------------------------------------------------------

/// The type of test obligation generated for a Finding.
enum TestType {
  /// Widget test: assertion that fails pre-fix / passes post-fix (Req 5.1).
  widget,

  /// Layout test at 360/768/1280 logical px (Req 5.2).
  layout,

  /// Golden test for light + dark Color_Mode (Req 5.3).
  golden,

  /// Overflow assertion: `tester.takeException()` is null (Req 5.4).
  overflow,

  /// Navigation test: active route + back-stack (Req 5.5).
  navigation,

  /// Accessibility test: Semantics-based (Req 5.6).
  accessibility;

  /// Human-readable label for reporting.
  String get label => switch (this) {
    TestType.widget => 'Widget (fail-pre/pass-post)',
    TestType.layout => 'Layout (360/768/1280 px)',
    TestType.golden => 'Golden (light + dark)',
    TestType.overflow => 'Overflow (takeException == null)',
    TestType.navigation => 'Navigation (route + back-stack)',
    TestType.accessibility => 'Accessibility (Semantics)',
  };
}

// ---------------------------------------------------------------------------
// Test Obligation
// ---------------------------------------------------------------------------

/// One test obligation generated for a Finding.
///
/// Each obligation represents a specific test that must be authored and pass
/// for the Finding to be classified as fixed.
class TestObligation {
  /// Unique test identifier (format: `T-{findingId}-{type}`).
  final String testId;

  /// The type of test to write.
  final TestType type;

  /// Human-readable description of what the test asserts.
  final String description;

  /// The Finding this obligation is for.
  final Finding finding;

  const TestObligation({
    required this.testId,
    required this.type,
    required this.description,
    required this.finding,
  });

  @override
  String toString() => 'TestObligation($testId, ${type.name})';
}

// ---------------------------------------------------------------------------
// Test Authoring Result
// ---------------------------------------------------------------------------

/// Result of test authoring for a Finding.
///
/// Contains the list of [TestObligation]s that must pass for the Finding
/// to be classified as fixed. If a required test cannot be authored,
/// [blocked] is true and [blockedReason] explains why.
class TestAuthoring {
  /// The Finding these test obligations belong to.
  final Finding finding;

  /// The test obligations generated.
  final List<TestObligation> obligations;

  /// True if a required test cannot be authored → Blocked_Item (Req 5.10).
  final bool blocked;

  /// Reason why test authoring is blocked (when [blocked] is true).
  final String? blockedReason;

  const TestAuthoring({
    required this.finding,
    required this.obligations,
    this.blocked = false,
    this.blockedReason,
  });

  /// Creates a blocked test authoring result.
  const TestAuthoring.blocked({required this.finding, required String reason})
    : obligations = const [],
      blocked = true,
      blockedReason = reason;

  @override
  String toString() =>
      'TestAuthoring(${finding.id}, obligations: ${obligations.length}'
      '${blocked ? ', BLOCKED: $blockedReason' : ''})';
}

// ---------------------------------------------------------------------------
// Suite Run Result
// ---------------------------------------------------------------------------

/// Result of running the full Business_Type_Test_Suite.
///
/// Records `(testId, Pass|Fail)` per test (Req 5.7).
class SuiteRun {
  /// The business type this suite was run for.
  final BusinessType businessType;

  /// All test results from the suite execution.
  final List<TestResult> results;

  const SuiteRun({required this.businessType, required this.results});

  /// Number of failing tests in this run.
  int get failingCount => results.where((r) => !r.passed).length;

  /// Whether a specific test passed in this run.
  bool testPassed(String testId) =>
      results.any((r) => r.testId == testId && r.passed);

  /// Whether a specific test failed in this run.
  bool testFailed(String testId) =>
      results.any((r) => r.testId == testId && !r.passed);

  @override
  String toString() =>
      'SuiteRun(${businessType.displayName}, '
      'total: ${results.length}, failing: $failingCount)';
}

// ---------------------------------------------------------------------------
// Suite Runner (abstract interface for test execution)
// ---------------------------------------------------------------------------

/// Abstract interface for running the Business_Type_Test_Suite.
///
/// Implementations may invoke `flutter test`, a subprocess, or a mock.
/// This abstraction keeps [TestCoordinator] testable without real test
/// execution.
abstract class SuiteRunner {
  /// Runs the full test suite for the given [businessType] and returns
  /// all test results.
  List<TestResult> run(BusinessType businessType);
}

// ---------------------------------------------------------------------------
// Test Coordinator
// ---------------------------------------------------------------------------

/// Coordinates test obligations, suite execution, and the fixed-classification
/// predicate for the audit-and-remediation process.
///
/// Design interface:
/// - [authorTests] → determines required tests per Finding
/// - [runSuite] → executes the full Business_Type_Test_Suite
/// - [isFixed] → true iff Finding's test passes AND suite has zero failures
class TestCoordinator {
  /// The suite runner that executes the actual tests.
  final SuiteRunner _suiteRunner;

  /// Optional previous suite run for regression detection (Req 5.8).
  SuiteRun? previousRun;

  /// Creates a [TestCoordinator] with the given [suiteRunner].
  ///
  /// [previousRun] can be set to enable regression detection: if a test
  /// that passed in the previous run fails in the current run, it blocks
  /// the "fixed" classification.
  TestCoordinator({required SuiteRunner suiteRunner, this.previousRun})
    : _suiteRunner = suiteRunner;

  /// Determines which test obligations are required for a [Finding] based
  /// on its category, and generates the corresponding [TestAuthoring].
  ///
  /// Test types generated per category:
  /// - All fixes: widget test (fail-pre/pass-post) — Req 5.1
  /// - Layout/overflow findings: layout tests at 360/768/1280 — Req 5.2
  /// - All fixes (with goldens): light + dark golden tests — Req 5.3
  /// - Overflow findings: `tester.takeException()` is null — Req 5.4
  /// - Navigation findings (uiUxCorrectness with navigation): route + back-stack — Req 5.5
  /// - Accessibility findings (uiUxCorrectness with accessibility): Semantics — Req 5.6
  ///
  /// If a required test cannot be authored (e.g., missing spec or ambiguous
  /// requirement for the test target), returns [TestAuthoring.blocked] and
  /// the Finding should be recorded as a Blocked_Item (Req 5.10).
  ///
  /// The optional [canAuthor] callback is consulted for each obligation. If
  /// it returns false for any required test, the authoring is blocked.
  TestAuthoring authorTests(
    Finding finding, {
    bool Function(TestType type, Finding finding)? canAuthor,
  }) {
    final obligations = <TestObligation>[];

    // ─── 1. Widget test (all fixes) — Req 5.1 ─────────────────────────────
    final widgetObligation = TestObligation(
      testId: 'T-${finding.id}-widget',
      type: TestType.widget,
      description:
          'Widget test asserting failure pre-fix and pass post-fix '
          'for ${finding.screen.name} (${finding.description})',
      finding: finding,
    );
    if (canAuthor != null && !canAuthor(TestType.widget, finding)) {
      return TestAuthoring.blocked(
        finding: finding,
        reason:
            'Cannot author widget test for ${finding.id}: '
            'missing specification or ambiguous requirement.',
      );
    }
    obligations.add(widgetObligation);

    // ─── 2. Layout tests (layout/overflow findings) — Req 5.2 ─────────────
    if (_requiresLayoutTest(finding)) {
      if (canAuthor != null && !canAuthor(TestType.layout, finding)) {
        return TestAuthoring.blocked(
          finding: finding,
          reason:
              'Cannot author layout test for ${finding.id}: '
              'missing specification or ambiguous requirement.',
        );
      }
      obligations.add(
        TestObligation(
          testId: 'T-${finding.id}-layout',
          type: TestType.layout,
          description:
              'Layout tests at 360/768/1280 logical px asserting no '
              'overflow or clipping for ${finding.screen.name}',
          finding: finding,
        ),
      );
    }

    // ─── 3. Golden tests (all fixes) — Req 5.3 ────────────────────────────
    if (canAuthor != null && !canAuthor(TestType.golden, finding)) {
      return TestAuthoring.blocked(
        finding: finding,
        reason:
            'Cannot author golden test for ${finding.id}: '
            'missing specification or ambiguous requirement.',
      );
    }
    obligations.add(
      TestObligation(
        testId: 'T-${finding.id}-golden',
        type: TestType.golden,
        description:
            'Golden tests for light and dark Color_Mode '
            'for ${finding.screen.name}',
        finding: finding,
      ),
    );

    // ─── 4. Overflow assertion — Req 5.4 ──────────────────────────────────
    if (_requiresOverflowTest(finding)) {
      if (canAuthor != null && !canAuthor(TestType.overflow, finding)) {
        return TestAuthoring.blocked(
          finding: finding,
          reason:
              'Cannot author overflow test for ${finding.id}: '
              'missing specification or ambiguous requirement.',
        );
      }
      obligations.add(
        TestObligation(
          testId: 'T-${finding.id}-overflow',
          type: TestType.overflow,
          description:
              'Overflow assertion: tester.takeException() returns null '
              'after rendering ${finding.screen.name}',
          finding: finding,
        ),
      );
    }

    // ─── 5. Navigation test — Req 5.5 ─────────────────────────────────────
    if (_requiresNavigationTest(finding)) {
      if (canAuthor != null && !canAuthor(TestType.navigation, finding)) {
        return TestAuthoring.blocked(
          finding: finding,
          reason:
              'Cannot author navigation test for ${finding.id}: '
              'missing specification or ambiguous requirement.',
        );
      }
      obligations.add(
        TestObligation(
          testId: 'T-${finding.id}-navigation',
          type: TestType.navigation,
          description:
              'Navigation test asserting active route and back-stack '
              'entries for ${finding.screen.name}',
          finding: finding,
        ),
      );
    }

    // ─── 6. Accessibility test — Req 5.6 ──────────────────────────────────
    if (_requiresAccessibilityTest(finding)) {
      if (canAuthor != null && !canAuthor(TestType.accessibility, finding)) {
        return TestAuthoring.blocked(
          finding: finding,
          reason:
              'Cannot author accessibility test for ${finding.id}: '
              'missing specification or ambiguous requirement.',
        );
      }
      obligations.add(
        TestObligation(
          testId: 'T-${finding.id}-accessibility',
          type: TestType.accessibility,
          description:
              'Semantics-based accessibility test asserting expected '
              'semantic labels and traversal order for ${finding.screen.name}',
          finding: finding,
        ),
      );
    }

    return TestAuthoring(finding: finding, obligations: obligations);
  }

  /// Runs the full Business_Type_Test_Suite for the given [active] business
  /// type, recording `(testId, Pass|Fail)` per test (Req 5.7).
  ///
  /// After execution, stores the result as [previousRun] for future
  /// regression detection.
  SuiteRun runSuite(BusinessType active) {
    final results = _suiteRunner.run(active);
    final run = SuiteRun(businessType: active, results: results);

    // Store as previous run for regression detection on next invocation
    previousRun = run;

    return run;
  }

  /// Determines whether a Finding is classified as "fixed" (Req 5.9).
  ///
  /// Returns `true` if and only if:
  /// 1. The Finding's own test passes in [run], AND
  /// 2. The suite reports zero failing tests in [run] (Req 5.9).
  ///
  /// Additionally, if [previousRun] is available: a test that passed in
  /// [previousRun] but fails in [run] is a regression (Req 5.8), which
  /// prevents the Finding from being classified as fixed.
  bool isFixed(Finding finding, SuiteRun run) {
    // Check if any regression exists (Req 5.8):
    // A regression is a test that passed before but fails now.
    if (previousRun != null) {
      for (final prevResult in previousRun!.results) {
        if (prevResult.passed) {
          // This test passed before — check if it fails now
          if (run.testFailed(prevResult.testId)) {
            // Regression detected → blocks "fixed" classification
            return false;
          }
        }
      }
    }

    // Condition 1: The Finding's own test must pass.
    final findingTestId = 'T-${finding.id}-widget';
    if (!run.testPassed(findingTestId)) {
      return false;
    }

    // Condition 2: The suite must have zero failing tests.
    if (run.failingCount != 0) {
      return false;
    }

    return true;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Whether a Finding requires layout tests at 360/768/1280 (Req 5.2).
  ///
  /// Required for layout/overflow and responsiveness findings.
  bool _requiresLayoutTest(Finding finding) {
    return finding.category == ChecklistCategory.layoutAndOverflow ||
        finding.category == ChecklistCategory.responsivenessAndPlatformCoverage;
  }

  /// Whether a Finding requires an overflow assertion (Req 5.4).
  ///
  /// Required specifically for overflow-related findings.
  bool _requiresOverflowTest(Finding finding) {
    return finding.category == ChecklistCategory.layoutAndOverflow;
  }

  /// Whether a Finding requires a navigation test (Req 5.5).
  ///
  /// Required for UI/UX correctness findings that involve navigation.
  /// Detection heuristic: category is uiUxCorrectness AND description
  /// mentions navigation-related keywords.
  bool _requiresNavigationTest(Finding finding) {
    if (finding.category != ChecklistCategory.uiUxCorrectness) return false;
    final desc = finding.description.toLowerCase();
    return desc.contains('navigation') ||
        desc.contains('route') ||
        desc.contains('back-stack') ||
        desc.contains('deep link') ||
        desc.contains('back button') ||
        desc.contains('navigator');
  }

  /// Whether a Finding requires an accessibility test (Req 5.6).
  ///
  /// Required for UI/UX correctness findings that involve accessibility.
  /// Detection heuristic: category is uiUxCorrectness AND description
  /// mentions accessibility-related keywords.
  bool _requiresAccessibilityTest(Finding finding) {
    if (finding.category != ChecklistCategory.uiUxCorrectness) return false;
    final desc = finding.description.toLowerCase();
    return desc.contains('accessibility') ||
        desc.contains('semantic') ||
        desc.contains('screen reader') ||
        desc.contains('tap target') ||
        desc.contains('contrast') ||
        desc.contains('focus traversal') ||
        desc.contains('reading order') ||
        desc.contains('a11y');
  }
}
