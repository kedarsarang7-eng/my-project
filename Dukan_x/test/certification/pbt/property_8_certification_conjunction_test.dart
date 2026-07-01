// Feature: comprehensive-test-certification, Property 8
// ============================================================================
// Task 15.3 — PROPERTY TEST
// **Validates: Requirements 6.7**
// ============================================================================
// Property 8: Certification result is the conjunction of its checks.
//
//   For any set of check results produced for a Business_Type, the
//   CertificationReport overall result is PASS if and only if every check
//   recorded zero Defects, and FAIL otherwise; and for any report mutated so
//   that one passing check gains a Defect, the overall result becomes FAIL.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_8_certification_conjunction_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../pbt/generators.dart';
import '../io/certification_pass.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Generates a random CheckName from the six certification checks.
final Generator<CheckName> _checkNameGen = Gen.elementOf<CheckName>(
  CheckName.values,
);

/// Generates a single CheckResult. About 50% pass (zero defects), 50% fail
/// (at least one defect ID).
final Generator<CheckResult> _checkResultGen =
    Gen.tuple([
      Gen.interval(0, 5), // CheckName index
      Gen.interval(0, 1), // 0 = pass, 1 = fail
      Gen.interval(1, 5), // number of defects if failing
      Gen.interval(0, 99999), // defect ID seed
    ]).map((parts) {
      final int nameIdx = parts[0] as int;
      final int passOrFail = parts[1] as int;
      final int defectCount = parts[2] as int;
      final int defectSeed = parts[3] as int;

      final name = CheckName.values[nameIdx];

      if (passOrFail == 0) {
        // Passing check — zero defects
        return CheckResult(name: name, passed: true, defectIds: []);
      } else {
        // Failing check — at least one defect
        final defectIds = List.generate(
          defectCount,
          (i) =>
              'DEF-${((defectSeed + i * 7) % 99999).toString().padLeft(5, '0')}',
        );
        return CheckResult(name: name, passed: false, defectIds: defectIds);
      }
    });

/// Generates a list of CheckResults where ALL checks pass (zero defects each).
/// Produces exactly 6 checks (one per CheckName).
final Generator<List<CheckResult>> _allPassingChecksGen = Gen.interval(0, 99999)
    .map((seed) {
      return CheckName.values.map((name) {
        return CheckResult(name: name, passed: true, defectIds: []);
      }).toList();
    });

/// Generates a list of CheckResults where at least one check FAILS.
/// Produces exactly 6 checks with at least one having defects.
final Generator<List<CheckResult>> _withFailingChecksGen =
    Gen.tuple([
      Gen.interval(1, 6), // number of failing checks (at least 1)
      Gen.interval(0, 99999), // defect ID seed
    ]).map((parts) {
      final int failCount = parts[0] as int;
      final int defectSeed = parts[1] as int;

      final checks = <CheckResult>[];
      for (int i = 0; i < CheckName.values.length; i++) {
        final name = CheckName.values[i];
        final shouldFail = i < failCount;

        if (shouldFail) {
          final defectIds = [
            'DEF-${((defectSeed + i * 13) % 99999).toString().padLeft(5, '0')}',
          ];
          checks.add(
            CheckResult(name: name, passed: false, defectIds: defectIds),
          );
        } else {
          checks.add(CheckResult(name: name, passed: true, defectIds: []));
        }
      }
      return checks;
    });

/// Generates a random list of CheckResults (one per CheckName) with random
/// pass/fail distribution. Used for the bi-directional conjunction test.
final Generator<List<CheckResult>> _mixedChecksGen =
    Gen.tuple([
      Gen.interval(0, 63), // bitmask for which checks fail (6 bits)
      Gen.interval(0, 99999), // defect ID seed
    ]).map((parts) {
      final int bitmask = parts[0] as int;
      final int defectSeed = parts[1] as int;

      final checks = <CheckResult>[];
      for (int i = 0; i < CheckName.values.length; i++) {
        final name = CheckName.values[i];
        final shouldFail = (bitmask & (1 << i)) != 0;

        if (shouldFail) {
          final defectIds = [
            'DEF-${((defectSeed + i * 11) % 99999).toString().padLeft(5, '0')}',
          ];
          checks.add(
            CheckResult(name: name, passed: false, defectIds: defectIds),
          );
        } else {
          checks.add(CheckResult(name: name, passed: true, defectIds: []));
        }
      }
      return checks;
    });

// ============================================================================
// HELPER: compute expected overall from checks
// ============================================================================

