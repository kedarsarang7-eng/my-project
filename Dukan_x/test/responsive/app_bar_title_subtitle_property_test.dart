// ============================================================================
// Task 4.2 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 9: App-bar title
// and subtitle do not overlap
// **Validates: Requirements 7.1, 7.2**
// ============================================================================
// Property 9 (design.md): *For any* title string, subtitle string, and required
//   viewport x scale combination, the App_Bar_Header renders with the title's
//   painted bounds entirely ABOVE the subtitle's painted bounds (no vertical
//   overlap), with both bounded by maxLines + ellipsis.
//
// Unit under test: the App_Bar_Header built by `DesktopContentContainer`
//   (`lib/widgets/desktop/desktop_content_container.dart`). Its `_buildHeader`
//   lays the title (`maxLines: 1` + ellipsis) above an optional subtitle
//   (`maxLines: 2` + ellipsis) in a `Column(mainAxisSize: min)` inside an
//   `Expanded`, wrapped in `SafeArea`. The non-overlap guarantee must hold for
//   ANY title/subtitle text across the full required (viewport x text-scale)
//   matrix — including elevated and above-cap scales routed through the real
//   clamp pipeline.
//
// WHY THIS SHAPE (not `forAll` inside `testWidgets`)
//   Driving `forAll` (which owns its own iteration/shrinking loop) from inside
//   a single `testWidgets` re-pumps the WidgetTester binding mid-property and
//   corrupts it. Instead we take a DETERMINISTIC, seeded sample of generated
//   (title, subtitle) pairs from a `dartproptest` `Generator` (using a fixed
//   `Random('...')` so the cases are reproducible), and give each generated
//   pair its OWN `testWidgets`, sweeping the full matrix inside it. This is the
//   same matrix-sweep discipline the Responsive_Test_Harness uses.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide.
//
// Run: flutter test test/responsive/app_bar_title_subtitle_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/widgets/desktop/desktop_content_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

/// A single generated header scenario: a [title] paired with a [subtitle].
/// Both are guaranteed non-empty and distinct from each other so that
/// `find.text` resolves each unambiguously.
class _HeaderCase {
  const _HeaderCase(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

void main() {
  // Word pool used to assemble realistic header titles/subtitles. None of these
  // words collide with the synthetic 'T<i>'/'S<i>' prefixes added per case, so
  // the title and subtitle of a case are always distinct.
  const List<String> kWordPool = <String>[
    'Device',
    'Settings',
    'Configure',
    'Preferences',
    'Inventory',
    'Management',
    'Report',
    'Summary',
    'Customer',
    'Profile',
    'Purchase',
    'Order',
    'Estimate',
    'Returns',
    'Section',
    'Details',
    'Overview',
    'Dashboard',
    'Account',
    'Transaction',
  ];

  // Generator for a list of 1..12 words (so both short and long, multi-line
  // strings are exercised), joined into a single header string.
  final Generator<List<String>> wordsGen = Gen.array<String>(
    Gen.elementOf<String>(kWordPool),
    minLength: 1,
    maxLength: 12,
  );

  // Combined (title-words x subtitle-words) generator.
  final Generator<_HeaderCase> caseGen = Gen.tuple([wordsGen, wordsGen]).map((
    parts,
  ) {
    final titleWords = (parts[0] as List).cast<String>();
    final subWords = (parts[1] as List).cast<String>();
    return _HeaderCase(titleWords.join(' '), subWords.join(' '));
  });

  // Deterministic seeded sample of generated cases (reproducible across runs).
  const int kSampleCount = 22;
  final rand = Random('app-bar-title-subtitle-non-overlap');
  final cases = <_HeaderCase>[];
  for (int i = 0; i < kSampleCount; i++) {
    final base = caseGen.generate(rand).value;
    // Prefix with a unique, distinct token per case so title != subtitle and
    // every Text is unambiguously findable via find.text across the suite.
    cases.add(_HeaderCase('T$i ${base.title}', 'S$i ${base.subtitle}'));
  }

  // A couple of explicitly very long strings to stress the maxLines+ellipsis
  // bounding and the non-overlap guarantee at the extremes.
  cases.add(
    _HeaderCase(
      'TX ${List<String>.filled(18, 'Configure').join(' ')}',
      'SX ${List<String>.filled(24, 'Preferences').join(' ')}',
    ),
  );
  cases.add(const _HeaderCase('TY A', 'SY A single short subtitle line here'));

  /// Pumps the App_Bar_Header for [c] at [viewport]/[scale] through the real
  /// pipeline, asserts no Overflow_Failure, and asserts the title's painted
  /// bounds sit entirely ABOVE the subtitle's painted bounds (Property 9).
  Future<void> assertTitleAboveSubtitle(
    WidgetTester tester,
    _HeaderCase c,
    Size viewport,
    double scale,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = viewport;

    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);

    try {
      await tester.pumpWidget(
        wrapWithPipeline(
          DesktopContentContainer(
            title: c.title,
            subtitle: c.subtitle,
            // No scrollbar so the empty body cannot introduce unrelated
            // layout noise; the header is what we are asserting on.
            showScrollbar: false,
            child: const SizedBox(),
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

    final overflowErrors = errors
        .where((e) => e.toString().contains('overflowed'))
        .toList();
    expect(
      overflowErrors,
      isEmpty,
      reason:
          'Overflow_Failure at $where:\n'
          '${overflowErrors.isEmpty ? '' : overflowErrors.first}',
    );

    final otherErrors = errors
        .where((e) => !e.toString().contains('overflowed'))
        .toList();
    expect(
      otherErrors,
      isEmpty,
      reason:
          'Unexpected error at $where:\n'
          '${otherErrors.isEmpty ? '' : otherErrors.first}',
    );

    final titleFinder = find.text(c.title);
    final subtitleFinder = find.text(c.subtitle);
    expect(titleFinder, findsOneWidget, reason: 'title not found at $where');
    expect(
      subtitleFinder,
      findsOneWidget,
      reason: 'subtitle not found at $where',
    );

    final titleRect = tester.getRect(titleFinder);
    final subtitleRect = tester.getRect(subtitleFinder);

    // Property 9: the title's painted bounds end at or above where the
    // subtitle's painted bounds begin — no vertical overlap. A tiny epsilon
    // absorbs sub-pixel rounding.
    expect(
      titleRect.bottom <= subtitleRect.top + 0.01,
      isTrue,
      reason:
          'Title overlaps subtitle at $where: '
          'title.bottom=${titleRect.bottom}, subtitle.top=${subtitleRect.top}',
    );
  }

  group('Feature: mobile-text-scale-responsive-hardening, Property 9: App-bar '
      'title and subtitle do not overlap', () {
    for (int i = 0; i < cases.length; i++) {
      final c = cases[i];
      // Feature: mobile-text-scale-responsive-hardening, Property 9: App-bar
      // title and subtitle do not overlap
      testWidgets(
        'case $i: title is entirely above subtitle across the required '
        'viewport x scale matrix',
        (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          for (final viewport in kRequiredViewports) {
            for (final scale in kRequiredScales) {
              await assertTitleAboveSubtitle(tester, c, viewport, scale);
            }
          }
        },
      );
    }
  });
}
