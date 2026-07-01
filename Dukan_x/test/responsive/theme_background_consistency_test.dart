// ============================================================================
// Task 8.3 — EXAMPLE / STRUCTURAL TEST (non-PBT criterion)
// Feature: mobile-text-scale-responsive-hardening
// Theme background consistency
// **Validates: Requirements 9.5**
// ============================================================================
// R9.5: "THE DukanX_App SHALL apply theme background colors consistently so
//   that a screen's background matches the active light or dark theme without
//   mismatched regions."
//
// Validates the work done in task 4.1, where `DesktopContentContainer` (when a
// title is supplied so the header path is taken) wraps its header + content in
// a `ColoredBox` painted with `Theme.of(context).scaffoldBackgroundColor`. The
// background region must therefore match the ACTIVE theme's
// `scaffoldBackgroundColor` under both a light and a dark theme.
//
// Approach (example/widget assertion, not a brittle pixel golden):
//   * Pump a `DesktopContentContainer` (with a title, so `_buildHeader` runs)
//     inside the app's real pipeline (`wrapWithPipeline`) under a known light
//     theme, then under a known dark theme.
//   * Read the ACTIVE theme in scope at the container via `Theme.of(element)`
//     so the expected color is exactly what production resolves (independent of
//     any MaterialApp theme post-processing).
//   * Find the `ColoredBox` introduced by the container and assert its color
//     equals `theme.scaffoldBackgroundColor` for each brightness — reading the
//     actual widget color rather than comparing pixels.
//
// Run: flutter test test/responsive/theme_background_consistency_test.dart
// ============================================================================

import 'package:dukanx/widgets/desktop/desktop_content_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  // Known themes with explicit, distinct scaffold backgrounds so the assertion
  // is unambiguous and the light vs dark cases are provably different.
  final ThemeData lightTheme = ThemeData.light(
    useMaterial3: true,
  ).copyWith(scaffoldBackgroundColor: const Color(0xFFF5F6FA));
  final ThemeData darkTheme = ThemeData.dark(
    useMaterial3: true,
  ).copyWith(scaffoldBackgroundColor: const Color(0xFF101418));

  /// Pumps the [DesktopContentContainer] header path under [theme] and returns
  /// the `(activeScaffoldBackground, containerColoredBoxColors)` pair so the
  /// caller can assert the container's background matches the active theme.
  Future<({Color active, List<Color?> boxes})> pumpAndReadBackground(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await tester.pumpWidget(
      wrapWithPipeline(
        const DesktopContentContainer(
          title: 'Device Settings',
          subtitle: 'Configure device-specific preferences',
          // No scrollbar so the empty body cannot introduce unrelated layout
          // noise; the background region is what we assert on.
          showScrollbar: false,
          child: SizedBox(),
        ),
        requestedScale: 1.0,
        theme: theme,
      ),
    );
    // Settle so a theme swap within a single test fully takes effect (there are
    // no infinite animations in this header-only tree).
    await tester.pumpAndSettle();

    // The active theme in scope at the container is exactly the theme whose
    // scaffoldBackgroundColor the container's ColoredBox is built from.
    final containerElement = tester.element(
      find.byType(DesktopContentContainer),
    );
    final active = Theme.of(containerElement).scaffoldBackgroundColor;

    // The ColoredBox(es) the container itself introduces (the outermost wraps
    // header + content with the scaffold background, per task 4.1).
    final boxColors = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(DesktopContentContainer),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((b) => b.color)
        .toList();

    return (active: active, boxes: boxColors);
  }

  testWidgets(
    'scaffold background region matches the active LIGHT theme background',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = kRequiredViewports.first;

      final result = await pumpAndReadBackground(tester, lightTheme);

      expect(
        result.active,
        const Color(0xFFF5F6FA),
        reason: 'active light theme scaffoldBackgroundColor should be applied',
      );
      expect(
        result.boxes,
        contains(result.active),
        reason:
            'DesktopContentContainer must paint a ColoredBox using the active '
            'theme scaffoldBackgroundColor (${result.active}); found: '
            '${result.boxes}',
      );
    },
  );

  testWidgets(
    'scaffold background region matches the active DARK theme background',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = kRequiredViewports.first;

      final result = await pumpAndReadBackground(tester, darkTheme);

      expect(
        result.active,
        const Color(0xFF101418),
        reason: 'active dark theme scaffoldBackgroundColor should be applied',
      );
      expect(
        result.boxes,
        contains(result.active),
        reason:
            'DesktopContentContainer must paint a ColoredBox using the active '
            'theme scaffoldBackgroundColor (${result.active}); found: '
            '${result.boxes}',
      );
    },
  );

  testWidgets(
    'light and dark backgrounds differ, proving the active theme drives the '
    'background (no mismatched/hardcoded region)',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = kRequiredViewports.first;

      final light = await pumpAndReadBackground(tester, lightTheme);
      final dark = await pumpAndReadBackground(tester, darkTheme);

      expect(
        light.active,
        isNot(equals(dark.active)),
        reason: 'light and dark scaffold backgrounds must differ',
      );
      expect(light.boxes, contains(light.active));
      expect(dark.boxes, contains(dark.active));
    },
  );
}
