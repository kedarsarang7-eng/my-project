// Feature: comprehensive-test-certification, Property 10
// ============================================================================
// Task 7.5 — PROPERTY TEST
// **Validates: Requirements 8.2, 8.3**
// ============================================================================
// Property 10: Regression result reduces to a conjunction and blocks on any
// failure.
//
//   For any set of per-test results, the Regression_Suite overall status is
//   failed if and only if at least one test failed; when failed the release is
//   blocked and the notification set equals exactly the set of failed tests;
//   when all pass the overall status is passed and the release is not blocked
//   on this gate.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_10_regression_conjunction_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../pbt/generators.dart';
import '../core/regression_reducer.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Generates a unique test ID string.
final Generator<String> _testIdGen = Gen.interval(
  1,
  99999,
).map((n) => 'TEST-${n.toString().padLeft(5, '0')}');

/// Generates a list of TestCaseResults where ALL tests pass.
/// Produces 1–30 test cases, each with outcome = passed.
final Generator<List<TestCaseResult>> _allPassingGen =
    Gen.tuple([
      Gen.interval(1, 30), // number of test cases
      Gen.interval(0, 99999), // seed for ID generation
    ]).map((parts) {
      final int count = parts[0] as int;
      final int seed = parts[1] as int;
      final results = <TestCaseResult>[];
      for (int i = 0; i < count; i++) {
        final id =
            'TEST-${((seed + i * 13) % 99999).toString().padLeft(5, '0')}';
        results.add(
          TestCaseResult(
            testId: id,
            testName: 'passing-test-$i',
            outcome: TestOutcome.passed,
          ),
        );
      }
      return results;
    });

/// Generates a list of TestCaseResults where at least one test FAILS.
/// Produces 1–30 test cases with a guaranteed failure among them.
final Generator<List<TestCaseResult>> _withFailuresGen =
    Gen.tuple([
      Gen.interval(1, 30), // total number of test cases
      Gen.interval(0, 99999), // seed for ID generation
      Gen.interval(1, 10), // number of additional failing cases
    ]).map((parts) {
      final int totalCount = parts[0] as int;
      final int seed = parts[1] as int;
      final int failCount = (parts[2] as int).clamp(1, totalCount);

      final results = <TestCaseResult>[];
      for (int i = 0; i < totalCount; i++) {
        final id =
            'TEST-${((seed + i * 17) % 99999).toString().padLeft(5, '0')}';
        final shouldFail = i < failCount;
        results.add(
          TestCaseResult(
            testId: id,
            testName: shouldFail ? 'failing-test-$i' : 'passing-test-$i',
            outcome: shouldFail ? TestOutcome.failed : TestOutcome.passed,
          ),
        );
      }
      return results;
    });

/// Generates a mixed list of TestCaseResults — randomly chosen pass/fail.
/// Uses a mode flag: 0 = all pass, 1 = at least one fails.
final Generator<List<TestCaseResult>> _mixedGen =
    Gen.tuple([
      Gen.interval(0, 1), // 0 = all pass, 1 = inject at least one failure
      Gen.interval(1, 25), // number of cases
      Gen.interval(0, 99999), // seed
      Gen.interval(0, 99999), // seed for fail injection
    ]).map((parts) {
      final int mode = parts[0] as int;
      final int count = parts[1] as int;
      final int seed = parts[2] as int;
      final int failSeed = parts[3] as int;

      final results = <TestCaseResult>[];
      for (int i = 0; i < count; i++) {
        final id =
            'TEST-${((seed + i * 11) % 99999).toString().padLeft(5, '0')}';
        results.add(
          TestCaseResult(
            testId: id,
            testName: 'test-$i',
            outcome: TestOutcome.passed,
          ),
        );
      }

      // If mode == 1, inject at least one failure
      if (mode == 1) {
        final failIdx = failSeed % count;
        final failId = 'TEST-FAIL-${failSeed.toString().padLeft(5, '0')}';
        results.add(
          TestCaseResult(
            testId: failId,
            testName: 'injected-fail',
            outcome: TestOutcome.failed,
          ),
        );
      }

      return results;
    });

// ============================================================================
// TESTS
// ============================================================================

