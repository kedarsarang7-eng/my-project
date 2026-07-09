/// Bug Condition Exploration Test — bug.escapedErrorString
///
/// **Validates: Requirements 1.13**
///
/// Property 13: Bug Condition — Real Error Messages
///
/// This test confirms that:
/// 1. `AddTankDialog._submit` catch block uses proper string interpolation
///    `'Error: $e'` so the SnackBar displays the actual exception message.
/// 2. `DipReadingDialog._submit` catch block uses proper string interpolation
///    `'Error: $e'` so the SnackBar displays the actual exception message.
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - add_tank_dialog.dart: uses `'Error: \$e'` (escaped dollar sign),
///     producing the literal text "Error: $e" instead of the real exception.
///   - dip_reading_dialog.dart: uses `'Error: \$e'` (escaped dollar sign),
///     producing the literal text "Error: $e" instead of the real exception.
///
/// After the fix this same test PASSES — both dialogs use unescaped `$e`
/// so the actual exception message is shown to users.
///
/// Note: `add_stock_dialog.dart` already uses the correct `'Error: $e'`
/// (no backslash) and is NOT affected by this bug.
///
/// Run: flutter test test/bug_condition/petrol_pump_escaped_error_exploration_test.dart
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
  // bug.escapedErrorString / 1.13 / 2.13 — AddTankDialog & DipReadingDialog
  //
  // Bug: Both dialogs' catch blocks have:
  //   content: Text('Error: \$e'),
  //
  // The backslash escapes the $ sign, making it a LITERAL string "Error: $e"
  // shown to users regardless of what exception was thrown. The user never sees
  // the actual exception message.
  //
  // The correct code (as seen in add_stock_dialog.dart) uses:
  //   content: Text('Error: $e'),
  //
  // Without the backslash, Dart performs string interpolation and the actual
  // exception object's toString() is embedded in the message.
  //
  // Detection approach:
  //   Read the source of both dialog files and look for the escaped pattern
  //   `'Error: \$e'` in the catch blocks. If present, the bug exists.
  //   We assert that the escaped pattern must NOT be present (so the test
  //   FAILS on unfixed code where it IS present).
  // ===========================================================================

  // The escaped pattern that constitutes the bug.
  // In Dart source, the literal string `'Error: \$e'` is written as:
  //   Text('Error: \$e')
  // When we read the source file as a string, we see the actual characters:
  //   Error: \$e
  // So we search for the backslash-dollar sequence in the source text.
  final escapedPattern = r'Error: \$e';

  // The correct pattern (unescaped interpolation).
  // In the source file this appears literally as: Error: $e (no backslash).
  // We need a raw string to express what the correct source looks like:
  final correctPattern = r'Error: $e';

  group('Bug Condition 1.13 — bug.escapedErrorString', () {
    late String addTankSrc;
    late String dipReadingSrc;
    late String addStockSrc;

    setUpAll(() {
      addTankSrc = _readSource(
        'lib/features/petrol_pump/presentation/dialogs/add_tank_dialog.dart',
      );
      assert(addTankSrc.isNotEmpty, 'add_tank_dialog.dart must exist');

      dipReadingSrc = _readSource(
        'lib/features/petrol_pump/presentation/dialogs/dip_reading_dialog.dart',
      );
      assert(dipReadingSrc.isNotEmpty, 'dip_reading_dialog.dart must exist');

      addStockSrc = _readSource(
        'lib/features/petrol_pump/presentation/dialogs/add_stock_dialog.dart',
      );
      assert(addStockSrc.isNotEmpty, 'add_stock_dialog.dart must exist');
    });

    // =========================================================================
    // Sub-Test 1: AddTankDialog must NOT contain the escaped error pattern
    // =========================================================================
    test('AddTankDialog catch block does not use escaped error string', () {
      final hasEscaped = addTankSrc.contains(escapedPattern);

      // On FIXED code: hasEscaped == false (backslash removed)
      // On UNFIXED code: hasEscaped == true (backslash present — bug)
      expect(
        hasEscaped,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.13): add_tank_dialog.dart contains the escaped '
            'error pattern `Text(\'Error: \\\$e\')` in its catch block.\n\n'
            'This means the SnackBar always displays the literal text '
            '"Error: \$e" regardless of what exception was thrown.\n'
            'Users never see the actual exception message.\n\n'
            'The fix must remove the backslash so Dart interpolates the '
            'exception:\n'
            '  Before: Text(\'Error: \\\$e\')\n'
            '  After:  Text(\'Error: \$e\')\n\n'
            'Reference: add_stock_dialog.dart already uses the correct pattern.',
      );
    });

    // =========================================================================
    // Sub-Test 2: AddTankDialog MUST contain the correct interpolation pattern
    // =========================================================================
    test('AddTankDialog catch block uses proper string interpolation', () {
      // We need to check that the source contains `Error: $e` WITHOUT a
      // preceding backslash. Since the escaped version also contains `Error: $e`
      // as a substring (after the backslash), we verify it's NOT preceded by \.
      //
      // Strategy: check that correctPattern is present AND escapedPattern is NOT.
      final hasCorrect = addTankSrc.contains(correctPattern);
      final hasEscaped = addTankSrc.contains(escapedPattern);

      // On FIXED code: hasCorrect == true, hasEscaped == false
      // On UNFIXED code: hasCorrect == true (substring match), hasEscaped == true
      // So the real signal is that escapedPattern must be absent.
      expect(
        hasCorrect && !hasEscaped,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.13): add_tank_dialog.dart does not have proper '
            'unescaped error interpolation `Text(\'Error: \$e\')` or still '
            'contains the escaped variant.\n\n'
            'After fix, the catch block must use:\n'
            '  content: Text(\'Error: \$e\'),\n'
            'so the actual exception message is displayed to users.',
      );
    });

    // =========================================================================
    // Sub-Test 3: DipReadingDialog must NOT contain the escaped error pattern
    // =========================================================================
    test('DipReadingDialog catch block does not use escaped error string', () {
      final hasEscaped = dipReadingSrc.contains(escapedPattern);

      // On FIXED code: hasEscaped == false (backslash removed)
      // On UNFIXED code: hasEscaped == true (backslash present — bug)
      expect(
        hasEscaped,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.13): dip_reading_dialog.dart contains the '
            'escaped error pattern `Text(\'Error: \\\$e\')` in its catch block.\n\n'
            'This means the SnackBar always displays the literal text '
            '"Error: \$e" regardless of what exception was thrown.\n'
            'Users never see the actual exception message.\n\n'
            'The fix must remove the backslash so Dart interpolates the '
            'exception:\n'
            '  Before: Text(\'Error: \\\$e\')\n'
            '  After:  Text(\'Error: \$e\')\n\n'
            'Reference: add_stock_dialog.dart already uses the correct pattern.',
      );
    });

    // =========================================================================
    // Sub-Test 4: DipReadingDialog MUST contain the correct interpolation
    // =========================================================================
    test('DipReadingDialog catch block uses proper string interpolation', () {
      final hasCorrect = dipReadingSrc.contains(correctPattern);
      final hasEscaped = dipReadingSrc.contains(escapedPattern);

      // On FIXED code: hasCorrect == true, hasEscaped == false
      // On UNFIXED code: hasCorrect == true (substring), hasEscaped == true
      expect(
        hasCorrect && !hasEscaped,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.13): dip_reading_dialog.dart does not have '
            'proper unescaped error interpolation `Text(\'Error: \$e\')` or '
            'still contains the escaped variant.\n\n'
            'After fix, the catch block must use:\n'
            '  content: Text(\'Error: \$e\'),\n'
            'so the actual exception message is displayed to users.',
      );
    });

    // =========================================================================
    // Sub-Test 5: add_stock_dialog.dart is already correct (sanity check)
    // =========================================================================
    test(
      'add_stock_dialog.dart already uses correct interpolation (control)',
      () {
        final hasEscaped = addStockSrc.contains(escapedPattern);
        final hasCorrect = addStockSrc.contains(correctPattern);

        // add_stock_dialog.dart should NOT have the escaped pattern and SHOULD
        // have the correct pattern. This is our control — it confirms the test
        // logic is valid by checking a file we know is correct.
        expect(
          hasCorrect && !hasEscaped,
          isTrue,
          reason:
              'SANITY CHECK FAILED: add_stock_dialog.dart was expected to use '
              'the correct unescaped pattern `Text(\'Error: \$e\')` but does not.\n'
              'This control test validates our detection logic is working.',
        );
      },
    );

    // =========================================================================
    // Sub-Test 6: Comprehensive — both files must be bug-free
    // =========================================================================
    test(
      'Both AddTankDialog and DipReadingDialog are free of escaped error bug',
      () {
        final addTankClean = !addTankSrc.contains(escapedPattern);
        final dipReadingClean = !dipReadingSrc.contains(escapedPattern);
        final addTankHasCorrect =
            addTankSrc.contains(correctPattern) && addTankClean;
        final dipReadingHasCorrect =
            dipReadingSrc.contains(correctPattern) && dipReadingClean;

        final allFixed =
            addTankClean &&
            dipReadingClean &&
            addTankHasCorrect &&
            dipReadingHasCorrect;

        expect(
          allFixed,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.13): Escaped error string bug still present:\n\n'
              'add_tank_dialog.dart:\n'
              '  Escaped pattern absent: $addTankClean\n'
              '  Correct interpolation present: $addTankHasCorrect\n\n'
              'dip_reading_dialog.dart:\n'
              '  Escaped pattern absent: $dipReadingClean\n'
              '  Correct interpolation present: $dipReadingHasCorrect\n\n'
              'Both files must use `Text(\'Error: \$e\')` (unescaped) so users '
              'see actual exception messages in the SnackBar, not the literal '
              'text "Error: \$e".\n\n'
              'Reference: add_stock_dialog.dart already does this correctly.',
        );
      },
    );
  });
}
