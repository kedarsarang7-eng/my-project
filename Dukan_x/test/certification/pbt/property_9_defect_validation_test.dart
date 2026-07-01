// Feature: comprehensive-test-certification, Property 9
// ============================================================================
// Property 9: Defect-record validation accepts well-formed records and rejects
// malformed ones.
//
// For any candidate Defect record, the DefectValidator accepts it if and only
// if it has a non-empty id AND ≥1 repro step. Test both directions:
//   1. FORWARD: well-formed defects (non-empty id, ≥1 step) → accepted
//   2. REJECTION (empty id): mutate id to empty → rejected, errorField='id'
//   3. REJECTION (empty reproSteps): mutate to empty list → rejected,
//      errorField='reproSteps'
//
// **Validates: Requirements 7.1, 7.2, 7.3**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_9_defect_validation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../core/defect.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Generates a non-empty defect ID (e.g. "DEF-0001" through "DEF-9999").
final Generator<String> _defectIdGen = Gen.interval(
  1,
  9999,
).map((n) => 'DEF-${n.toString().padLeft(4, '0')}');

/// Generates a random Severity from the allowed set.
final Generator<Severity> _severityGen = Gen.elementOf<Severity>(
  Severity.values,
);

/// Generates a random ResolutionStatus from the allowed set.
final Generator<ResolutionStatus> _statusGen = Gen.elementOf<ResolutionStatus>(
  ResolutionStatus.values,
);

/// Generates a random GapCategory from the allowed set.
final Generator<GapCategory> _categoryGen = Gen.elementOf<GapCategory>(
  GapCategory.values,
);

/// Pool of realistic reproduction step descriptions.
const List<String> _reproStepPool = [
  'Open the billing screen',
  'Add an item to the cart',
  'Apply a discount coupon',
  'Click submit to generate invoice',
  'Navigate to reports section',
  'Observe the incorrect total',
  'Verify the ledger entry',
  'Check inventory stock count',
  'Toggle offline mode',
  'Attempt to sync data',
];

/// Generates a non-empty list of repro steps (1–5 steps).
final Generator<List<String>> _reproStepsGen =
    Gen.tuple([
      Gen.interval(1, 5), // number of steps
      Gen.interval(0, 9), // start index into pool
    ]).map((parts) {
      final int count = parts[0] as int;
      final int startIdx = parts[1] as int;
      return List<String>.generate(
        count,
        (i) => _reproStepPool[(startIdx + i) % _reproStepPool.length],
      );
    });

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const validator = DefectValidator();

  group('Property 9: Defect-record validation — accepts well-formed, '
      'rejects malformed', () {
    // ========================================================================
    // Direction 1: FORWARD — well-formed defects accepted
    // ========================================================================
    test('FORWARD: well-formed defects (non-empty id, ≥1 step) → accepted', () {
      final held = forAll(
        (
          String id,
          Severity severity,
          List<String> reproSteps,
          ResolutionStatus status,
          GapCategory category,
        ) {
          final defect = Defect(
            id: id,
            severity: severity,
            reproSteps: reproSteps,
            status: status,
            category: category,
          );

          final result = validator.validate(defect);

          // Must be accepted with no errorField
          return result.accepted == true && result.errorField == null;
        },
        [_defectIdGen, _severityGen, _reproStepsGen, _statusGen, _categoryGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 2: REJECTION — empty id → rejected with errorField='id'
    // ========================================================================
    test('REJECTION (empty id): mutate id to empty → rejected, '
        "errorField='id'", () {
      final held = forAll(
        (
          Severity severity,
          List<String> reproSteps,
          ResolutionStatus status,
          GapCategory category,
        ) {
          // Create a defect with an empty id (the mutation)
          final defect = Defect(
            id: '', // mutated to empty
            severity: severity,
            reproSteps: reproSteps,
            status: status,
            category: category,
          );

          final result = validator.validate(defect);

          // Must be rejected with errorField == 'id'
          return result.accepted == false && result.errorField == 'id';
        },
        [_severityGen, _reproStepsGen, _statusGen, _categoryGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 3: REJECTION — empty reproSteps → rejected with
    //              errorField='reproSteps'
    // ========================================================================
    test('REJECTION (empty reproSteps): mutate to empty list → rejected, '
        "errorField='reproSteps'", () {
      final held = forAll(
        (
          String id,
          Severity severity,
          ResolutionStatus status,
          GapCategory category,
        ) {
          // Create a defect with empty repro steps (the mutation)
          final defect = Defect(
            id: id,
            severity: severity,
            reproSteps: const [], // mutated to empty
            status: status,
            category: category,
          );

          final result = validator.validate(defect);

          // Must be rejected with errorField == 'reproSteps'
          return result.accepted == false && result.errorField == 'reproSteps';
        },
        [_defectIdGen, _severityGen, _statusGen, _categoryGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
