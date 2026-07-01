// ============================================================================
// Task 5.4 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 8: Segmented-control
// labels remain visible
// **Validates: Requirements 6.2**
// ============================================================================
// Property 8 (design.md): For ANY required (Mobile_Viewport x Elevated_Text_
//   Scale) combination, the GST report-type segmented control renders all three
//   labels (GSTR-1, GSTR-3B, HSN) without clipping — each label is findable and
//   shrinks-to-fit rather than being cut off — and the control reports no
//   Overflow_Failure.
//
// Requirement:
//   6.2 — WHEN the GST_Reports_Screen segmented control (GSTR-1/GSTR-3B/HSN) is
//         rendered at any Elevated_Text_Scale up to the cap on any
//         Mobile_Viewport, THE segmented control SHALL display its options
//         without clipping their labels.
//
// UNIT UNDER TEST — a REPRESENTATIVE control, not the whole screen.
//   `gst_reports_screen.dart` is heavy (Riverpod + DI + service locator), so we
//   render a representative `SegmentedButton<String>` that mirrors the EXACT
//   label structure the fixed screen uses on mobile:
//       SizedBox(width: double.infinity)            // full-width on mobile
//         -> SegmentedButton<String>(
//              segments: [ ButtonSegment(
//                label: FittedBox(fit: BoxFit.scaleDown,
//                                 child: Text('GSTR-1', maxLines: 1)), ), ... ],
//            )
//   Icons are dropped on mobile (matching `context.isMobile ? null : Icon(...)`)
//   so the three labels share a single row. The FittedBox(scaleDown) is the
//   mechanism that makes each label shrink-to-fit instead of clipping when the
//   text scale is raised.
//
// HOW THIS TEST PROVES THE PROPERTY
//   The control is pumped through the app's REAL single text-scale pipeline
//   (`wrapWithPipeline`, non-Windows, so an Above_Cap_Scale is clamped to 1.3)
//   across the FULL required matrix (3 viewports x 3 scales). For every pair:
//     * no FlutterError containing `overflowed` is captured (no overflow);
//     * each of the three labels (GSTR-1, GSTR-3B, HSN) resolves to exactly one
//       painted `Text` (findable — i.e. still in the tree and visible);
//     * each label's painted bounds lie WITHIN the control's horizontal bounds
//       (no clipping off either edge) — the FittedBox scale-down keeps the glyph
//       box inside its segment rather than letting it spill/clip;
//     * the three labels are laid out left-to-right on a SINGLE row: their
//       centres are strictly increasing in x and their vertical extents all
//       overlap a common band — so all three stay visible side-by-side rather
//       than one being cut off or pushed to another line.
//   Finally the suite asserts the full required matrix was exercised (totality).
//
// This is a matrix-sweep test (the labels are fixed, so there is no generated
// input space to sample) using `flutter_test`, per the task note. Matrix
// constants and the real pipeline wrapper come from `responsive_test_harness`.
//
// Run: flutter test test/responsive/segmented_control_labels_property_test.dart -r expanded
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

/// The three GST report-type labels, in their on-screen left-to-right order.
const List<String> _kGstLabels = <String>['GSTR-1', 'GSTR-3B', 'HSN'];

/// Builds a representative full-width segmented control that mirrors the EXACT
/// mobile label structure of `gst_reports_screen.dart`: a full-width
/// `SegmentedButton<String>` whose three labels are each
/// `FittedBox(scaleDown) -> Text(maxLines: 1)`, with icons dropped (mobile).
Widget _buildRepresentativeGstSegmentedControl() {
  return SizedBox(
    width: double.infinity,
    child: SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(
          value: 'gstr1',
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('GSTR-1', maxLines: 1),
          ),
        ),
        ButtonSegment<String>(
          value: 'gstr3b',
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('GSTR-3B', maxLines: 1),
          ),
        ),
        ButtonSegment<String>(
          value: 'hsn',
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('HSN', maxLines: 1),
          ),
        ),
      ],
      selected: const <String>{'gstr1'},
      onSelectionChanged: (_) {},
    ),
  );
}

