/// Layout-width harness helpers for Flutter UI audit per-fix tests.
///
/// Provides reusable utilities to pump widgets at specific viewport widths
/// (phone/tablet/desktop) and assert no overflow occurs. Used by
/// `TestCoordinator`-authored tests to validate Requirement 5.2.
///
/// Usage:
/// ```dart
/// import 'package:dukanx/test/audit_helpers/audit_test_helpers.dart';
///
/// testWidgets('no overflow at phone width', (tester) async {
///   await assertNoOverflowAtWidth(tester, MyWidget(), kPhoneWidth);
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone viewport width (logical pixels) — narrow Android/iPhone.
const double kPhoneWidth = 360.0;

/// Tablet viewport width (logical pixels) — iPad / Android tablet portrait.
const double kTabletWidth = 768.0;

/// Desktop viewport width (logical pixels) — standard desktop window.
const double kDesktopWidth = 1280.0;

/// Default viewport height used when constraining width.
const double kDefaultTestHeight = 800.0;

/// Pumps [widget] inside a [MaterialApp] constrained to [width] logical pixels.
///
/// The widget is placed inside a [MediaQuery] override and a [SizedBox] so that
/// layout respects the target width. Returns after a full frame pump.
Future<void> pumpAtWidth(
  WidgetTester tester,
  Widget widget,
  double width, {
  double height = kDefaultTestHeight,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: MaterialApp(home: Scaffold(body: widget)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [widget] at [width] and asserts that `tester.takeException()` is null
/// (no RenderFlex overflow or other rendering exception).
///
/// This is the primary harness for Requirement 5.2 layout tests.
Future<void> assertNoOverflowAtWidth(
  WidgetTester tester,
  Widget widget,
  double width, {
  double height = kDefaultTestHeight,
}) async {
  await pumpAtWidth(tester, widget, width, height: height);
  expect(
    tester.takeException(),
    isNull,
    reason: 'Overflow detected at width $width logical pixels',
  );
}

/// Runs layout assertions at all three canonical widths (phone, tablet, desktop).
///
/// Convenience wrapper that calls [assertNoOverflowAtWidth] for each of
/// [kPhoneWidth], [kTabletWidth], and [kDesktopWidth].
Future<void> assertNoOverflowAtAllWidths(
  WidgetTester tester,
  Widget widget,
) async {
  for (final width in [kPhoneWidth, kTabletWidth, kDesktopWidth]) {
    await assertNoOverflowAtWidth(tester, widget, width);
  }
}
