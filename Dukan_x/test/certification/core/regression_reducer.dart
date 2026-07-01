/// Regression reduction logic for the Certification_System.
///
/// Reduces per-test results to an overall regression status.
/// The overall status is failed if and only if at least one test failed.
/// When failed: the release is blocked and the notification set equals exactly
/// the set of failed tests. When all pass: the release is not blocked.
///
/// Pure logic, no I/O. This is a simple conjunction reducer.
///
/// Requirements: 8.2, 8.3
library;

/// Outcome of a single test execution.
enum TestOutcome { passed, failed }

/// The result of a single test case within the regression suite.
class TestCaseResult {
  /// Unique identifier for this test case.
  final String testId;

  /// Human-readable name describing what this test validates.
  final String testName;

  /// Whether the test passed or failed.
  final TestOutcome outcome;

  const TestCaseResult({
    required this.testId,
    required this.testName,
    required this.outcome,
  });
}

/// The overall result of running the regression suite.
///
/// Contains the aggregated status, whether the release is blocked, and
/// exactly the set of test IDs that failed (for notification purposes).
class RegressionResult {
  /// Overall status: failed iff ≥1 test failed (Req 8.2).
  final TestOutcome overallStatus;

  /// True when overall status is failed — blocks the release and prevents
  /// promotion of the change to the next stage (Req 8.3).
  final bool releaseBlocked;

  /// Exactly the set of failed test IDs for notification (Req 8.3).
  /// Empty when all tests pass.
  final Set<String> failedTestIds;

  const RegressionResult({
    required this.overallStatus,
    required this.releaseBlocked,
    required this.failedTestIds,
  });
}

/// Pure reducer that computes the overall regression result from per-test
/// results.
///
/// The reduction logic is a simple conjunction:
/// - Failed iff ≥1 test failed.
/// - When failed: block release and notify exactly the failed set.
/// - When all pass: do not block.
///
/// An empty result set (no tests executed) is treated as passed (vacuous truth)
/// since there are no failures to report.
class RegressionReducer {
  const RegressionReducer();

  /// Reduce [results] to an overall regression status.
  ///
  /// Returns a [RegressionResult] with:
  /// - [RegressionResult.overallStatus] = failed iff any result has
  ///   [TestOutcome.failed]
  /// - [RegressionResult.releaseBlocked] = true when overall is failed
  /// - [RegressionResult.failedTestIds] = exactly the set of test IDs that
  ///   failed (for notification)
  RegressionResult reduce(List<TestCaseResult> results) {
    final failedIds = <String>{};

    for (final result in results) {
      if (result.outcome == TestOutcome.failed) {
        failedIds.add(result.testId);
      }
    }

    final hasFailed = failedIds.isNotEmpty;

    return RegressionResult(
      overallStatus: hasFailed ? TestOutcome.failed : TestOutcome.passed,
      releaseBlocked: hasFailed,
      failedTestIds: failedIds,
    );
  }
}
