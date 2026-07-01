// ============================================================================
// TASK 1.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 4: Currency display derives
//          from paise
// **Validates: Requirements 2.3**
// ============================================================================
//
// Property 4 (design.md — Correctness Properties):
//   "For any integer paise value, the displayed currency amount equals that
//    value divided by 100 rendered with exactly two decimal places."
//
// HOW THIS IS PROVEN AS A PROPERTY (independent round-trip oracle):
//   Rather than re-deriving the production format string, this test asserts the
//   two observable contracts of `Paise.toDisplay`:
//     (1) FORMAT: the output matches `^-?\d+\.\d\d$` — a rupee part, a literal
//         dot, and EXACTLY two decimal digits (Requirement 2.3).
//     (2) VALUE:  parsing the output back into paise (sign × (rupees·100 +
//         fraction), reconstructed with pure integer arithmetic) returns the
//         ORIGINAL paise value — i.e. the display is exactly value / 100.
//   The reconstruction never calls `toDisplay`, so a regression (wrong decimal
//   count, dropped sign, truncation instead of /100, locale separators) breaks
//   either the regex or the round-trip.
//
// PBT library: dartproptest ^0.2.1 (glados is unresolvable here — see the
//   dev_dependency note in pubspec.yaml). `forAll((a) => <bool>, [genA],
//   numRuns: N)` runs N generated cases and returns whether the predicate held
//   for all of them (throwing a shrinking counterexample otherwise).
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/paise_property4_display_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/pharmacy/paise.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the repo convention.
const int kNumRuns = 200;

/// Exactly two decimals, optional leading minus sign, no thousands separators.
final RegExp _twoDecimalRupees = RegExp(r'^-?\d+\.\d\d$');

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 4: Currency display '
      'derives from paise — Req 2.3', () {
    // Integer paise spanning negative (returns/credit notes) through large
    // positive amounts (up to ₹10,000,000), comfortably within double-exact
    // integer range for the round-trip reconstruction.
    final Generator<int> paiseGen = Gen.interval(-1000000000, 1000000000);

    test('Property 4: toDisplay renders any integer paise as value/100 with '
        'exactly two decimal places (format + round-trip value)', () {
      final bool held = forAll(
        (int paise) {
          final String display = Paise.toDisplay(paise);

          // (1) FORMAT: exactly two decimal places, optional sign.
          if (!_twoDecimalRupees.hasMatch(display)) return false;

          // (2) VALUE: reconstruct paise from the rendered string with pure
          //     integer arithmetic and require it to equal the original.
          final bool isNegative = display.startsWith('-');
          final String magnitude = isNegative ? display.substring(1) : display;
          final List<String> parts = magnitude.split('.');
          final int rupeePart = int.parse(parts[0]);
          final int fractionPart = int.parse(parts[1]);
          final int reconstructed = rupeePart * 100 + fractionPart;
          final int signed = isNegative ? -reconstructed : reconstructed;

          return signed == paise;
        },
        [paiseGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'toDisplay must render integer paise as rupees with exactly '
            'two decimals equal to paise / 100.',
      );
    });

    // Deterministic anchors — pin exact rendering incl. zero-padding and sign.
    test('Property 4 anchors: zero-padding, sign, and boundaries', () {
      expect(Paise.toDisplay(0), '0.00');
      expect(Paise.toDisplay(5), '0.05');
      expect(Paise.toDisplay(99), '0.99');
      expect(Paise.toDisplay(100), '1.00');
      expect(Paise.toDisplay(150), '1.50');
      expect(Paise.toDisplay(-5), '-0.05');
      expect(Paise.toDisplay(-150), '-1.50');
      expect(Paise.toDisplay(1234567), '12345.67');
    });
  });
}
