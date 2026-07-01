// ============================================================================
// TASK 11.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 17: Drug License Number
//          validation
// **Validates: Requirements 14.1, 14.4**
// ============================================================================
//
// Property 17 (design.md — Correctness Properties):
//   "For any candidate Drug License Number string, it is accepted if and only
//    if it is alphanumeric with length between 1 and 50 inclusive; otherwise it
//    is rejected, the previously saved value is retained, and a length-
//    constraint error is indicated."
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The pure validator under test is `DrugLicense.validate(String?)`
//   (lib/features/pharmacy/utils/drug_license.dart). It trims the candidate,
//   then accepts it iff the trimmed value is non-empty, no longer than 50
//   characters, and entirely alphanumeric.
//
//   The property is checked against an INDEPENDENT ORACLE that restates the
//   acceptance criteria in plain code units (no reuse of the production regex):
//
//     accepts(raw) := let t = raw.trim() in
//                     t.length in [1, 50] AND every codeUnit of t is
//                     0-9 / A-Z / a-z.
//
//   Two surfaces are exercised, matching the two halves of the property:
//     (A) ACCEPTANCE — `validate` is valid iff the oracle accepts; on accept
//         the returned value is exactly the trimmed candidate with no error;
//         on reject the returned value is `null` (nothing to commit, so the
//         caller retains the prior value) and the error is exactly the
//         length-constraint message (R14.1, R14.4).
//     (B) RETENTION — a pure simulation of the service's save semantics
//         (mirroring `DrugLicenseService.setDrugLicenseNumber`): the value
//         stored after an attempted save equals the trimmed candidate when the
//         candidate is valid, and the UNCHANGED prior value otherwise. This
//         pins the "previously saved value is retained" clause (R14.4).
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard). `forAll` returns true
//   when the property held for every run and throws a shrinking counterexample
//   otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/drug_license_property17_validation_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/utils/drug_license.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

// ---------------------------------------------------------------------------
// Independent oracle (restates R14.1 in code units; no production regex reuse)
// ---------------------------------------------------------------------------

/// True iff [c] is an ASCII alphanumeric code unit (0-9, A-Z, a-z).
bool _isAsciiAlnum(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A); //  a-z

/// The acceptance-criteria definition: after trimming, the value is accepted
/// iff it is 1..50 characters long and entirely ASCII alphanumeric.
bool _oracleAccepts(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty || t.length > 50) return false;
  for (final c in t.codeUnits) {
    if (!_isAsciiAlnum(c)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Character pools
// ---------------------------------------------------------------------------

/// Alphanumeric characters — the only ones a valid value may contain.
final List<String> _alnumChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.split('');

/// Disallowed (non-alphanumeric) characters that survive trimming when placed
/// in the interior of a string, so they force rejection.
const List<String> _badInteriorChars = <String>[
  '-',
  '_',
  '/',
  '.',
  '@',
  '#',
  '!',
  '*',
  '+',
  '(',
  ')',
  '%',
  '&',
  'é',
  'ß',
  '√',
];

/// Whitespace characters used for padding (stripped by `trim()`).
const List<String> _wsChars = <String>[' ', '\t', '\n', '  ', '   '];

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// A purely alphanumeric string of length 1..50 — always VALID.
final Generator<String> _validGen = Gen.array<String>(
  Gen.elementOf<String>(_alnumChars),
  minLength: 1,
  maxLength: 50,
).map((cs) => cs.cast<String>().join());

/// A purely alphanumeric string of length 51..80 — always INVALID (too long).
final Generator<String> _tooLongGen = Gen.array<String>(
  Gen.elementOf<String>(_alnumChars),
  minLength: 51,
  maxLength: 80,
).map((cs) => cs.cast<String>().join());

/// An alphanumeric core (1..50) wrapped in surrounding whitespace — VALID
/// after trimming. Exercises the trim contract.
final Generator<String> _paddedValidGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.array<String>(
        Gen.elementOf<String>(_alnumChars),
        minLength: 1,
        maxLength: 50,
      ),
      Gen.elementOf<String>(_wsChars),
      Gen.elementOf<String>(_wsChars),
    ]).map((parts) {
      final core = (parts[0] as List).cast<String>().join();
      final lead = parts[1] as String;
      final trail = parts[2] as String;
      return '$lead$core$trail';
    });

/// An alphanumeric string with at least one disallowed interior character —
/// always INVALID (non-alphanumeric content).
final Generator<String> _badCharGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.array<String>(
        Gen.elementOf<String>(_alnumChars),
        minLength: 0,
        maxLength: 20,
      ),
      Gen.elementOf<String>(_badInteriorChars),
      Gen.array<String>(
        Gen.elementOf<String>(_alnumChars),
        minLength: 0,
        maxLength: 20,
      ),
    ]).map((parts) {
      final a = (parts[0] as List).cast<String>().join();
      final bad = parts[1] as String;
      final b = (parts[2] as List).cast<String>().join();
      return '$a$bad$b';
    });

