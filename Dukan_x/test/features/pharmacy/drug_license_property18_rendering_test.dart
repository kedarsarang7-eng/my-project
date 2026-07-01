// ============================================================================
// TASK 11.3 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 18: Drug License Number
//          rendering follows configuration
// **Validates: Requirements 14.2, 14.3**
// ============================================================================
//
// Property 18 (design.md — Correctness Properties):
//   "For any pharmacy invoice rendered to print/PDF, the Drug License Number
//    appears in the header if and only if a value is configured for the tenant,
//    and rendering completes without error when none is configured."
//
// HOW THIS IS PROVEN AS A PROPERTY:
//   The include/omit decision used by the print/PDF header is centralized in
//   the pure function `DrugLicense.headerLine(String?)`
//   (lib/features/pharmacy/utils/drug_license.dart). The header template in
//   `InvoicePdfWidgets.buildHeader` renders the Drug License line exactly when
//   `DrugLicense.headerLine(configured) != null`, using its returned text. So
//   property-testing this total, side-effect-free function is equivalent to
//   property-testing the rendering decision itself:
//
//     * a NON-NULL result  => the header includes the "D.L. No: <value>" line
//                             (R14.2 — value is configured);
//     * a NULL result      => the header omits the Drug License field and the
//                             export completes without error (R14.3 — none
//                             configured).
//
//   The property is checked against an INDEPENDENT ORACLE that restates R14.2 /
//   R14.3 in plain terms (no reuse of the production expression):
//
//     configured(c) := c != null AND c.isNotEmpty
//     appears(c)    := configured(c)              // R14.2 / R14.3 (iff)
//     line(c)       := configured(c) ? 'D.L. No: ' + c : null
//
//   "Completes without error" is demonstrated by the function being TOTAL: it
//   is invoked across every generated input (including null, empty, padded,
//   and arbitrary fuzz) and must return a defined value without throwing.
//
// PBT library: dartproptest (repo-wide standard). `forAll` returns true when
//   the property held for every run and throws a shrinking counterexample
//   otherwise.
//
// Run: flutter test test/features/pharmacy/drug_license_property18_rendering_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/pharmacy/utils/drug_license.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

// ---------------------------------------------------------------------------
// Independent oracle (restates R14.2 / R14.3; no production expression reuse)
// ---------------------------------------------------------------------------

/// A Drug License Number is "configured" iff it is non-null and non-empty.
bool _oracleConfigured(String? configured) =>
    configured != null && configured.isNotEmpty;

/// The expected header line: the labelled value when configured, else `null`
/// (the line is omitted).
String? _oracleLine(String? configured) =>
    _oracleConfigured(configured) ? 'D.L. No: $configured' : null;

// ---------------------------------------------------------------------------
// Generators — cover the "configured" and "absent" partitions plus fuzz.
// ---------------------------------------------------------------------------

final List<String> _alnumChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.split('');

/// A non-empty configured value (alphanumeric, 1..50) — always rendered.
final Generator<String> _configuredGen = Gen.array<String>(
  Gen.elementOf<String>(_alnumChars),
  minLength: 1,
  maxLength: 50,
).map((cs) => cs.cast<String>().join());

/// Arbitrary non-empty fuzz strings — still configured, so still rendered
/// verbatim (the renderer does not re-validate; it shows what is configured).
final Generator<String> _fuzzNonEmptyGen = Gen.string(
  minLength: 1,
  maxLength: 70,
);

/// Arbitrary fuzz that MAY be empty — exercises the boundary between
/// configured and absent.
final Generator<String> _fuzzAnyGen = Gen.string(minLength: 0, maxLength: 70);

/// A candidate configured value drawn from every generator above, plus the
/// explicit "absent" cases (`null` and the empty string), so both branches of
/// the iff are heavily exercised.
final Generator<String?> _candidateGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 4), // kind selector
      _configuredGen,
      _fuzzNonEmptyGen,
      _fuzzAnyGen,
    ]).map((parts) {
      final kind = parts[0] as int;
      switch (kind) {
        case 0:
          return parts[1] as String; // configured (clean)
        case 1:
          return parts[2] as String; // configured (fuzz, non-empty)
        case 2:
          return parts[3] as String; // any fuzz (maybe empty)
        case 3:
          return ''; // absent: empty string
        default:
          return null; // absent: not configured
      }
    });

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 18: Drug License '
      'Number rendering follows configuration — Req 14.2, 14.3', () {
    // ----------------------------------------------------------------------
    // The rendering decision appears iff configured, the rendered text is the
    // labelled value, and the function is total (never throws => "completes
    // without error").
    // ----------------------------------------------------------------------
    test('Property 18: the Drug License header line appears iff a value is '
        'configured; when absent it is omitted and rendering completes without '
        'error', () {
      final bool held = forAll(
        (String? configured) {
          // TOTAL / no-error: invoking the decision must not throw for any
          // input, including null and empty (R14.3 "without raising an error").
          final String? line = DrugLicense.headerLine(configured);

          final bool appears = line != null;
          final bool expectedAppears = _oracleConfigured(configured);

          // R14.2 / R14.3 — appears in the header IFF configured.
          if (appears != expectedAppears) return false;

          // The rendered content matches the labelled value exactly when
          // present, and is null (omitted) when absent.
          if (line != _oracleLine(configured)) return false;

          if (appears) {
            // R14.2 — the configured value is present in the header output.
            if (!line!.contains(configured!)) return false;
            if (!line.startsWith(DrugLicense.headerLabelPrefix)) return false;
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
            'The Drug License Number must be rendered in the invoice header '
            'exactly when a non-empty value is configured, and omitted (null) '
            'without error when none is configured.',
      );
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin the configured/absent boundary so the
    // property is demonstrably non-vacuous.
    // ----------------------------------------------------------------------
    test('Property 18 anchors: configured renders the labelled value; null and '
        'empty omit the line', () {
      // Configured -> labelled line containing the value (R14.2).
      expect(DrugLicense.headerLine('MH20B123456'), 'D.L. No: MH20B123456');
      expect(DrugLicense.headerLine('A'), 'D.L. No: A');

      // Absent -> omitted (null), no error (R14.3).
      expect(DrugLicense.headerLine(null), isNull);
      expect(DrugLicense.headerLine(''), isNull);

      // The rendered line always begins with the shared label prefix.
      final line = DrugLicense.headerLine('DL12345');
      expect(line, isNotNull);
      expect(line!.startsWith(DrugLicense.headerLabelPrefix), isTrue);
      expect(line.contains('DL12345'), isTrue);
    });
  });
}