void main() {
  group(
    'Feature: comprehensive-test-certification, Property 10 '
    '(Regression result reduces to a conjunction and blocks on any failure)',
    () {
      const reducer = RegressionReducer();

      // -----------------------------------------------------------------------
      // FORWARD: All tests pass → overall passed, release NOT blocked,
      // failedTestIds is empty.
      // -----------------------------------------------------------------------
      test('FORWARD: all tests pass → overall passed, not blocked, empty '
          'failedTestIds', () {
        final held = forAll(
          (List<TestCaseResult> results) {
            final regression = reducer.reduce(results);

            // Overall status must be passed
            if (regression.overallStatus != TestOutcome.passed) return false;

            // Release must NOT be blocked
            if (regression.releaseBlocked) return false;

            // failedTestIds must be empty
            if (regression.failedTestIds.isNotEmpty) return false;

            return true;
          },
          [_allPassingGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -----------------------------------------------------------------------
      // REJECTION: At least one test fails → overall failed, release blocked,
      // failedTestIds = exactly the set of failed tests.
      // -----------------------------------------------------------------------
      test('REJECTION: any test fails → overall failed, release blocked, '
          'failedTestIds equals exactly the failed set', () {
        final held = forAll(
          (List<TestCaseResult> results) {
            final regression = reducer.reduce(results);

            // Overall status must be failed
            if (regression.overallStatus != TestOutcome.failed) return false;

            // Release must be blocked
            if (!regression.releaseBlocked) return false;

            // Compute expected failed IDs
            final expectedFailedIds = results
                .where((r) => r.outcome == TestOutcome.failed)
                .map((r) => r.testId)
                .toSet();

            // failedTestIds must exactly match
            if (regression.failedTestIds.length != expectedFailedIds.length) {
              return false;
            }
            if (!regression.failedTestIds.containsAll(expectedFailedIds)) {
              return false;
            }

            return true;
          },
          [_withFailuresGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -----------------------------------------------------------------------
      // CONJUNCTION (bi-directional): failed iff ≥1 test failed
      // -----------------------------------------------------------------------
      test(
        'CONJUNCTION: overall status is failed iff at least one test failed',
        () {
          final held = forAll(
            (List<TestCaseResult> results) {
              final regression = reducer.reduce(results);
              final hasAnyFailure = results.any(
                (r) => r.outcome == TestOutcome.failed,
              );

              if (hasAnyFailure) {
                // Must be failed and blocked
                if (regression.overallStatus != TestOutcome.failed)
                  return false;
                if (!regression.releaseBlocked) return false;
              } else {
                // Must be passed and not blocked
                if (regression.overallStatus != TestOutcome.passed)
                  return false;
                if (regression.releaseBlocked) return false;
              }

              return true;
            },
            [_mixedGen],
            numRuns: kNumRuns,
          );
          expect(held, isTrue);
        },
      );

      // -----------------------------------------------------------------------
      // NOTIFICATION SET: failedTestIds equals exactly the set of failed test IDs
      // -----------------------------------------------------------------------
      test('failedTestIds equals exactly the set of failed test IDs', () {
        final held = forAll(
          (List<TestCaseResult> results) {
            final regression = reducer.reduce(results);

            // Compute expected failed IDs from the input
            final expectedFailedIds = results
                .where((r) => r.outcome == TestOutcome.failed)
                .map((r) => r.testId)
                .toSet();

            // failedTestIds must exactly match
            if (regression.failedTestIds.length != expectedFailedIds.length) {
              return false;
            }
            if (!regression.failedTestIds.containsAll(expectedFailedIds)) {
              return false;
            }

            return true;
          },
          [_mixedGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      });

      // -----------------------------------------------------------------------
      // EMPTY: empty result list → passed, not blocked (vacuous truth)
      // -----------------------------------------------------------------------
      test('empty result list → passed and not blocked (vacuous truth)', () {
        final regression = reducer.reduce([]);
        expect(regression.overallStatus, TestOutcome.passed);
        expect(regression.releaseBlocked, isFalse);
        expect(regression.failedTestIds, isEmpty);
      });
    },
  );
}
