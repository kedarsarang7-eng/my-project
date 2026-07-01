// ============================================================================
// Task 3.2 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 5: Label/value rows
// never overlap
// **Validates: Requirements 3.4, 4.1**
// ============================================================================
// Property 5 (design.md): For ANY label string, value string, and required
//   (viewport x text-scale) combination, an `OverflowSafeLabelValueRow` lays
//   out so the label's painted bounds and the value's painted bounds do NOT
//   intersect (a positive horizontal gap is preserved) and the row reports no
//   Overflow_Failure.
//
// Requirements:
//   3.4 — WHERE a label and its associated value are displayed on one row, THE
//         row SHALL keep the label and value visually separated without overlap
//         at every Elevated_Text_Scale up to the Text_Scale_Cap.
//   4.1 — WHEN the Totals_Card is rendered at any Elevated_Text_Scale up to the
//         cap on any Mobile_Viewport, THE Totals_Card SHALL display each label
//         without overlapping its corresponding amount value.
//
// UNIT UNDER TEST
//   `OverflowSafeLabelValueRow` from
//   `package:dukanx/widgets/responsive/overflow_safe.dart`, laid out as
//     Row[ Flexible(Text label, ellipsis), SizedBox(minGap), Flexible(FittedBox(Text value)) ].
//   The label sits on the left, the value on the right, separated by a
//   guaranteed `minGap`. Both children are `Flexible`, so the row can never
//   overflow. Property 5 asserts the painted boxes never intersect horizontally
//   and that a strictly positive gap remains.
//
// HOW THE GEOMETRY IS MEASURED
//   Each case uses a DISTINCT, non-empty label and value (label = word-based,
//   value = numeric/currency-based) so `find.text(...)` resolves exactly one
//   widget for each. `tester.getRect` returns the on-screen painted bounds —
//   it accounts for the `FittedBox` scale-down transform applied to the value —
//   so we can assert `valueRect.left > labelRect.right` (no intersection,
//   positive gap) directly.
//
// GENERATED SWEEP (not a single forAll closure):
//   Pumping real frames inside a `forAll` closure corrupts the test binding
//   (the binding is mutated by each pump + the scoped `FlutterError.onError`).
//   Following the sibling suites (`harness_overflow_detection_property_test`),
//   we draw a deterministic, SEEDED sample of label/value pairs from a
//   `dartproptest` `Generator` at suite-build time and run each pair in its OWN
//   isolated `testWidgets`, iterating the FULL required matrix inside. This is
//   the dartproptest equivalent of a `forAll` over generated label/value
//   strings x the required matrix, with each case isolated.
//
// PBT library: dartproptest ^0.2.1 (the repo-standard QuickCheck/Hypothesis-
//   inspired library).
//
// Run: flutter test test/responsive/label_value_non_overlap_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

/// A single generated scenario: a [label] (word-based) paired with a [value]
/// (numeric/currency-based). The two pools never overlap, so the strings are
/// always distinct and each resolves to exactly one `find.text` match.
class _LabelValueCase {
  const _LabelValueCase(this.label, this.value);

  final String label;
  final String value;

  @override
  String toString() => 'label="$label", value="$value"';
}

// Word-based label pool: short labels, multi-word labels, and a deliberately
// very long label that forces ellipsis inside a constrained Flexible.
const List<String> _kLabelPool = <String>[
  'Total',
  'Subtotal',
  'Discount',
  'Grand Total',
  'Amount Payable',
  'Balance Due',
  'CGST (9%)',
  'Round Off',
  'Net Amount Receivable After All Adjustments And Applicable Taxes',
];

// Numeric / currency value pool: small amounts, grouped Indian-format amounts,
// and very large numbers that cannot fit naturally and must shrink-to-fit.
const List<String> _kValuePool = <String>[
  '₹0.00',
  '₹12.50',
  '₹1,234.56',
  '₹99,999.99',
  '₹12,34,567.89',
  '₹9,99,99,999.99',
  '₹1,23,45,67,890.12',
  '12345678901234567890',
  '₹999999999999999.99',
];

/// Generator: an arbitrary (label x value) pair drawn from the two disjoint
/// pools. Because labels are word-based and values are numeric/currency-based,
/// the two strings are always distinct.
final Generator<_LabelValueCase> _caseGen =
    Gen.tuple([
      Gen.interval(0, _kLabelPool.length - 1),
      Gen.interval(0, _kValuePool.length - 1),
    ]).map((parts) {
      final String label = _kLabelPool[parts[0] as int];
      final String value = _kValuePool[parts[1] as int];
      return _LabelValueCase(label, value);
    });

