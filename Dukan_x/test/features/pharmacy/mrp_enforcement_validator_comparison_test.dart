// ============================================================================
// Feature: pharmacy-vertical-remediation — Task 3.3
// Example-based unit tests: MRP comparison cases for MrpEnforcementValidator.
// **Validates: Requirements 8.7**
// ============================================================================
//
// Requirement 8.7:
//   "THE System SHALL include unit tests for MRP_Validator covering the
//    price-equal-to-MRP case (accepted), the price-below-MRP case (accepted),
//    and the price-above-MRP case (rejected)."
//
// Under test:
//   MrpEnforcementValidator.isMrpCompliant(int sellingPaise, int? mrpPaise)
//   — returns true when selling price is at or below the MRP ceiling, false
//   when it strictly exceeds it. All comparisons are in integer paise.
//
// These are the explicit, example-based proofs mandated by Requirement 8.7
// (the companion Property 12 test exhaustively samples the comparison space):
//   * selling == mrp  -> true  (accepted, ceiling met exactly)
//   * selling <  mrp  -> true  (accepted, below ceiling)
//   * selling >  mrp  -> false (rejected, above ceiling)
// plus a couple of paise-level boundary cases either side of the ceiling.
//
// Run: flutter test test/features/pharmacy/mrp_enforcement_validator_comparison_test.dart
// ============================================================================

import 'package:dukanx/utils/mrp_enforcement_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Requirement 8.7: MRP comparison cases (isMrpCompliant)', () {
    test('price equal to MRP is accepted (compliant)', () {
      // Selling price exactly meets the MRP ceiling -> allowed.
      expect(MrpEnforcementValidator.isMrpCompliant(10000, 10000), isTrue);
    });

    test('price below MRP is accepted (compliant)', () {
      // Selling price under the MRP ceiling -> allowed.
      expect(MrpEnforcementValidator.isMrpCompliant(9999, 10000), isTrue);
    });

    test('price above MRP is rejected (non-compliant)', () {
      // Selling price strictly exceeds the MRP ceiling -> blocked.
      expect(MrpEnforcementValidator.isMrpCompliant(10001, 10000), isFalse);
    });

    test('one paise below the ceiling is accepted', () {
      // Boundary: the largest selling price still at/under MRP.
      expect(MrpEnforcementValidator.isMrpCompliant(49999, 50000), isTrue);
    });

    test('one paise above the ceiling is rejected', () {
      // Boundary: the smallest selling price that violates MRP.
      expect(MrpEnforcementValidator.isMrpCompliant(50001, 50000), isFalse);
    });
  });
}
