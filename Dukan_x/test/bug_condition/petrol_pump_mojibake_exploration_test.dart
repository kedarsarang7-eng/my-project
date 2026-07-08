/// Bug Condition Exploration Test — bug.mojibake
///
/// **Validates: Requirements 1.12**
///
/// Property 12: Bug Condition — Correct Currency & Punctuation Glyphs
///
/// This test confirms that:
/// 1. `ShiftReportScreen` renders the proper Unicode rupee sign (U+20B9) in its
///    currency display strings, not the mojibake sequence (UTF-8 bytes of the
///    rupee sign misinterpreted as Latin-1/Windows-1252).
/// 2. `petrol_pump_business_rules.dart` doc comments contain the correct
///    Unicode punctuation glyphs (em-dash U+2014, multiplication sign U+00D7,
///    minus sign U+2212), not their mojibake byte sequences.
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - shift_report_screen.dart: uses mojibake 3-char sequence instead of
///     the proper rupee sign U+20B9.
///   - petrol_pump_business_rules.dart line 1: mojibake for em-dash U+2014
///   - petrol_pump_business_rules.dart line 32: mojibake for multiplication U+00D7
///   - petrol_pump_business_rules.dart line 45: mojibake for minus U+2212
///
/// After the fix this same test PASSES — all glyphs are the correct Unicode
/// code points with no mojibake byte sequences present.
///
/// Run: flutter test test/bug_condition/petrol_pump_mojibake_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // bug.mojibake / 1.12 / 2.12 — ShiftReportScreen & PetrolPumpBusinessRules
  //
  // Bug: Source files were saved with UTF-8 encoding but certain Unicode
  // characters were double-encoded or mis-encoded, producing visible mojibake
  // in the rendered UI and source comments.
  //
  // When Dart reads these files (which are UTF-8 on disk), the mojibake
  // characters appear as specific Unicode code point sequences:
  //
  //   Rupee (U+20B9) mojibake: U+00E2, U+201A, U+00B9
  //   Em-dash (U+2014) mojibake: U+00E2, U+20AC, U+201D
  //   Multiplication (U+00D7) mojibake: U+00C3, U+2014
  //   Minus (U+2212) mojibake: U+00E2, U+02C6, U+2019
  //
  // Expected (post-fix):
  //   - shift_report_screen.dart uses proper rupee sign (U+20B9)
  //   - petrol_pump_business_rules.dart uses proper em-dash, times, minus
  // ===========================================================================

  // Mojibake sequences as they appear when Dart reads the UTF-8 files:
  // These are the GARBLED character sequences.
  final mojibakeRupee = String.fromCharCodes([0x00E2, 0x201A, 0x00B9]);
  final mojibakeEmDash = String.fromCharCodes([0x00E2, 0x20AC, 0x201D]);
  final mojibakeTimes = String.fromCharCodes([0x00C3, 0x2014]);
  final mojibakeMinus = String.fromCharCodes([0x00E2, 0x02C6, 0x2019]);

  // Proper Unicode glyphs (what should be there after fix)
  final properRupee = String.fromCharCode(0x20B9); // Indian Rupee Sign
  final properEmDash = String.fromCharCode(0x2014); // Em Dash
  final properTimes = String.fromCharCode(0x00D7); // Multiplication Sign
  final properMinus = String.fromCharCode(0x2212); // Minus Sign

  group('Bug Condition 1.12 — bug.mojibake', () {
    late String shiftReportSrc;
    late String businessRulesSrc;

    setUpAll(() {
      shiftReportSrc = _readSource(
        'lib/features/petrol_pump/presentation/screens/reports/shift_report_screen.dart',
      );
      assert(shiftReportSrc.isNotEmpty, 'shift_report_screen.dart must exist');

      businessRulesSrc = _readSource(
        'lib/features/petrol_pump/utils/petrol_pump_business_rules.dart',
      );
      assert(
        businessRulesSrc.isNotEmpty,
        'petrol_pump_business_rules.dart must exist',
      );
    });

    // =========================================================================
    // Sub-Test 1: ShiftReportScreen must NOT contain the rupee mojibake
    // =========================================================================
    test('ShiftReportScreen does not contain rupee mojibake sequence', () {
      final hasMojibakeRupee = shiftReportSrc.contains(mojibakeRupee);

      // On FIXED code: hasMojibakeRupee == false (mojibake removed)
      // On UNFIXED code: hasMojibakeRupee == true (mojibake present)
      expect(
        hasMojibakeRupee,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.12): shift_report_screen.dart contains the '
            'mojibake byte sequence for the rupee sign (U+20B9).\n'
            'Characters found: U+00E2 U+201A U+00B9 (should be single U+20B9).\n\n'
            'The file uses garbled characters in currency strings:\n'
            '  Total Sales: garbled-chars + amount.toStringAsFixed(2)\n'
            '  Mini stat: garbled-chars + val.toStringAsFixed(0)\n\n'
            'Users see corrupted text instead of the rupee sign.\n'
            'The fix must replace the mojibake with the proper rupee sign (U+20B9).',
      );
    });

    // =========================================================================
    // Sub-Test 2: ShiftReportScreen must contain the PROPER rupee symbol
    // =========================================================================
    test('ShiftReportScreen contains proper rupee symbol (U+20B9)', () {
      final hasProperRupee = shiftReportSrc.contains(properRupee);

      // On FIXED code: hasProperRupee == true
      // On UNFIXED code: hasProperRupee == false (only mojibake present)
      expect(
        hasProperRupee,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.12): shift_report_screen.dart does not contain '
            'the proper Unicode rupee sign (U+20B9).\n'
            'The file only has the mojibake sequence where the rupee should be.\n\n'
            'After fix, the proper rupee sign must be present for currency display.\n'
            'Expected: string containing U+20B9 (Indian Rupee Sign).',
      );
    });

    // =========================================================================
    // Sub-Test 3: Business rules must NOT contain em-dash mojibake
    // =========================================================================
    test('Business rules does not contain em-dash mojibake sequence', () {
      final hasMojibakeEmDash = businessRulesSrc.contains(mojibakeEmDash);

      // On FIXED code: hasMojibakeEmDash == false
      // On UNFIXED code: hasMojibakeEmDash == true (line 1 comment)
      expect(
        hasMojibakeEmDash,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.12): petrol_pump_business_rules.dart contains '
            'the mojibake sequence for em-dash (U+2014).\n'
            'Characters found: U+00E2 U+20AC U+201D (should be single U+2014).\n\n'
            'Found on line 1:\n'
            '  // Petrol pump [mojibake] domain rules (clause 2.16 of bugfix.md).\n\n'
            'Should be:\n'
            '  // Petrol pump \u2014 domain rules (clause 2.16 of bugfix.md).\n\n'
            'The fix must replace the mojibake with the proper em-dash (U+2014).',
      );
    });

    // =========================================================================
    // Sub-Test 4: Business rules must NOT contain multiplication mojibake
    // =========================================================================
    test('Business rules does not contain multiplication sign mojibake sequence', () {
      final hasMojibakeTimes = businessRulesSrc.contains(mojibakeTimes);

      // On FIXED code: hasMojibakeTimes == false
      // On UNFIXED code: hasMojibakeTimes == true (saleValue comment)
      expect(
        hasMojibakeTimes,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.12): petrol_pump_business_rules.dart contains '
            'the mojibake sequence for multiplication sign (U+00D7).\n'
            'Characters found: U+00C3 U+2014 (should be single U+00D7).\n\n'
            'Found in saleValue doc comment:\n'
            '  /// Sale value for a nozzle = dispensedLitres [mojibake] pricePerLitre.\n\n'
            'Should be:\n'
            '  /// Sale value for a nozzle = dispensedLitres \u00D7 pricePerLitre.\n\n'
            'The fix must replace the mojibake with the proper multiplication sign (U+00D7).',
      );
    });

    // =========================================================================
    // Sub-Test 5: Business rules must NOT contain minus sign mojibake
    // =========================================================================
    test('Business rules does not contain minus sign mojibake sequence', () {
      final hasMojibakeMinus = businessRulesSrc.contains(mojibakeMinus);

      // On FIXED code: hasMojibakeMinus == false
      // On UNFIXED code: hasMojibakeMinus == true (cashVariance comment)
      expect(
        hasMojibakeMinus,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.12): petrol_pump_business_rules.dart contains '
            'the mojibake sequence for minus sign (U+2212).\n'
            'Characters found: U+00E2 U+02C6 U+2019 (should be single U+2212).\n\n'
            'Found in cashVariance doc comment:\n'
            '  /// Shift cash variance = expectedCash [mojibake] reportedCash.\n\n'
            'Should be:\n'
            '  /// Shift cash variance = expectedCash \u2212 reportedCash.\n\n'
            'The fix must replace the mojibake with the proper minus sign (U+2212).',
      );
    });

    // =========================================================================
    // Sub-Test 6: Comprehensive — no mojibake + all proper glyphs present
    // =========================================================================
    test(
      'Neither file contains any mojibake and all proper glyphs are present',
      () {
        // Check for mojibake presence (should all be false after fix)
        final rupeeClean = !shiftReportSrc.contains(mojibakeRupee);
        final emDashClean = !businessRulesSrc.contains(mojibakeEmDash);
        final timesClean = !businessRulesSrc.contains(mojibakeTimes);
        final minusClean = !businessRulesSrc.contains(mojibakeMinus);

        // Check for proper glyphs (should all be true after fix)
        final hasProperRupee = shiftReportSrc.contains(properRupee);
        final hasProperEmDash = businessRulesSrc.contains(
          'pump $properEmDash domain',
        );
        final hasProperTimes = businessRulesSrc.contains(
          'dispensedLitres $properTimes pricePerLitre',
        );
        final hasProperMinus = businessRulesSrc.contains(
          'expectedCash $properMinus reportedCash',
        );

        final allGood =
            rupeeClean &&
            emDashClean &&
            timesClean &&
            minusClean &&
            hasProperRupee &&
            hasProperEmDash &&
            hasProperTimes &&
            hasProperMinus;

        expect(
          allGood,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.12): Mojibake sequences still present or '
              'proper Unicode glyphs missing:\n\n'
              'shift_report_screen.dart:\n'
              '  Rupee mojibake absent: $rupeeClean\n'
              '  Proper rupee (U+20B9) present: $hasProperRupee\n\n'
              'petrol_pump_business_rules.dart:\n'
              '  Em-dash mojibake absent: $emDashClean\n'
              '  Proper em-dash (U+2014) in context: $hasProperEmDash\n'
              '  Times mojibake absent: $timesClean\n'
              '  Proper times (U+00D7) in context: $hasProperTimes\n'
              '  Minus mojibake absent: $minusClean\n'
              '  Proper minus (U+2212) in context: $hasProperMinus\n\n'
              'The fix must re-encode both files so the proper Unicode '
              'glyphs replace the mojibake sequences.',
        );
      },
    );
  });
}