/// Draws [count] reproducible cases from [_caseGen] using a fixed seed, then
/// pins guaranteed extremes (longest label + longest value, and a short pair)
/// so the hardest layouts are always exercised regardless of sampling.
List<_LabelValueCase> _sampleCases(int count) {
  final random = Random('mobile-text-scale-hardening-property-5');
  final cases = <_LabelValueCase>[
    // Guaranteed extreme: longest label + widest value (worst-case crowding).
    const _LabelValueCase(
      'Net Amount Receivable After All Adjustments And Applicable Taxes',
      '₹1,23,45,67,890.12',
    ),
    // Guaranteed extreme: short label + very large unbroken number.
    const _LabelValueCase('Total', '12345678901234567890'),
    // Guaranteed minimal: short label + tiny value.
    const _LabelValueCase('Total', '₹0.00'),
  ];
  for (var i = 0; i < count; i++) {
    cases.add(_caseGen.generate(random).value);
  }
  return cases;
}

/// Pumps an [OverflowSafeLabelValueRow] for [c] across the FULL required matrix
/// and asserts Property 5 for every (viewport, scale) pair:
///   * no Overflow_Failure is reported, and
///   * the label's painted bounds and the value's painted bounds do not
///     intersect (valueRect.left > labelRect.right — a positive gap).
/// Also asserts the full required matrix was exercised (totality).
Future<void> _assertNonOverlapAcrossMatrix(
  WidgetTester tester,
  _LabelValueCase c,
) async {
  final exercised = <String>{};

  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  for (final viewport in kRequiredViewports) {
    for (final scale in kRequiredScales) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          wrapWithPipeline(
            // Centred so the row gets a finite, representative width budget
            // (full-viewport width) rather than being unbounded.
            Center(
              child: OverflowSafeLabelValueRow(label: c.label, value: c.value),
            ),
            requestedScale: scale,
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = oldHandler;
      }

      final where =
          'viewport ${viewport.width.toStringAsFixed(0)}x'
          '${viewport.height.toStringAsFixed(0)}, requested scale $scale';

      // (1) No overflow at this pair.
      final overflowErrors = errors
          .where((e) => e.toString().contains('overflowed'))
          .toList();
      expect(
        overflowErrors,
        isEmpty,
        reason:
            'OverflowSafeLabelValueRow ($c) overflowed at $where:\n'
            '${overflowErrors.isEmpty ? '' : overflowErrors.first}',
      );

      // Surface any non-overflow build/layout error rather than swallowing it.
      final otherErrors = errors
          .where((e) => !e.toString().contains('overflowed'))
          .toList();
      expect(
        otherErrors,
        isEmpty,
        reason:
            'Unexpected error for ($c) at $where:\n'
            '${otherErrors.isEmpty ? '' : otherErrors.first}',
      );

      // (2) Label and value each resolve to exactly one painted Text.
      final labelFinder = find.text(c.label);
      final valueFinder = find.text(c.value);
      expect(
        labelFinder,
        findsOneWidget,
        reason: 'label "${c.label}" must render exactly once at $where',
      );
      expect(
        valueFinder,
        findsOneWidget,
        reason: 'value "${c.value}" must render exactly once at $where',
      );

      // (3) Painted bounds must NOT intersect, with a strictly positive gap:
      //     the value (right child) starts to the right of where the label
      //     (left child) ends. The SizedBox(minGap) between the two Flexible
      //     slots guarantees this separation.
      final labelRect = tester.getRect(labelFinder);
      final valueRect = tester.getRect(valueFinder);
      expect(
        valueRect.left,
        greaterThan(labelRect.right),
        reason:
            'label/value painted bounds overlap at $where for ($c): '
            'labelRect=$labelRect, valueRect=$valueRect — the value must '
            'start to the right of the label (positive gap preserved).',
      );

      exercised.add(responsiveMatrixKey(viewport, scale));
    }
  }

  // Totality (R10.6): every required (viewport, scale) pair was exercised.
  final missing = missingMatrixPairs(exercised);
  expect(
    missing,
    isEmpty,
    reason:
        'Property 5 must exercise the full required matrix; missing pairs: '
        '${missing.toList()..sort()}',
  );
}

void main() {
  // A representative seeded sweep: >= 20 generated cases plus 3 pinned extremes,
  // covering short/long labels and small/large/wide values across the full
  // required matrix (3 viewports x 3 scales).
  final cases = _sampleCases(20);

  group(
    'Feature: mobile-text-scale-responsive-hardening, Property 5: Label/value '
    'rows never overlap',
    () {
      for (var i = 0; i < cases.length; i++) {
        final c = cases[i];
        testWidgets(
          'Property 5 [#$i $c]: label & value never overlap across the matrix',
          (WidgetTester tester) async {
            await _assertNonOverlapAcrossMatrix(tester, c);
          },
        );
      }
    },
  );
}
