/// Overflow assertion helpers for Flutter UI audit per-fix tests.
///
/// Provides reusable utilities to detect and assert the absence of overflow
/// exceptions after rendering a widget. Used by `TestCoordinator`-authored
/// tests to validate Requirement 5.4.
///
/// Usage:
/// ```dart
/// import 'package:dukanx/test/audit_helpers/audit_test_helpers.dart';
///
/// testWidgets('no overflow after fix', (tester) async {
///   await assertNoOverflowException(tester, MyFixedWidget());
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [widget] inside a minimal [MaterialApp] and asserts that
/// `tester.takeException()` returns null — meaning no RenderFlex overflow,
/// assertion error, or other rendering exception occurred.
///
/// This is the canonical overflow assertion for Requirement 5.4.
Future<void> assertNoOverflowException(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'An overflow or rendering exception was thrown',
  );
}

/// Pumps [widget] and returns `true` if an overflow/rendering exception
/// occurred, `false` otherwise.
///
/// Use this when you need to branch on whether overflow happened rather
/// than immediately failing the test.
Future<bool> pumpAndCheckOverflow(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  await tester.pumpAndSettle();
  final exception = tester.takeException();
  return exception != null;
}

/// Pumps [widget] at a given [size] and asserts no overflow.
///
/// Combines size-constrained pumping with the takeException assertion.
Future<void> assertNoOverflowAtSize(
  WidgetTester tester,
  Widget widget,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: Scaffold(body: widget)),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'Overflow at size ${size.width}x${size.height}',
  );
}