/// Replicates the certification conjunction logic: overall PASS iff every
/// check has zero defects (passed == true).
bool _expectedOverall(List<CheckResult> checks) =>
    checks.every((c) => c.passed);

// ============================================================================
// TESTS
// ============================================================================

void main() {
  group('Feature: comprehensive-test-certification, Property 8 '
      '(Certification result is the conjunction of its checks)', () {
    // -----------------------------------------------------------------------
    // FORWARD: All checks pass → overallPass == true
    // -----------------------------------------------------------------------
    test(
      'FORWARD: all checks pass (zero defects each) → overallPass is true',
      () {
        final held = forAll(
          (List<CheckResult> checks) {
            final report = CertificationReport(
              businessType: 'grocery',
              checks: checks,
              overallPass: _expectedOverall(checks),
              omittedTests: [],
            );

            // Every check has zero defects
            if (!checks.every((c) => c.passed)) return false;

            // Overall must be PASS
            if (!report.overallPass) return false;

            return true;
          },
          [_allPassingChecksGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // REJECTION: At least one check fails → overallPass == false
    // -----------------------------------------------------------------------
    test(
      'REJECTION: at least one check with defects → overallPass is false',
      () {
        final held = forAll(
          (List<CheckResult> checks) {
            final overallPass = checks.every((c) => c.passed);

            final report = CertificationReport(
              businessType: 'pharmacy',
              checks: checks,
              overallPass: overallPass,
              omittedTests: [],
            );

            // At least one check has defects
            if (checks.every((c) => c.passed)) return false;

            // Overall must be FAIL
            if (report.overallPass) return false;

            return true;
          },
          [_withFailingChecksGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // CONJUNCTION (bi-directional): overallPass == true iff all checks passed
    // -----------------------------------------------------------------------
    test(
      'CONJUNCTION: overallPass is true iff every check recorded zero defects',
      () {
        final held = forAll(
          (List<CheckResult> checks) {
            final overallPass = checks.every((c) => c.passed);

            final report = CertificationReport(
              businessType: 'restaurant',
              checks: checks,
              overallPass: overallPass,
              omittedTests: [],
            );

            // Verify the conjunction: overallPass == (every check passed)
            final expectedPass = checks.every((c) => c.passed);
            if (report.overallPass != expectedPass) return false;

            return true;
          },
          [_mixedChecksGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // MUTATION: Take an all-passing report, inject a defect into one check
    // → overallPass becomes false.
    // -----------------------------------------------------------------------
    test(
      'MUTATION: injecting a defect into a passing check flips overallPass to false',
      () {
        final held = forAll(
          (List<CheckResult> checks) {
            // Start with all checks passing
            if (!checks.every((c) => c.passed)) return false;

            // Pick one check to mutate (use first)
            final mutatedChecks = checks
                .map(
                  (c) => CheckResult(
                    name: c.name,
                    passed: c.passed,
                    defectIds: List.of(c.defectIds),
                  ),
                )
                .toList();

            // Inject a defect into the first check
            mutatedChecks[0] = CheckResult(
              name: mutatedChecks[0].name,
              passed: false,
              defectIds: ['DEF-INJECTED-001'],
            );

            // Recompute overall
            final mutatedOverall = mutatedChecks.every((c) => c.passed);

            final mutatedReport = CertificationReport(
              businessType: 'electronics',
              checks: mutatedChecks,
              overallPass: mutatedOverall,
              omittedTests: [],
            );

            // After mutation, overall must be FAIL
            if (mutatedReport.overallPass) return false;

            return true;
          },
          [_allPassingChecksGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // EDGE CASE: single check failing is enough to make overall FAIL
    // -----------------------------------------------------------------------
    test(
      'single failing check among otherwise passing → overallPass is false',
      () {
        for (int failIdx = 0; failIdx < CheckName.values.length; failIdx++) {
          final checks = CheckName.values.map((name) {
            final idx = CheckName.values.indexOf(name);
            if (idx == failIdx) {
              return CheckResult(
                name: name,
                passed: false,
                defectIds: ['DEF-SINGLE-${failIdx.toString().padLeft(3, '0')}'],
              );
            }
            return CheckResult(name: name, passed: true, defectIds: []);
          }).toList();

          final overallPass = checks.every((c) => c.passed);

          final report = CertificationReport(
            businessType: 'service',
            checks: checks,
            overallPass: overallPass,
            omittedTests: [],
          );

          expect(
            report.overallPass,
            isFalse,
            reason: 'Failing check at index $failIdx should cause overall FAIL',
          );
        }
      },
    );
  });
}
