import 'package:flutter_test/flutter_test.dart';

import 'regression_reducer.dart';

void main() {
  const reducer = RegressionReducer();

  group('RegressionReducer', () {
    test('all passing tests → passed, not blocked, empty failed set', () {
      final results = [
        const TestCaseResult(
          testId: 'T1',
          testName: 'test one',
          outcome: TestOutcome.passed,
        ),
        const TestCaseResult(
          testId: 'T2',
          testName: 'test two',
          outcome: TestOutcome.passed,
        ),
        const TestCaseResult(
          testId: 'T3',
          testName: 'test three',
          outcome: TestOutcome.passed,
        ),
      ];

      final result = reducer.reduce(results);

      expect(result.overallStatus, TestOutcome.passed);
      expect(result.releaseBlocked, isFalse);
      expect(result.failedTestIds, isEmpty);
    });

    test(
      'one failed test → failed, blocked, failed set contains that test',
      () {
        final results = [
          const TestCaseResult(
            testId: 'T1',
            testName: 'test one',
            outcome: TestOutcome.passed,
          ),
          const TestCaseResult(
            testId: 'T2',
            testName: 'test two',
            outcome: TestOutcome.failed,
          ),
          const TestCaseResult(
            testId: 'T3',
            testName: 'test three',
            outcome: TestOutcome.passed,
          ),
        ];

        final result = reducer.reduce(results);

        expect(result.overallStatus, TestOutcome.failed);
        expect(result.releaseBlocked, isTrue);
        expect(result.failedTestIds, equals({'T2'}));
      },
    );

    test(
      'multiple failed tests → failed set contains exactly the failed ones',
      () {
        final results = [
          const TestCaseResult(
            testId: 'T1',
            testName: 'test one',
            outcome: TestOutcome.failed,
          ),
          const TestCaseResult(
            testId: 'T2',
            testName: 'test two',
            outcome: TestOutcome.passed,
          ),
          const TestCaseResult(
            testId: 'T3',
            testName: 'test three',
            outcome: TestOutcome.failed,
          ),
        ];

        final result = reducer.reduce(results);

        expect(result.overallStatus, TestOutcome.failed);
        expect(result.releaseBlocked, isTrue);
        expect(result.failedTestIds, equals({'T1', 'T3'}));
      },
    );

    test('all failed → failed set contains all test IDs', () {
      final results = [
        const TestCaseResult(
          testId: 'T1',
          testName: 'test one',
          outcome: TestOutcome.failed,
        ),
        const TestCaseResult(
          testId: 'T2',
          testName: 'test two',
          outcome: TestOutcome.failed,
        ),
      ];

      final result = reducer.reduce(results);

      expect(result.overallStatus, TestOutcome.failed);
      expect(result.releaseBlocked, isTrue);
      expect(result.failedTestIds, equals({'T1', 'T2'}));
    });

    test('empty results → passed (vacuous truth), not blocked', () {
      final result = reducer.reduce([]);

      expect(result.overallStatus, TestOutcome.passed);
      expect(result.releaseBlocked, isFalse);
      expect(result.failedTestIds, isEmpty);
    });

    test('single passing test → passed', () {
      final results = [
        const TestCaseResult(
          testId: 'T1',
          testName: 'only test',
          outcome: TestOutcome.passed,
        ),
      ];

      final result = reducer.reduce(results);

      expect(result.overallStatus, TestOutcome.passed);
      expect(result.releaseBlocked, isFalse);
      expect(result.failedTestIds, isEmpty);
    });

    test('single failing test → failed', () {
      final results = [
        const TestCaseResult(
          testId: 'T1',
          testName: 'only test',
          outcome: TestOutcome.failed,
        ),
      ];

      final result = reducer.reduce(results);

      expect(result.overallStatus, TestOutcome.failed);
      expect(result.releaseBlocked, isTrue);
      expect(result.failedTestIds, equals({'T1'}));
    });
  });
}
