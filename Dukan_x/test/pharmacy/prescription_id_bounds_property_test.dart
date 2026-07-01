// ============================================================================
// TASK 4.4 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 10: Captured prescription
//          identifier bounds
// **Validates: Requirements 7.2**
// ============================================================================
//
// Property 10 (design.md — Correctness Properties):
//   "For any prescription identifier captured through the gate, it is accepted
//    and assigned to the bill exactly when its length is between 1 and 100
//    characters inclusive."
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The pure predicate under test is `PrescriptionId.accepts(String?)` /
//   `PrescriptionId.normalize(String?)`
//   (lib/features/pharmacy/utils/prescription_id.dart). This is exactly the
//   bound check that `BillCreationScreenV2._ensurePrescriptionForProduct`
//   applies to `PrescriptionGateResult.prescriptionId` before assigning it to
//   the bill: the captured id is trimmed, then accepted iff its length is in
//   the inclusive range [1, 100] (R7.2).
//
//   The predicate is checked against an INDEPENDENT ORACLE that restates the
//   acceptance criterion in plain code (no reuse of the production constants):
//
//     accepts(raw) := let t = raw.trim() in (1 <= t.length <= 100)
//
//   Two facets, matching the two halves of the property, are exercised:
//     (A) ACCEPTANCE — `accepts` agrees with the oracle for every candidate,
//         and `normalize` yields the trimmed id exactly when accepted and
//         `null` otherwise (so the screen assigns the id iff in bounds).
//     (B) ASSIGNMENT — a pure simulation of the screen's decision (mirroring
//         `_ensurePrescriptionForProduct`): the value assigned to the bill is
//         the trimmed candidate when in bounds, and the bill's prior
//         prescription id is left unchanged otherwise.
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard).
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//   `forAll` returns true when the property held for every run and throws a
//   shrinking counterexample otherwise.
//
// TEST-ONLY for the assertions; the bound predicate it pins is the production
// rule consumed by the POS.
//
// Run: flutter test test/pharmacy/prescription_id_bounds_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/utils/prescription_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

// ---------------------------------------------------------------------------
// Independent oracle (restates R7.2 without reusing production constants)
// ---------------------------------------------------------------------------

/// The acceptance criterion: after trimming, the identifier is accepted iff its
/// length is in the inclusive range [1, 100].
bool _oracleAccepts(String? raw) {
  final t = (raw ?? '').trim();
  return t.length >= 1 && t.length <= 100;
}

// ---------------------------------------------------------------------------
// Character pools
// ---------------------------------------------------------------------------

/// Visible characters a captured prescription id may contain (rx text / hash /
/// scan reference). Includes alphanumerics plus a few separators that survive
/// trimming, so interior length — not character class — drives the bound.
final List<String> _bodyChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-/.#'.split(
      '',
    );

/// Whitespace characters used for padding (stripped by `trim()`).
const List<String> _wsChars = <String>[' ', '\t', '\n', '  ', '   '];

// ---------------------------------------------------------------------------
// Generators — span just-below, at, and above both boundaries plus fuzz
// ---------------------------------------------------------------------------

/// A non-whitespace string of length 1..100 — always VALID after trim.
final Generator<String> _validGen = Gen.array<String>(
  Gen.elementOf<String>(_bodyChars),
  minLength: 1,
  maxLength: 100,
).map((cs) => cs.cast<String>().join());

/// A non-whitespace string of length 101..160 — always INVALID (too long).
final Generator<String> _tooLongGen = Gen.array<String>(
  Gen.elementOf<String>(_bodyChars),
  minLength: 101,
  maxLength: 160,
).map((cs) => cs.cast<String>().join());

/// A valid core (1..100) wrapped in surrounding whitespace — VALID after trim.
/// Exercises the trim contract (padding must not count toward the bound).
final Generator<String> _paddedValidGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.array<String>(
        Gen.elementOf<String>(_bodyChars),
        minLength: 1,
        maxLength: 100,
      ),
      Gen.elementOf<String>(_wsChars),
      Gen.elementOf<String>(_wsChars),
    ]).map((parts) {
      final core = (parts[0] as List).cast<String>().join();
      final lead = parts[1] as String;
      final trail = parts[2] as String;
      return '$lead$core$trail';
    });

/// Empty / whitespace-only strings — always INVALID (empty after trim).
final Generator<String> _emptyishGen = Gen.array<String>(
  Gen.elementOf<String>(_wsChars),
  minLength: 0,
  maxLength: 5,
).map((cs) => cs.cast<String>().join());

/// Arbitrary fuzz strings — the oracle decides; covers anything the structured
/// generators miss.
final Generator<String> _fuzzGen = Gen.string(minLength: 0, maxLength: 130);

