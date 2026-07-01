// ============================================================================
// Task 3.3 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 6: Value stays on a
// single visible row
// **Validates: Requirements 4.3, 4.4**
// ============================================================================
// Property 6 (design.md): For any amount value (including values too wide to
//   fit naturally) in an `OverflowSafeLabelValueRow`, the value renders on a
//   single visible row together with its label — shrinking to fit (FittedBox
//   scale-down) or truncating with ellipsis when it cannot fit, and remaining
//   whole when it fits.
//
// Requirement 4.3: WHERE a Totals_Card amount value cannot fit on its row, THE
//   amount value SHALL shrink-to-fit or truncate with ellipsis while remaining
//   on a single visible row with its label.
// Requirement 4.4: WHERE a Totals_Card amount value fits on its row, THE amount
//   value SHALL remain on a single visible row together with its label.
//
// HOW THIS TEST PROVES SINGLE-ROW BEHAVIOR
//   `OverflowSafeLabelValueRow` renders the value as
//   `Flexible(FittedBox(fit: scaleDown, alignment: centerRight,
//             child: Text(value, maxLines: 1, softWrap: false)))`.
//   The strongest single-row guarantee is therefore structural and is checked
//   at the WIDGET level for every generated amount across the full required
//   matrix:
//     * the value `Text` is present in the tree (FittedBox keeps the whole
//       widget — scaling only shrinks its painted size, so `find.text` still
//       locates it even when it cannot fit naturally);
//     * that `Text` has `maxLines == 1` and `softWrap == false`, so it can only
//       ever occupy one line — it shrinks-to-fit/truncates rather than wrapping;
//     * the value shares the row with its label (their vertical extents
//       overlap), proving "a single visible row together with its label";
//     * the row reports NO overflow (`FlutterError.onError` capture), so the
//       single-row layout is achieved without clipping.
//
// GENERATION STRATEGY (per the no-`forAll`-re-pump rule)
//   `forAll` cannot re-pump widgets inside a single `testWidgets` (it would
//   corrupt the binding). Instead a dartproptest `Generator<String>` is sampled
//   with a FIXED `Random('seed')` to produce a deterministic set of amount
//   strings spanning tiny to enormous magnitudes, and EACH amount runs in its
//   OWN `testWidgets` (fresh binding) where the full (viewport x scale) matrix
//   is iterated. Explicit edge amounts (zero, single digit, grouped, and a
//   far-too-wide 30+ digit value) are prepended so the "cannot fit" path is
//   always exercised.
//
// PBT library: dartproptest ^0.2.1 (repo-standard). Run:
//   flutter test test/responsive/value_single_row_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

/// Groups [digits] into 3-digit blocks from the right (e.g. `1234567` ->
/// `1,234,567`) so generated amounts can be both plain and comma-grouped,
/// widening some values to better stress the shrink-to-fit / truncate path.
String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Builds an amount string (currency-prefixed) whose integer part has
/// [intDigits] digits, optionally comma-grouped, with two-digit [paise].
String _amount(int intDigits, int paise, bool grouped) {
  final sb = StringBuffer();
  for (var i = 0; i < intDigits; i++) {
    // First digit is non-zero; remaining digits vary so the string is not a
    // monotonous run of one character.
    final d = i == 0 ? 1 + (intDigits % 9) : (i * 7 + intDigits) % 10;
    sb.write(d);
  }
  final intPart = grouped ? _group(sb.toString()) : sb.toString();
  return '\u20B9$intPart.${paise.toString().padLeft(2, '0')}';
}

