// Feature: comprehensive-test-certification, Property 12
// ============================================================================
// Task 7.3 — PROPERTY TEST
// **Validates: Requirements 10.1, 10.5**
// ============================================================================
// Property 12: Security gate is green only with zero failing cases across all
// five categories.
//
//   For any set of security case results across the five categories
//   (authentication bypass, role escalation, insecure local storage, API
//   authorization, license tamper), the Security Quality_Gate is green if and
//   only if no case failed; otherwise the gate fails and exactly one
//   release-blocking Defect is recorded per category containing a failing case,
//   naming the affected endpoint or case.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_12_security_gate_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../pbt/generators.dart';
import '../core/gate_reducer.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// All five security categories.
const List<SecurityCategory> _allCategories = SecurityCategory.values;

/// Generates a random SecurityCategory.
final Generator<SecurityCategory> _categoryGen =
    Gen.elementOf<SecurityCategory>(_allCategories);

/// Generates a random case name string.
final Generator<String> _caseNameGen = Gen.interval(
  1,
  9999,
).map((n) => 'case-${n.toString().padLeft(4, '0')}');

/// Generates a random endpoint string.
final Generator<String> _endpointGen = Gen.interval(
  1,
  999,
).map((n) => '/api/endpoint-$n');

/// Generates a list of SecurityCaseResults where ALL cases pass (no failures).
/// Produces 1–20 cases across random categories.
final Generator<List<SecurityCaseResult>> _allPassingCasesGen =
    Gen.tuple([
      Gen.interval(1, 20), // number of cases
      Gen.interval(0, 99999), // seed for category distribution
    ]).map((parts) {
      final int count = parts[0] as int;
      final int seed = parts[1] as int;
      final cases = <SecurityCaseResult>[];
      for (int i = 0; i < count; i++) {
        final catIdx = (seed + i * 7) % _allCategories.length;
        cases.add(
          SecurityCaseResult(
            category: _allCategories[catIdx],
            caseName: 'pass-case-${i + 1}',
            passed: true,
            endpoint: '/api/resource-${i + 1}',
          ),
        );
      }
      return cases;
    });

/// Generates a list of SecurityCaseResults where at least one case FAILS.
/// Ensures at least one failing case exists among 1–20 cases.
final Generator<List<SecurityCaseResult>> _withFailingCasesGen =
    Gen.tuple([
      Gen.interval(1, 20), // total number of cases
      Gen.interval(0, 4), // category index for the guaranteed failing case
      Gen.interval(0, 99999), // seed for other cases
      Gen.interval(1, 5), // number of additional failing cases (0 to 4 extra)
    ]).map((parts) {
      final int totalCount = parts[0] as int;
      final int failCatIdx = parts[1] as int;
      final int seed = parts[2] as int;
      final int extraFails = (parts[3] as int).clamp(0, totalCount - 1);

      final cases = <SecurityCaseResult>[];

      // Add the guaranteed failing case
      cases.add(
        SecurityCaseResult(
          category: _allCategories[failCatIdx],
          caseName: 'fail-case-guaranteed',
          passed: false,
          endpoint: '/api/vulnerable-endpoint',
        ),
      );

      // Fill remaining cases with a mix of passing and failing
      for (int i = 1; i < totalCount; i++) {
        final catIdx = (seed + i * 3) % _allCategories.length;
        final shouldFail = i <= extraFails;
        cases.add(
          SecurityCaseResult(
            category: _allCategories[catIdx],
            caseName: shouldFail ? 'fail-case-$i' : 'pass-case-$i',
            passed: !shouldFail,
            endpoint: '/api/endpoint-$i',
          ),
        );
      }
      return cases;
    });

// ============================================================================
// TESTS
// ============================================================================

