// Feature: comprehensive-test-certification, Property 15
// ============================================================================
// Property 15: Traceability coverage-gap flag tracks linked test cases
// (round-trip).
// **Validates: Requirements 13.3, 13.4**
// ============================================================================
// 1. A requirement entry is flagged isCoverageGap=true iff testCaseIds is empty
// 2. Adding a test case to a gap-flagged entry clears the gap
// 3. Removing the last test case re-introduces the gap
//
// Unit under test: `TraceabilityMatrix`, `TraceEntry`, `AddTestCase`,
// `RemoveTestCase` from `../core/traceability_matrix.dart`.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_15_coverage_gap_flag_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/traceability_matrix.dart';
import 'generators.dart';

void main() {
  group('Feature: comprehensive-test-certification, Property 15: '
      'Traceability coverage-gap flag tracks linked test cases (round-trip)', () {
    test(
      'Property 15a: A requirement entry with empty testCaseIds is flagged '
      'isCoverageGap=true, and with non-empty testCaseIds is flagged false',
      () {
        final held = forAll(
          (int reqSeed, int testCaseCount) {
            // Generate a requirement ID and a count of test cases [0, 5].
            final reqId = 'REQ-${reqSeed.abs() % 1000}';
            final count = testCaseCount.abs() % 6; // 0..5

            final testCaseIds = List.generate(
              count,
              (i) => 'TC-${reqSeed.abs() % 100}-$i',
            );

            final entry = TraceEntry(
              requirementId: reqId,
              testCaseIds: testCaseIds,
            );

            // isCoverageGap must be true iff testCaseIds is empty.
            return entry.isCoverageGap == testCaseIds.isEmpty;
          },
          [Gen.interval(0, 9999), Gen.interval(0, 100)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('Property 15b: Adding a test case to a gap-flagged entry clears '
        'the coverage gap', () {
      final held = forAll(
        (int reqSeed, int tcSeed) {
          // Create a gap-flagged entry (empty test cases).
          final reqId = 'REQ-${reqSeed.abs() % 1000}';
          final testCaseId = 'TC-${tcSeed.abs() % 10000}';

          final matrix = TraceabilityMatrix();
          // Apply AddTestCase to a new (empty) entry — entry auto-created.
          matrix.applyChange(
            AddTestCase(requirementId: reqId, testCaseId: testCaseId),
          );

          final entry = matrix.getEntry(reqId);
          if (entry == null) return false;

          // After adding a test case, the gap flag must be cleared.
          return entry.isCoverageGap == false &&
              entry.testCaseIds.contains(testCaseId);
        },
        [Gen.interval(0, 9999), Gen.interval(0, 9999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 15c: Removing the last test case re-introduces the '
        'coverage gap', () {
      final held = forAll(
        (int reqSeed, int tcSeed) {
          final reqId = 'REQ-${reqSeed.abs() % 1000}';
          final testCaseId = 'TC-${tcSeed.abs() % 10000}';

          final matrix = TraceabilityMatrix();

          // Add a single test case — no gap.
          matrix.applyChange(
            AddTestCase(requirementId: reqId, testCaseId: testCaseId),
          );
          final afterAdd = matrix.getEntry(reqId);
          if (afterAdd == null || afterAdd.isCoverageGap) return false;

          // Remove that test case — gap re-introduced.
          matrix.applyChange(
            RemoveTestCase(requirementId: reqId, testCaseId: testCaseId),
          );
          final afterRemove = matrix.getEntry(reqId);
          if (afterRemove == null) return false;

          return afterRemove.isCoverageGap == true &&
              afterRemove.testCaseIds.isEmpty;
        },
        [Gen.interval(0, 9999), Gen.interval(0, 9999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 15d: Round-trip — add N test cases then remove all, '
        'gap flag tracks correctly at each step', () {
      final held = forAll(
        (int reqSeed, int countSeed) {
          final reqId = 'REQ-${reqSeed.abs() % 1000}';
          // Add between 1 and 5 test cases.
          final n = (countSeed.abs() % 5) + 1;

          final matrix = TraceabilityMatrix();

          // Initially no entry exists; when created via first add it has no gap.
          final testCaseIds = List.generate(n, (i) => 'TC-$reqSeed-$i');

          // Add test cases one by one — gap should clear after first add.
          for (var i = 0; i < n; i++) {
            matrix.applyChange(
              AddTestCase(requirementId: reqId, testCaseId: testCaseIds[i]),
            );
            final entry = matrix.getEntry(reqId);
            if (entry == null || entry.isCoverageGap) return false;
          }

          // Remove all test cases one by one.
          for (var i = 0; i < n; i++) {
            matrix.applyChange(
              RemoveTestCase(requirementId: reqId, testCaseId: testCaseIds[i]),
            );
            final entry = matrix.getEntry(reqId);
            if (entry == null) return false;

            // Gap should only appear after the LAST removal.
            final isLast = i == n - 1;
            if (entry.isCoverageGap != isLast) return false;
          }

          return true;
        },
        [Gen.interval(0, 9999), Gen.interval(0, 100)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