/// A single candidate drawn uniformly from every generator above so the accept
/// and reject branches — and both boundaries — are heavily exercised.
final Generator<String> _candidateGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 4), // kind selector
      _validGen,
      _tooLongGen,
      _paddedValidGen,
      _emptyishGen,
      _fuzzGen,
    ]).map((parts) {
      final kind = parts[0] as int;
      switch (kind) {
        case 0:
          return parts[1] as String;
        case 1:
          return parts[2] as String;
        case 2:
          return parts[3] as String;
        case 3:
          return parts[4] as String;
        default:
          return parts[5] as String;
      }
    });

/// A prior prescription id already on the in-progress bill for the assignment
/// property: either a previously captured valid id or `null` (none yet).
final Generator<String?> _priorGen = Gen.tuple(<Generator<dynamic>>[
  Gen.interval(0, 1), // 0 => null prior, 1 => valid prior
  _validGen,
]).map((parts) => (parts[0] as int) == 0 ? null : parts[1] as String);

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 10: Captured '
      'prescription identifier bounds — Req 7.2', () {
    // ----------------------------------------------------------------------
    // (A) ACCEPTANCE: the bound predicate matches the acceptance oracle, and
    //     normalize yields the trimmed id exactly when accepted.
    // ----------------------------------------------------------------------
    test('Property 10a: accepts iff trimmed length is 1..100; normalize '
        'returns the trimmed id when accepted and null otherwise', () {
      final bool held = forAll(
        (String raw) {
          final expected = _oracleAccepts(raw);

          // The predicate must agree with the oracle.
          if (PrescriptionId.accepts(raw) != expected) return false;

          final normalized = PrescriptionId.normalize(raw);
          if (expected) {
            // Accepted: the trimmed identifier is what gets assigned (R7.2).
            if (normalized != raw.trim()) return false;
          } else {
            // Rejected: nothing to assign — the gate result is not used.
            if (normalized != null) return false;
          }
          return true;
        },
        [_candidateGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'A captured prescription identifier is accepted iff, after '
            'trimming, its length is between 1 and 100 inclusive; the assigned '
            'value is the trimmed identifier.',
      );
    });

    // ----------------------------------------------------------------------
    // (B) ASSIGNMENT: a pure simulation of the screen's decision — the bill's
    //     prescription id becomes the trimmed candidate iff in bounds, else
    //     the prior value is retained (mirrors _ensurePrescriptionForProduct).
    // ----------------------------------------------------------------------
    test('Property 10b: an in-bounds capture is assigned to the bill; an '
        'out-of-bounds capture leaves the prior prescription id unchanged', () {
      final bool held = forAll(
        (List<dynamic> args) {
          final prior = args[0] as String?;
          final captured = args[1] as String;

          // Mirror _ensurePrescriptionForProduct's decision:
          //   in bounds -> assign the trimmed id; out of bounds -> keep prior.
          final normalized = PrescriptionId.normalize(captured);
          final assigned = normalized ?? prior;

          // Independent expectation from the oracle.
          final expectedAssigned = _oracleAccepts(captured)
              ? captured.trim()
              : prior;

          return assigned == expectedAssigned;
        },
        [
          Gen.tuple(<Generator<dynamic>>[_priorGen, _candidateGen]),
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Only an in-bounds captured identifier is assigned to the bill; an '
            'out-of-bounds capture must leave the prior prescription id '
            'untouched.',
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin both length boundaries and the trim contract
    // so the property is demonstrably non-vacuous.
    // ----------------------------------------------------------------------
    test('Property 10 anchors: length boundaries and trim contract', () {
      // Length 1 (minimum) — accepted.
      expect(PrescriptionId.accepts('A'), isTrue);
      expect(PrescriptionId.normalize('A'), 'A');
      // Length 100 (maximum) — accepted.
      expect(PrescriptionId.accepts('A' * 100), isTrue);
      expect(PrescriptionId.normalize('A' * 100), 'A' * 100);
      // Length 101 (one over) — rejected.
      expect(PrescriptionId.accepts('A' * 101), isFalse);
      expect(PrescriptionId.normalize('A' * 101), isNull);
      // Empty — rejected.
      expect(PrescriptionId.accepts(''), isFalse);
      // Null — rejected.
      expect(PrescriptionId.accepts(null), isFalse);
      expect(PrescriptionId.normalize(null), isNull);
      // Whitespace-only — rejected (empty after trim).
      expect(PrescriptionId.accepts('     '), isFalse);
      // Surrounding whitespace trimmed, then accepted; value is trimmed.
      expect(PrescriptionId.normalize('  RX-12345  '), 'RX-12345');
      // A value that trims down to exactly 100 valid chars — accepted.
      expect(PrescriptionId.accepts(' ${'B' * 100} '), isTrue);
      // A value that trims down to 101 chars — rejected.
      expect(PrescriptionId.accepts(' ${'B' * 101} '), isFalse);
    });
  });
}