/// Empty / whitespace-only strings — always INVALID (empty after trim).
final Generator<String> _emptyishGen = Gen.array<String>(
  Gen.elementOf<String>(_wsChars),
  minLength: 0,
  maxLength: 5,
).map((cs) => cs.cast<String>().join());

/// Arbitrary fuzz strings — the oracle decides; covers anything the structured
/// generators miss.
final Generator<String> _fuzzGen = Gen.string(minLength: 0, maxLength: 70);

/// A single candidate string drawn uniformly from every generator above so the
/// accept and reject branches are both heavily exercised.
final Generator<String> _candidateGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 5), // kind selector
      _validGen,
      _tooLongGen,
      _paddedValidGen,
      _badCharGen,
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
        case 4:
          return parts[5] as String;
        default:
          return parts[6] as String;
      }
    });

/// A prior stored value for the retention property: either a previously saved
/// valid value or `null` (none configured yet).
final Generator<String?> _priorGen = Gen.tuple(<Generator<dynamic>>[
  Gen.interval(0, 1), // 0 => null prior, 1 => valid prior
  _validGen,
]).map((parts) => (parts[0] as int) == 0 ? null : parts[1] as String);

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 17: Drug License '
      'Number validation — Req 14.1, 14.4', () {
    // ----------------------------------------------------------------------
    // (A) ACCEPTANCE: validate matches the acceptance-criteria oracle, and the
    //     accept/reject payloads obey R14.1 / R14.4.
    // ----------------------------------------------------------------------
    test('Property 17a: validate accepts iff alphanumeric & length 1..50; '
        'accept yields the trimmed value, reject yields no value + the '
        'length-constraint error', () {
      final bool held = forAll(
        (String raw) {
          final expected = _oracleAccepts(raw);
          final v = DrugLicense.validate(raw);

          // The predicate must agree with the oracle.
          if (v.isValid != expected) return false;
          // The convenience predicate must agree too.
          if (DrugLicense.isValid(raw) != expected) return false;

          if (v.isValid) {
            // Accepted: returns the trimmed candidate, no error (R14.1).
            if (v.value != raw.trim()) return false;
            if (v.error != null) return false;
          } else {
            // Rejected: nothing to commit (so the caller retains the prior
            // value) and a length-constraint error is indicated (R14.4).
            if (v.value != null) return false;
            if (v.error != DrugLicense.lengthConstraintMessage) return false;
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
            'A Drug License Number is valid iff, after trimming, it is 1..50 '
            'alphanumeric characters; invalid candidates carry no value and '
            'the length-constraint message.',
      );
    });

    // ----------------------------------------------------------------------
    // (B) RETENTION: a pure simulation of the save semantics — the stored
    //     value after an attempted save is the new value iff valid, else the
    //     unchanged prior value (R14.4 "the previously saved value is
    //     retained").
    // ----------------------------------------------------------------------
    test('Property 17b: an invalid save retains the prior value; a valid save '
        'replaces it with the trimmed candidate', () {
      final bool held = forAll(
        (List<dynamic> args) {
          final prior = args[0] as String?;
          final candidate = args[1] as String;

          // Mirror DrugLicenseService.setDrugLicenseNumber's decision:
          //   valid   -> store the trimmed value
          //   invalid -> leave the prior value unchanged.
          final v = DrugLicense.validate(candidate);
          final stored = v.isValid ? v.value : prior;

          // Independent expectation from the oracle.
          final expectedStored = _oracleAccepts(candidate)
              ? candidate.trim()
              : prior;

          return stored == expectedStored;
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
            'Rejecting an invalid Drug License Number must leave the prior '
            'value untouched; only a valid value replaces it.',
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin the length boundaries and the character
    // contract so the property is demonstrably non-vacuous.
    // ----------------------------------------------------------------------
    test('Property 17 anchors: length and character boundaries', () {
      // Length 1 (minimum) — accepted.
      expect(DrugLicense.validate('A').isValid, isTrue);
      // Length 50 (maximum) — accepted.
      expect(DrugLicense.validate('A' * 50).isValid, isTrue);
      // Length 51 (one over) — rejected.
      final over = DrugLicense.validate('A' * 51);
      expect(over.isValid, isFalse);
      expect(over.value, isNull);
      expect(over.error, DrugLicense.lengthConstraintMessage);
      // Empty — rejected.
      expect(DrugLicense.validate('').isValid, isFalse);
      // Null — rejected.
      expect(DrugLicense.validate(null).isValid, isFalse);
      // Whitespace-only — rejected (empty after trim).
      expect(DrugLicense.validate('    ').isValid, isFalse);
      // Surrounding whitespace trimmed, then accepted; value is trimmed.
      final padded = DrugLicense.validate('  MH20B123456  ');
      expect(padded.isValid, isTrue);
      expect(padded.value, 'MH20B123456');
      // Interior non-alphanumeric — rejected.
      expect(DrugLicense.validate('MH-20-B-123').isValid, isFalse);
      expect(DrugLicense.validate('AB 12').isValid, isFalse);
      // A 51-char value that trims down to 50 valid chars — accepted.
      expect(DrugLicense.validate(' ${'B' * 50} ').isValid, isTrue);
    });
  });
}
