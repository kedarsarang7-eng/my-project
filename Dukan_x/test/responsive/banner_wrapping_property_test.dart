// ============================================================================
// Task 3.5 — PROPERTY TEST
// Feature: mobile-text-scale-responsive-hardening, Property 7: Info banner
// wraps across available width
// **Validates: Requirements 5.1, 5.2, 5.3**
// ============================================================================
// Property 7 (design.md): For ANY multi-word message and required
//   (Mobile_Viewport x Elevated_Text_Scale) combination, an
//   `OverflowSafeInfoBanner` lays the text out within the bounded banner
//   content width and wraps across that width rather than degenerating to one
//   word per line — its rendered line count does not exceed its word count and
//   it uses the available width — with no Overflow_Failure.
//
// Requirements:
//   5.1 — banner wraps text across the available width rather than one word
//         per line.
//   5.2 — banner renders without an Overflow_Failure.
//   5.3 — banner text is bounded by the available content width (defined width
//         constraint for wrapping).
//
// HOW THIS TEST PROVES THE PROPERTY
//   For every generated multi-word message x every required (viewport, scale)
//   pair the banner is pumped through the app's REAL single text-scale pipeline
//   (`wrapWithPipeline`, non-Windows, so an Above_Cap_Scale is clamped to 1.3),
//   then:
//     * no FlutterError containing `overflowed` is captured (R5.2);
//     * the rendered line count <= the message word count — a banner can never
//       produce more lines than it has words (R5.1 upper bound);
//     * the rendered line count is STRICTLY LESS than the word count — because
//       the banner is given a bounded content width, the greedy wrap packs at
//       least two words per (non-final) line, so it can never degenerate to one
//       word per line. `lines < wordCount` is exactly "uses the available
//       width" (R5.1 / R5.3).
//
//   The strict bound is robust under the flutter_test monospace test font
//   (each glyph is `fontSize` wide). The worst case is the narrowest viewport
//   (360) at the cap scale (1.3): content text width is ~304 logical px and the
//   per-glyph width is ~18.2 px (~16 chars/line). Words are constrained to <= 5
//   characters, so any two words + a space (<= 11 chars, ~200 px) always share a
//   line. Hence every non-final line holds >= 2 words and lines <= ceil(words/2)
//   < words for the generated word counts (>= 5).
//
// APPROACH (per task note): a `forAll` that re-pumps inside a single
//   `testWidgets` would corrupt the binding, so instead a deterministic, seeded
//   sample of messages is drawn from a `dartproptest` Generator (words joined
//   into a message) and EACH message gets its own `testWidgets`, which iterates
//   the full required matrix internally.
//
// PBT library: dartproptest ^0.2.1 (repo-standard). Matrix constants and the
//   real pipeline wrapper come from `responsive_test_harness.dart`.
//
// Run: flutter test test/responsive/banner_wrapping_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  // Number of distinct generated messages exercised (each across the full 3x3
  // viewport x scale matrix => >= 24 * 9 = 216 rendered cases).
  const int kSampleCount = 24;

  // A word pool of short (<= 5 character) tokens. The length cap guarantees the
  // strict `lines < wordCount` bound holds even at the narrowest viewport / cap
  // scale under the flutter_test monospace font (see header). The pool mixes
  // very short and 5-char words for varied, realistic banner messages.
  const List<String> kWords = <String>[
    'po',
    'is',
    'to',
    'be',
    'as',
    'you',
    'can',
    'add',
    'tax',
    'due',
    'net',
    'sum',
    'fee',
    'buy',
    'set',
    'item',
    'note',
    'save',
    'edit',
    'list',
    'late',
    'order',
    'total',
    'units',
    'price',
    'batch',
    'stock',
    'draft',
    'later',
  ];

  // Generator: pick 5..12 words and join them into a multi-word message.
  // Varied word counts and word lengths exercise different wrap geometries.
  final Generator<String> messageGen = Gen.array<String>(
    Gen.elementOf<String>(kWords),
    minLength: 5,
    maxLength: 12,
  ).map((words) => words.join(' '));

  // Draw a DETERMINISTIC, deduplicated sample so the suite is reproducible and
  // each generated message can own its `testWidgets` (no re-pump inside forAll).
  final List<String> messages = _sampleMessages(messageGen, kSampleCount);

  group('Feature: mobile-text-scale-responsive-hardening, Property 7: Info banner '
      'wraps across available width', () {
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final wordCount = message.split(' ').where((w) => w.isNotEmpty).length;
      final preview = message.length <= 32
          ? message
          : '${message.substring(0, 29)}...';

      testWidgets(
        'Property 7 [#${i + 1}, $wordCount words] "$preview" wraps across the '
        'required matrix (lines <= words, uses width, no overflow)',
        (WidgetTester tester) async {
          addTearDown(() => tester.view.resetPhysicalSize());
          addTearDown(() => tester.view.resetDevicePixelRatio());

          for (final viewport in kRequiredViewports) {
            for (final scale in kRequiredScales) {
              tester.view.devicePixelRatio = 1.0;
              tester.view.physicalSize = viewport;

              // Scoped overflow capture, restored in `finally` so one case
              // can never corrupt later cases (mirrors the harness pattern).
              final errors = <FlutterErrorDetails>[];
              final oldHandler = FlutterError.onError;
              FlutterError.onError = (details) => errors.add(details);
              try {
                await tester.pumpWidget(
                  wrapWithPipeline(
                    OverflowSafeInfoBanner(
                      icon: Icons.info,
                      message: message,
                      color: Colors.blue,
                    ),
                    requestedScale: scale,
                  ),
                );
                // Force a layout/paint pass so overflow is reported, without
                // pumpAndSettle (no infinite animations here, but keeps the
                // pattern consistent with the harness).
                await tester.pump();
              } finally {
                FlutterError.onError = oldHandler;
              }

              final where =
                  'viewport ${viewport.width.toStringAsFixed(0)}x'
                  '${viewport.height.toStringAsFixed(0)}, requested scale '
                  '$scale';

              // R5.2 — no render overflow at this (viewport, scale).
              final overflowErrors = errors
                  .where((e) => e.toString().contains('overflowed'))
                  .toList();
              expect(
                overflowErrors,
                isEmpty,
                reason:
                    'OverflowSafeInfoBanner produced an Overflow_Failure at '
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
                    'Unexpected error rendering the banner at $where:\n'
                    '${otherErrors.isEmpty ? '' : otherErrors.first}',
              );

              // Inspect the message paragraph's actual rendered line layout.
              // `computeLineMetrics` is not public on RenderParagraph in this
              // Flutter version, so derive the line count from the selection
              // boxes: each rendered line shares a vertical top, so the number
              // of distinct (rounded) box tops equals the rendered line count.
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(message),
              );
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: message.length),
              );
              final lineCount = boxes
                  .map((box) => box.top.round())
                  .toSet()
                  .length;

              // R5.1 (upper bound) — never more lines than words.
              expect(
                lineCount,
                lessThanOrEqualTo(wordCount),
                reason:
                    'Banner rendered $lineCount lines for $wordCount words at '
                    '$where — line count must never exceed word count.',
              );

              // R5.1 / R5.3 — wraps ACROSS the bounded width: at least two
              // words share a line, so it never degenerates to one word per
              // line. `lines < words` is precisely "uses the available width".
              expect(
                lineCount,
                lessThan(wordCount),
                reason:
                    'Banner rendered one word per line ($lineCount lines for '
                    '$wordCount words) at $where — text must pack multiple '
                    'words per line, using the available banner width rather '
                    'than wrapping per word.',
              );
            }
          }
        },
      );
    }
  });
}

/// Draws a deterministic, deduplicated sample of [count] messages from [gen]
/// using a fixed seed, so the suite is fully reproducible run-to-run.
List<String> _sampleMessages(Generator<String> gen, int count) {
  final rand = Random('mobile-text-scale-banner-property-7');
  final seen = <String>{};
  final out = <String>[];
  // Bound the loop so a degenerate generator can never spin forever.
  var guard = 0;
  while (out.length < count && guard < count * 50) {
    guard++;
    final message = gen.generate(rand).value;
    if (message.trim().isEmpty) continue;
    if (seen.add(message)) out.add(message);
  }
  return out;
}
