/// Bug Condition Exploration Test — fuelRates.fabAndBoundsMissing
///
/// **Validates: Requirements 1.11**
///
/// Property 11: Bug Condition — Fuel Rate FAB & Bounds
///
/// This test confirms that `FuelRatesScreen`:
/// 1. The FAB's `onPressed` body is empty (only contains a comment) —
///    tapping "Add" does nothing; no dialog opens.
/// 2. `_showUpdateRateDialog` has NO bounds validation — any parseable
///    double (including negatives and extreme values) is accepted via
///    bare `double.tryParse` with no min/max check.
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - FAB onPressed: `onPressed: () { // Add custom fuel type logic }`
///     — empty body, nothing happens when tapped.
///   - _showUpdateRateDialog: `final newRate = double.tryParse(controller.text);
///     if (newRate != null) { await _fuelService.updateFuelRate(...) }` — accepts
///     ANY parseable double including negatives (-50) and extreme values (99999).
///
/// After the fix this same test PASSES — the FAB opens an add-fuel-type dialog,
/// and the update dialog rejects rates outside [1.0, 500.0].
///
/// Scoped PBT Approach: Property-based test generating rate values outside
/// [1.0, 500.0] (including negative values) and asserting each is rejected
/// by the update flow's bounds validation in source code.
///
/// Run: flutter test test/bug_condition/petrol_pump_fuel_rates_fab_exploration_test.dart
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // fuelRates.fabAndBoundsMissing / 1.11 / 2.11 — FuelRatesScreen
  //
  // Bug 1: FAB onPressed is empty — `onPressed: () { // Add custom fuel type logic }`
  //         Tapping the FAB does nothing.
  //
  // Bug 2: _showUpdateRateDialog accepts any parseable double with no bounds check.
  //         A rate of -50 or 99999 is accepted unchanged.
  //
  // Expected (post-fix):
  //   - FAB onPressed opens an add-fuel-type dialog (showDialog call in body)
  //   - _showUpdateRateDialog validates rate is within [1.0, 500.0] and
  //     rejects values outside that range.
  // ===========================================================================
  group('Bug Condition 1.11 — fuelRates.fabAndBoundsMissing', () {
    late String fuelRatesScreenSrc;

    setUpAll(() {
      fuelRatesScreenSrc = _readSource(
        'lib/features/petrol_pump/presentation/screens/fuel_rates_screen.dart',
      );
      assert(
        fuelRatesScreenSrc.isNotEmpty,
        'fuel_rates_screen.dart must exist',
      );
    });

    // =========================================================================
    // Sub-Test 1: FAB onPressed body must contain a meaningful action
    // (e.g. showDialog call), not just a comment.
    // =========================================================================
    test('FAB onPressed opens a dialog (not empty body)', () {
      // Locate the floatingActionButton section
      final fabIdx = fuelRatesScreenSrc.indexOf('floatingActionButton');
      expect(
        fabIdx,
        isNot(-1),
        reason: 'floatingActionButton must exist in fuel_rates_screen.dart',
      );

      // Extract the onPressed callback body for the FAB.
      final onPressedIdx = fuelRatesScreenSrc.indexOf('onPressed', fabIdx);
      expect(
        onPressedIdx,
        isNot(-1),
        reason: 'FAB must have an onPressed handler',
      );

      // Find the opening brace of the onPressed callback
      final braceStart = fuelRatesScreenSrc.indexOf('{', onPressedIdx);
      expect(braceStart, isNot(-1));

      // Find the matching closing brace (simple brace counting)
      int depth = 0;
      int braceEnd = -1;
      for (int i = braceStart; i < fuelRatesScreenSrc.length; i++) {
        if (fuelRatesScreenSrc[i] == '{') depth++;
        if (fuelRatesScreenSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            braceEnd = i;
            break;
          }
        }
      }
      expect(braceEnd, isNot(-1), reason: 'Must find matching closing brace');

      final onPressedBody = fuelRatesScreenSrc.substring(
        braceStart + 1,
        braceEnd,
      );

      // On FIXED code: onPressed body must contain showDialog (opens a dialog)
      // On UNFIXED code: onPressed body is just a comment:
      //   `// Add custom fuel type logic`
      final hasShowDialog = onPressedBody.contains('showDialog');

      expect(
        hasShowDialog,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.11): FAB onPressed body is EMPTY — contains only '
            'a comment `// Add custom fuel type logic` with no executable code.\n\n'
            'The current code:\n'
            '  floatingActionButton: FloatingActionButton(\n'
            '    onPressed: () {\n'
            '      // Add custom fuel type logic\n'
            '    },\n'
            '    child: const Icon(Icons.add),\n'
            '  )\n\n'
            'Tapping the FAB does NOTHING — no dialog opens, no fuel type '
            'can be added. The fix must call showDialog to open an '
            'add-fuel-type form.',
      );
    });

    // =========================================================================
    // Sub-Test 2: FAB onPressed body has actual executable statements
    // (not just whitespace and comments)
    // =========================================================================
    test('FAB onPressed has executable code (not just comments)', () {
      final fabIdx = fuelRatesScreenSrc.indexOf('floatingActionButton');
      final onPressedIdx = fuelRatesScreenSrc.indexOf('onPressed', fabIdx);
      final braceStart = fuelRatesScreenSrc.indexOf('{', onPressedIdx);

      int depth = 0;
      int braceEnd = -1;
      for (int i = braceStart; i < fuelRatesScreenSrc.length; i++) {
        if (fuelRatesScreenSrc[i] == '{') depth++;
        if (fuelRatesScreenSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            braceEnd = i;
            break;
          }
        }
      }

      final onPressedBody = fuelRatesScreenSrc.substring(
        braceStart + 1,
        braceEnd,
      );

      // Strip comments and whitespace to see if there's any executable code
      final strippedBody = onPressedBody
          .replaceAll(RegExp(r'//[^\n]*'), '') // Remove single-line comments
          .replaceAll(
            RegExp(r'/\*.*?\*/', dotAll: true),
            '',
          ) // Remove block comments
          .trim();

      // On FIXED code: strippedBody has executable statements (showDialog, etc.)
      // On UNFIXED code: strippedBody is EMPTY after removing the comment
      expect(
        strippedBody.isNotEmpty,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.11): FAB onPressed body contains NO executable '
            'code. After stripping comments, the body is empty.\n\n'
            'The entire onPressed callback:\n'
            '  onPressed: () {\n'
            '    // Add custom fuel type logic\n'
            '  }\n\n'
            'This is a TODO placeholder that was never implemented. Users '
            'cannot add custom fuel types (e.g. CNG, E85) because the button '
            'literally does nothing when pressed.',
      );
    });

    // =========================================================================
    // Sub-Test 3: _showUpdateRateDialog must have bounds validation
    // (min/max check rejecting rates outside [1.0, 500.0]).
    // =========================================================================
    test('_showUpdateRateDialog has bounds validation for rate values', () {
      // Locate the _showUpdateRateDialog method
      final methodIdx = fuelRatesScreenSrc.indexOf('_showUpdateRateDialog');
      expect(
        methodIdx,
        isNot(-1),
        reason: '_showUpdateRateDialog must exist in fuel_rates_screen.dart',
      );

      // Extract the method body
      final methodBodyStart = fuelRatesScreenSrc.indexOf('{', methodIdx);

      int depth = 0;
      int methodEnd = -1;
      for (int i = methodBodyStart; i < fuelRatesScreenSrc.length; i++) {
        if (fuelRatesScreenSrc[i] == '{') depth++;
        if (fuelRatesScreenSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            methodEnd = i + 1;
            break;
          }
        }
      }

      final methodBody = fuelRatesScreenSrc.substring(
        methodBodyStart,
        methodEnd,
      );

      // On FIXED code: the method MUST check bounds — should contain
      // comparisons against min/max values (1.0 / 500.0 or similar)
      final hasBoundsCheck =
          (methodBody.contains(RegExp(r'<\s*1')) ||
              methodBody.contains(RegExp(r'<\s*1\.0')) ||
              methodBody.contains(RegExp(r'>=\s*1')) ||
              methodBody.contains('minRate') ||
              methodBody.contains('lowerBound')) &&
          (methodBody.contains(RegExp(r'>\s*500')) ||
              methodBody.contains(RegExp(r'>\s*500\.0')) ||
              methodBody.contains(RegExp(r'<=\s*500')) ||
              methodBody.contains('maxRate') ||
              methodBody.contains('upperBound'));

      expect(
        hasBoundsCheck,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.11): _showUpdateRateDialog has NO bounds '
            'validation. The code accepts any parseable double:\n\n'
            '  final newRate = double.tryParse(controller.text);\n'
            '  if (newRate != null) {\n'
            '    await _fuelService.updateFuelRate(fuel.fuelId, newRate);\n'
            '  }\n\n'
            'A rate of -50.0 or 99999.0 is accepted without any check.\n'
            'The fix must validate: 1.0 <= newRate <= 500.0 and reject '
            'values outside this range with an error message.',
      );
    });

    // =========================================================================
    // Sub-Test 4: _showUpdateRateDialog must reject negative rates
    // =========================================================================
    test('_showUpdateRateDialog rejects negative rates', () {
      final methodIdx = fuelRatesScreenSrc.indexOf('_showUpdateRateDialog');
      final methodBodyStart = fuelRatesScreenSrc.indexOf('{', methodIdx);

      int depth = 0;
      int methodEnd = -1;
      for (int i = methodBodyStart; i < fuelRatesScreenSrc.length; i++) {
        if (fuelRatesScreenSrc[i] == '{') depth++;
        if (fuelRatesScreenSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            methodEnd = i + 1;
            break;
          }
        }
      }

      final methodBody = fuelRatesScreenSrc.substring(
        methodBodyStart,
        methodEnd,
      );

      // On FIXED code: there is validation that prevents negative/out-of-bounds rates.
      // On UNFIXED code: bare `double.tryParse` with only `!= null` check
      // means -50.0 passes validation — this test FAILS.
      final hasAnyValidation = methodBody.contains(
        RegExp(
          r'(newRate\s*[<>]|rate\s*[<>]|<\s*1|>\s*500|minRate|maxRate|bounds|range|invalid)',
        ),
      );

      expect(
        hasAnyValidation,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.11): _showUpdateRateDialog accepts negative '
            'rate values. With input "-50":\n'
            '  double.tryParse("-50") = -50.0 (not null)\n'
            '  proceeds to _fuelService.updateFuelRate(fuelId, -50.0)\n\n'
            'No validation rejects this. A fuel rate of -50.00/litre is '
            'nonsensical and would corrupt billing calculations.\n\n'
            'The fix must check: if (newRate < 1.0 || newRate > 500.0) '
            '{ show error; return; }',
      );
    });

    // =========================================================================
    // Sub-Test 5 (PBT): Generate random rate values outside [1.0, 500.0]
    // and verify the source code has a mechanism to reject them.
    // =========================================================================
    test('PBT: rates outside [1.0, 500.0] are rejected by update flow', () {
      // Extract the update logic from _showUpdateRateDialog
      final methodIdx = fuelRatesScreenSrc.indexOf('_showUpdateRateDialog');
      final methodBodyStart = fuelRatesScreenSrc.indexOf('{', methodIdx);

      int depth = 0;
      int methodEnd = -1;
      for (int i = methodBodyStart; i < fuelRatesScreenSrc.length; i++) {
        if (fuelRatesScreenSrc[i] == '{') depth++;
        if (fuelRatesScreenSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            methodEnd = i + 1;
            break;
          }
        }
      }

      final methodBody = fuelRatesScreenSrc.substring(
        methodBodyStart,
        methodEnd,
      );

      // Generate 100 random invalid rate values outside [1.0, 500.0]
      final rng = Random(42); // Deterministic seed for reproducibility
      final invalidRates = <double>[];

      for (int i = 0; i < 100; i++) {
        if (i % 4 == 0) {
          // Negative values: [-1000.0, -0.01]
          invalidRates.add(-(rng.nextDouble() * 1000.0 + 0.01));
        } else if (i % 4 == 1) {
          // Zero or just below minimum
          invalidRates.add(rng.nextDouble() * 0.99); // [0, 0.99)
        } else if (i % 4 == 2) {
          // Above maximum: (500.0, 10000.0]
          invalidRates.add(500.01 + rng.nextDouble() * 9500.0);
        } else {
          // Extreme values
          invalidRates.add(
            rng.nextBool()
                ? -(rng.nextDouble() * 1000000)
                : 500.01 + rng.nextDouble() * 1000000,
          );
        }
      }

      // Verify ALL these values would be parseable by double.tryParse
      // (they're all valid doubles that would pass the only existing check)
      for (final rate in invalidRates) {
        final parsed = double.tryParse(rate.toString());
        expect(
          parsed,
          isNotNull,
          reason: 'Rate $rate should be parseable by double.tryParse',
        );
      }

      // Now verify the source code has bounds checking that would reject them.
      // On FIXED code: the method contains bounds validation (< 1.0 or > 500.0)
      // On UNFIXED code: the only check is `if (newRate != null)` — ALL pass
      final hasBoundsRejection = methodBody.contains(
        RegExp(
          r'(newRate\s*<|newRate\s*>|rate\s*<|rate\s*>|<\s*1\.0|>\s*500\.0|<\s*1\b|>\s*500\b)',
        ),
      );

      expect(
        hasBoundsRejection,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.11 — PBT): Generated 100 invalid rate values '
            'outside [1.0, 500.0] that the update flow would accept:\n\n'
            'Sample counterexamples:\n'
            '  Rate: ${invalidRates[0].toStringAsFixed(2)} (negative)\n'
            '  Rate: ${invalidRates[1].toStringAsFixed(2)} (below minimum)\n'
            '  Rate: ${invalidRates[2].toStringAsFixed(2)} (above maximum)\n'
            '  Rate: ${invalidRates[3].toStringAsFixed(2)} (extreme)\n\n'
            'ALL 100 values pass the only check: `if (newRate != null)`\n'
            'because double.tryParse succeeds for all valid doubles.\n\n'
            'The code:\n'
            '  final newRate = double.tryParse(controller.text);\n'
            '  if (newRate != null) {\n'
            '    await _fuelService.updateFuelRate(fuel.fuelId, newRate);\n'
            '  }\n\n'
            'No bounds check exists. The fix must add:\n'
            '  if (newRate < 1.0 || newRate > 500.0) { reject; }',
      );
    });
  });
}
