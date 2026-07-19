// Requirement 3.2 — Advance default and bounds regression lock.
//
// **Validates: Requirements 3.2**
//
// Per requirements.md Requirement 3.2 (Acceptance Criteria 1-4):
//   AC1. WHEN DcQuoteConversionScreen initializes its advance field, THE
//        AdvanceConfig SHALL default advancePct to 50, and the UI control
//        SHALL constrain the selectable range to [30, 50].
//   AC2. FOR ALL AdvanceConfig instances with advancePct outside [30, 50],
//        THE AdvanceConfig.isValid SHALL be false.
//   AC3. FOR ALL non-negative totalPaise and any AdvanceConfig where isValid
//        is true, computeAdvancePaise(totalPaise) SHALL return either null
//        or a value within [0, totalPaise], never a value outside that
//        range.
//   AC4. IF computeAdvancePaise returns null, THEN THE
//        DcQuoteConversionScreen SHALL reject the conversion and SHALL NOT
//        create a booking or change quote status.
//
// This is a regression-lock test (design.md status: DONE) — no production
// code change is expected unless it surfaces an actual regression (per
// tasks.md Task 13).
//
// Property (tasks.md, explicit): For any AdvanceConfig with advancePct in
// [30, 50] and any non-negative totalPaise, computeAdvancePaise returns
// null or a value in [0, totalPaise].
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard, see pubspec.yaml's
// dev_dependency note on why `glados` is not used). forAll(...) is run with
// >= 100 generated cases per the spec; 200 matches the convention used
// across this repo's other property suites.
//
// AC1 (UI constraint) and AC4 (conversion-rejection wiring) are locked via
// source-scanning, following the same pattern already used for
// "DcQuoteConversionScreen calls X" / "never calls deprecated Y" checks in
// test/features/decoration_catering/dc_quote_invoice_parity_test.dart —
// reading the screen's source and asserting on literal substrings/structural
// ordering rather than a runtime spy. This is necessary because the screen's
// `_advanceConfig` field is private State and the dropdown only ever
// produces in-range values via `AdvanceConfig.tryCreate`, so an out-of-range
// (null-producing) config cannot be reached through the public widget API —
// the only way to reach a null `computeAdvancePaise` result is to construct
// an `AdvanceConfig` directly (bypassing `tryCreate`), which this file does
// at the unit level, then locks in that the screen's guard around that null
// result runs before any repository mutation.
//
// Run: flutter test test/features/decoration_catering/dc_advance_config_test.dart

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/decoration_catering/utils/decoration_catering_business_rules.dart';

/// At least 100 generated cases are required by the spec; 200 matches the
/// dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

const _quoteConversionScreenPath =
    'lib/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart';