void main() {
  group('Feature: comprehensive-test-certification, Property 12 '
      '(Security gate is green only with zero failing cases)', () {
    const reducer = GateStatusReducer();

    // -----------------------------------------------------------------------
    // FORWARD: All cases passed=true across all 5 categories → green
    // -----------------------------------------------------------------------
    test('FORWARD: gate is green when all security cases pass across all '
        'categories', () {
      final held = forAll(
        (List<SecurityCaseResult> cases) {
          final status = reducer.reduceSecurity(cases);

          // Every case passes → gate must be green
          if (status != GateStatus.green) return false;

          // No defects should be generated for all-passing cases
          final defects = reducer.securityDefects(cases);
          if (defects.isNotEmpty) return false;

          return true;
        },
        [_allPassingCasesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // REJECTION: Any case with passed=false → notGreen
    // -----------------------------------------------------------------------
    test('REJECTION: gate is notGreen when any security case fails', () {
      final held = forAll(
        (List<SecurityCaseResult> cases) {
          final status = reducer.reduceSecurity(cases);

          // At least one case fails → gate must be notGreen
          if (status != GateStatus.notGreen) return false;

          // Defects should be generated
          final defects = reducer.securityDefects(cases);
          if (defects.isEmpty) return false;

          return true;
        },
        [_withFailingCasesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // CONJUNCTION: green iff zero failing cases (bi-directional)
    // -----------------------------------------------------------------------
    test('gate status is the conjunction: green iff zero failing cases '
        'across all five categories', () {
      // Use a generator that produces a mix of all-pass and some-fail cases
      final mixedGen =
          Gen.tuple([
            Gen.interval(0, 1), // 0 = all pass, 1 = has failures
            Gen.interval(1, 15), // number of cases
            Gen.interval(0, 4), // category index for failure
            Gen.interval(0, 99999), // seed
          ]).map((parts) {
            final int mode = parts[0] as int;
            final int count = parts[1] as int;
            final int failCatIdx = parts[2] as int;
            final int seed = parts[3] as int;

            final cases = <SecurityCaseResult>[];
            for (int i = 0; i < count; i++) {
              final catIdx = (seed + i * 7) % _allCategories.length;
              cases.add(
                SecurityCaseResult(
                  category: _allCategories[catIdx],
                  caseName: 'case-$i',
                  passed: true,
                  endpoint: '/api/resource-$i',
                ),
              );
            }

            // If mode == 1, inject a failure
            if (mode == 1) {
              cases.add(
                SecurityCaseResult(
                  category: _allCategories[failCatIdx],
                  caseName: 'injected-fail',
                  passed: false,
                  endpoint: '/api/vulnerable-$failCatIdx',
                ),
              );
            }

            return cases;
          });

      final held = forAll(
        (List<SecurityCaseResult> cases) {
          final status = reducer.reduceSecurity(cases);
          final hasAnyFailure = cases.any((c) => !c.passed);

          // green iff zero failing cases
          if (hasAnyFailure) {
            return status == GateStatus.notGreen;
          } else {
            return status == GateStatus.green;
          }
        },
        [mixedGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // DEFECT GENERATION: exactly one defect per offending category
    // -----------------------------------------------------------------------
    test('exactly one defect is recorded per category with failing cases', () {
      final held = forAll(
        (List<SecurityCaseResult> cases) {
          final defects = reducer.securityDefects(cases);

          // Count distinct categories that have at least one failing case
          final failingCategories = <SecurityCategory>{};
          for (final c in cases) {
            if (!c.passed) failingCategories.add(c.category);
          }

          // Number of defects must equal number of offending categories
          if (defects.length != failingCategories.length) return false;

          // Each defect must correspond to one offending category
          final defectCategories = defects.map((d) => d.offendingItem).toSet();
          final expectedCategoryNames = failingCategories
              .map((c) => c.name)
              .toSet();
          if (defectCategories.length != expectedCategoryNames.length) {
            return false;
          }
          if (!defectCategories.containsAll(expectedCategoryNames)) {
            return false;
          }

          return true;
        },
        [_withFailingCasesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // EMPTY CASES: empty list → green (no failures exist)
    // -----------------------------------------------------------------------
    test('empty case list results in green gate (vacuously no failures)', () {
      final status = reducer.reduceSecurity([]);
      expect(status, GateStatus.green);

      final defects = reducer.securityDefects([]);
      expect(defects, isEmpty);
    });
  });
}