void main() {
  // ── Generator: amount strings of widely varying magnitude ────────────────
  // integer-digit count 1..48 (single rupee up to astronomically wide),
  // paise 0..99, and a grouping flag.
  final Generator<String> amountGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(1, 48),
        Gen.interval(0, 99),
        Gen.interval(0, 1),
      ]).map((parts) {
        final intDigits = parts[0] as int;
        final paise = parts[1] as int;
        final grouped = (parts[2] as int) == 1;
        return _amount(intDigits, paise, grouped);
      });

  // Deterministically sample the generator with a fixed seed so the test is
  // reproducible while still covering a broad, "generated" input space.
  final rand = Random('mobile-text-scale-property-6-value-single-row');
  final sampled = <String>[];
  for (var i = 0; i < 22; i++) {
    sampled.add(amountGen.generate(rand).value);
  }

  // Explicit edge amounts: zero, single digit, a normal grouped amount, and a
  // deliberately far-too-wide value that CANNOT fit naturally (forces the
  // FittedBox scale-down / truncate path).
  final amounts = <String>{
    '\u20B90.00',
    '\u20B91',
    '\u20B999.50',
    '\u20B91,234.56',
    '\u20B9${'9' * 32}.99',
    ...sampled,
  }.toList();

  group(
    'Feature: mobile-text-scale-responsive-hardening, Property 6: Value stays '
    'on a single visible row',
    () {
      for (final amount in amounts) {
        testWidgets(
          'value "$amount" renders on one row with its label across the '
          'required matrix (shrink-to-fit/truncate, no overflow)',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final exercised = <String>{};

            for (final viewport in kRequiredViewports) {
              for (final scale in kRequiredScales) {
                tester.view.devicePixelRatio = 1.0;
                tester.view.physicalSize = viewport;

                // Scoped overflow capture (reused pattern from the harness).
                final errors = <FlutterErrorDetails>[];
                final oldHandler = FlutterError.onError;
                FlutterError.onError = (details) => errors.add(details);
                try {
                  await tester.pumpWidget(
                    wrapWithPipeline(
                      // A narrow box guarantees that wide amounts cannot fit
                      // naturally, exercising the shrink-to-fit/truncate path
                      // (R4.3) while normal amounts exercise the fit path (R4.4).
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 180,
                          child: OverflowSafeLabelValueRow(
                            label: 'Total',
                            value: amount,
                          ),
                        ),
                      ),
                      requestedScale: scale,
                    ),
                  );
                  await tester.pump();
                } finally {
                  FlutterError.onError = oldHandler;
                }

                exercised.add(responsiveMatrixKey(viewport, scale));

                final where =
                    'viewport '
                    '${viewport.width.toStringAsFixed(0)}x'
                    '${viewport.height.toStringAsFixed(0)}, requested scale '
                    '$scale';

                // (1) No Overflow_Failure — the single-row layout is achieved
                // without clipping.
                final overflow = errors
                    .where((e) => e.toString().contains('overflowed'))
                    .toList();
                expect(
                  overflow,
                  isEmpty,
                  reason:
                      'Value "$amount" overflowed at $where:\n'
                      '${overflow.isEmpty ? '' : overflow.first}',
                );

                // (2) Label and value are both present together.
                final labelFinder = find.text('Total');
                final valueFinder = find.text(amount);
                expect(
                  labelFinder,
                  findsOneWidget,
                  reason: 'Label missing at $where.',
                );
                expect(
                  valueFinder,
                  findsOneWidget,
                  reason:
                      'Value "$amount" not in tree at $where '
                      '(FittedBox keeps the whole Text — scaling only shrinks '
                      'its painted size).',
                );

                // (3) The value can only ever occupy a SINGLE line.
                final valueText = tester.widget<Text>(valueFinder);
                expect(
                  valueText.maxLines,
                  1,
                  reason: 'Value "$amount" must be maxLines:1 at $where.',
                );
                expect(
                  valueText.softWrap,
                  isFalse,
                  reason: 'Value "$amount" must not soft-wrap at $where.',
                );

                // (4) The value shares the row with its label (their vertical
                // extents overlap) — "a single visible row together with its
                // label", not stacked vertically.
                final labelRect = tester.getRect(labelFinder);
                final valueRect = tester.getRect(valueFinder);
                expect(
                  valueRect.center.dy,
                  inInclusiveRange(labelRect.top - 1, labelRect.bottom + 1),
                  reason:
                      'Value "$amount" not on the same row as its label at '
                      '$where (label=$labelRect, value=$valueRect).',
                );
              }
            }

            // Totality (R10.6): every required (viewport@scale) pair exercised.
            expect(
              missingMatrixPairs(exercised),
              isEmpty,
              reason:
                  'Matrix incomplete for "$amount": '
                  '${(missingMatrixPairs(exercised).toList()..sort())}',
            );
          },
        );
      }
    },
  );
}