String _readSource(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

void main() {
  group('Requirement 3.2 AC1 — AdvanceConfig defaults advancePct to 50; UI '
      'control constrained to [30, 50]', () {
    test('AdvanceConfig() defaults advancePct to 50', () {
      const config = AdvanceConfig();
      expect(config.advancePct, 50);
    });

    test('DcQuoteConversionScreen constrains the advance % dropdown to '
        '[30, 50] inclusive', () {
      final source = _readSource(_quoteConversionScreenPath);
      // Locks the exact generation+filter expression used to build the
      // dropdown's selectable range.
      expect(
        source.contains('List.generate(21, (i) => 30 + i)'),
        isTrue,
        reason:
            'The advance % dropdown must be generated from a base of '
            '30 spanning 21 values (30..50) per Requirement 3.2 AC1.',
      );
      expect(
        source.contains('.where((pct) => pct >= 30 && pct <= 50)'),
        isTrue,
        reason:
            'The advance % dropdown items must be filtered to [30, 50] '
            'inclusive per Requirement 3.2 AC1.',
      );
    });
  });

  group('Requirement 3.2 AC2 — AdvanceConfig.isValid is false for advancePct '
      'outside [30, 50]', () {
    test('isValid is true for boundary and interior values in [30, 50]', () {
      for (final pct in [30, 35, 42, 50]) {
        expect(
          AdvanceConfig(advancePct: pct).isValid,
          isTrue,
          reason: 'advancePct=$pct is within [30, 50] and should be valid',
        );
      }
    });

    test('isValid is false for values outside [30, 50]', () {
      for (final pct in [-100, -1, 0, 1, 29, 51, 52, 100, 1000]) {
        expect(
          AdvanceConfig(advancePct: pct).isValid,
          isFalse,
          reason: 'advancePct=$pct is outside [30, 50] and should be invalid',
        );
      }
    });

    test('Property: isValid is false for any advancePct outside [30, 50] '
        '(100+ generated cases)', () {
      final belowGen = Gen.interval(-1000, 29);
      final aboveGen = Gen.interval(51, 2000);
      final outOfRangeGen =
          Gen.tuple(<Generator<dynamic>>[
            Gen.interval(0, 1),
            belowGen,
            aboveGen,
          ]).map((parts) {
            final useBelow = (parts[0] as int) == 0;
            return useBelow ? parts[1] as int : parts[2] as int;
          });

      final held = forAll(
        (int pct) => AdvanceConfig(advancePct: pct).isValid == false,
        [outOfRangeGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'AdvanceConfig.isValid must be false for any advancePct '
            'outside [30, 50] per Requirement 3.2 AC2.',
      );
    });
  });

  group('Requirement 3.2 AC3 — computeAdvancePaise returns null or a value in '
      '[0, totalPaise] for any valid AdvanceConfig and any non-negative '
      'totalPaise', () {
    test('Property: for any AdvanceConfig with advancePct in [30, 50] and '
        'any non-negative totalPaise, computeAdvancePaise(totalPaise) '
        'returns null or a value in [0, totalPaise]', () {
      final pctGen = Gen.interval(30, 50);
      // Non-negative totalPaise spanning zero through a large
      // (crore-scale) amount — a realistic upper bound for an event
      // quote total in paise (₹1,00,00,000).
      final totalPaiseGen = Gen.interval(0, 1000000000);

      final caseGen = Gen.tuple(<Generator<dynamic>>[pctGen, totalPaiseGen]);

      final held = forAll(
        (List<dynamic> args) {
          final pct = args[0] as int;
          final totalPaise = args[1] as int;
          final config = AdvanceConfig(advancePct: pct);

          // Sanity: every generated pct is in [30, 50] and therefore valid.
          if (!config.isValid) return false;

          final result = config.computeAdvancePaise(totalPaise);
          if (result == null) return true;
          return result >= 0 && result <= totalPaise;
        },
        [caseGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'For any valid AdvanceConfig (advancePct in [30, 50]) and '
            'any non-negative totalPaise, computeAdvancePaise must '
            'return either null or a value within [0, totalPaise], '
            'never a value outside that range (Requirement 3.2 AC3).',
      );
    });

    test('Anchors: zero, small, and large totals compute an advance within '
        'bounds for boundary advancePct values', () {
      for (final pct in [30, 50]) {
        final config = AdvanceConfig(advancePct: pct);
        for (final total in [0, 1, 100, 999999, 10000000000]) {
          final result = config.computeAdvancePaise(total);
          expect(
            result,
            isNotNull,
            reason: 'pct=$pct, total=$total should compute a bounded advance',
          );
          expect(
            result! >= 0 && result <= total,
            isTrue,
            reason: 'advance=$result must be within [0, $total]',
          );
        }
      }
    });
  });

  group('Requirement 3.2 AC4 — a null computeAdvancePaise result rejects the '
      'conversion without creating a booking or changing quote status', () {
    test('An invalid AdvanceConfig (constructed directly, bypassing '
        'tryCreate) yields a null computeAdvancePaise result', () {
      // AdvanceConfig's const constructor does not itself prevent an
      // out-of-range advancePct — only the tryCreate factory enforces
      // the [30, 50] bound. This demonstrates the null-producing path
      // that the screen's guard (checked below) must handle; it cannot
      // be reached through the public widget API since the dropdown
      // only ever emits tryCreate-validated (in-range) values.
      const invalidConfig = AdvanceConfig(advancePct: 99);
      expect(invalidConfig.isValid, isFalse);
      expect(invalidConfig.computeAdvancePaise(100000), isNull);
    });

    test('DcQuoteConversionScreen._convertToBooking rejects the conversion '
        'before any repository mutation when computeAdvancePaise returns '
        'null', () {
      final source = _readSource(_quoteConversionScreenPath);

      final methodIndex = source.indexOf('Future<void> _convertToBooking()');
      expect(
        methodIndex,
        greaterThanOrEqualTo(0),
        reason: '_convertToBooking must exist on DcQuoteConversionScreen',
      );
      final methodBody = source.substring(methodIndex);

      final nullGuardIndex = methodBody.indexOf('if (advancePaise == null)');
      expect(
        nullGuardIndex,
        greaterThanOrEqualTo(0),
        reason:
            '_convertToBooking must guard on a null advancePaise result '
            'per Requirement 3.2 AC4.',
      );

      final updateQuoteStatusIndex = methodBody.indexOf(
        'repo.updateQuoteStatus(',
      );
      final createBookingIndex = methodBody.indexOf('repo.createBooking(');
      expect(
        updateQuoteStatusIndex,
        greaterThan(nullGuardIndex),
        reason:
            'The null-advance guard must run before any quote status '
            'mutation (Requirement 3.2 AC4).',
      );
      expect(
        createBookingIndex,
        greaterThan(nullGuardIndex),
        reason:
            'The null-advance guard must run before booking creation '
            '(Requirement 3.2 AC4).',
      );

      // The guard branch must return early, and that return must occur
      // before either mutation call site in the method's source order.
      final returnIndex = methodBody.indexOf('return;', nullGuardIndex);
      expect(returnIndex, greaterThan(nullGuardIndex));
      expect(returnIndex, lessThan(updateQuoteStatusIndex));
      expect(returnIndex, lessThan(createBookingIndex));
    });
  });
}