void main() {
  group('Feature: mobile-text-scale-responsive-hardening, Property 8: '
      'Segmented-control labels remain visible', () {
    testWidgets(
      'Property 8: GSTR-1 / GSTR-3B / HSN labels all stay findable, on one '
      'row, and within bounds (shrink-to-fit, no clipping, no overflow) '
      'across the full required matrix',
      (WidgetTester tester) async {
        final exercised = <String>{};

        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        for (final viewport in kRequiredViewports) {
          for (final scale in kRequiredScales) {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = viewport;

            // Scoped overflow capture, restored in `finally` so one case can
            // never corrupt later cases (mirrors the harness pattern).
            final errors = <FlutterErrorDetails>[];
            final oldHandler = FlutterError.onError;
            FlutterError.onError = (details) => errors.add(details);
            try {
              await tester.pumpWidget(
                wrapWithPipeline(
                  Center(child: _buildRepresentativeGstSegmentedControl()),
                  requestedScale: scale,
                ),
              );
              // Force a layout/paint pass so overflow is reported, without
              // pumpAndSettle (consistent with the harness).
              await tester.pump();
            } finally {
              FlutterError.onError = oldHandler;
            }

            final where =
                'viewport ${viewport.width.toStringAsFixed(0)}x'
                '${viewport.height.toStringAsFixed(0)}, requested scale '
                '$scale';

            // (1) No render overflow at this (viewport, scale) — R6.2.
            final overflowErrors = errors
                .where((e) => e.toString().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'GST segmented control produced an Overflow_Failure at '
                  '$where:\n${overflowErrors.isEmpty ? '' : overflowErrors.first}',
            );
            // Surface any other build/layout error rather than swallowing it.
            final otherErrors = errors
                .where((e) => !e.toString().contains('overflowed'))
                .toList();
            expect(
              otherErrors,
              isEmpty,
              reason:
                  'Unexpected error rendering the segmented control at '
                  '$where:\n${otherErrors.isEmpty ? '' : otherErrors.first}',
            );

            // (2) All three labels are findable (still in the tree, visible).
            for (final label in _kGstLabels) {
              expect(
                find.text(label),
                findsOneWidget,
                reason:
                    'Segmented-control label "$label" must render exactly '
                    'once at $where (label cut off / missing).',
              );
            }

            // The control's painted bounds — used to assert no label is
            // clipped off either horizontal edge.
            final controlRect = tester.getRect(
              find.byType(SegmentedButton<String>),
            );

            final labelRects = <String, Rect>{
              for (final label in _kGstLabels)
                label: tester.getRect(find.text(label)),
            };

            // (3) Shrink-to-fit, not clipped: every label's painted bounds lie
            //     WITHIN the control's horizontal bounds. The FittedBox
            //     scale-down keeps each glyph box inside its segment rather
            //     than spilling past / being cut at the control edges. A 0.5px
            //     tolerance absorbs sub-pixel rounding.
            const double eps = 0.5;
            for (final entry in labelRects.entries) {
              final label = entry.key;
              final rect = entry.value;
              expect(
                rect.left,
                greaterThanOrEqualTo(controlRect.left - eps),
                reason:
                    'Label "$label" is clipped at the LEFT edge at $where: '
                    'labelRect=$rect, controlRect=$controlRect.',
              );
              expect(
                rect.right,
                lessThanOrEqualTo(controlRect.right + eps),
                reason:
                    'Label "$label" is clipped at the RIGHT edge at $where: '
                    'labelRect=$rect, controlRect=$controlRect.',
              );
              // A real, positive painted area — the label was actually laid
              // out (shrunk, never collapsed to nothing).
              expect(
                rect.width,
                greaterThan(0.0),
                reason:
                    'Label "$label" has zero painted width at $where '
                    '(collapsed / not visible).',
              );
            }

            // (4) Single row, left-to-right: centres strictly increasing in x
            //     and vertical extents all overlap a common band — so all
            //     three labels share one row, none pushed off / onto another
            //     line.
            final r1 = labelRects['GSTR-1']!;
            final r2 = labelRects['GSTR-3B']!;
            final r3 = labelRects['HSN']!;

            expect(
              r1.center.dx < r2.center.dx && r2.center.dx < r3.center.dx,
              isTrue,
              reason:
                  'Labels are not laid out left-to-right (GSTR-1, GSTR-3B, '
                  'HSN) at $where: centres '
                  '${r1.center.dx}, ${r2.center.dx}, ${r3.center.dx}.',
            );

            // Vertical overlap => same row. Two rects overlap vertically when
            // each one's top is above the other's bottom.
            bool overlapVertically(Rect a, Rect b) =>
                a.top < b.bottom && b.top < a.bottom;
            expect(
              overlapVertically(r1, r2) &&
                  overlapVertically(r2, r3) &&
                  overlapVertically(r1, r3),
              isTrue,
              reason:
                  'Labels do not share a single row at $where (vertical '
                  'extents do not all overlap): GSTR-1=$r1, GSTR-3B=$r2, '
                  'HSN=$r3.',
            );

            exercised.add(responsiveMatrixKey(viewport, scale));
          }
        }

        // Totality (R10.6): every required (viewport, scale) pair exercised.
        final missing = missingMatrixPairs(exercised);
        expect(
          missing,
          isEmpty,
          reason:
              'Property 8 must exercise the full required matrix; missing '
              'pairs: ${missing.toList()..sort()}',
        );
      },
    );
  });
}
