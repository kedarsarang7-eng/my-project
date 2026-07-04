/// Golden test helpers for Flutter UI audit per-fix tests.
///
/// Provides reusable utilities to pump widgets with light/dark themes and
/// compare against golden files. Used by `TestCoordinator`-authored tests
/// to validate Requirement 5.3.
///
/// Usage:
/// ```dart
/// import 'package:dukanx/test/audit_helpers/audit_test_helpers.dart';
///
/// testWidgets('light golden', (tester) async {
///   await pumpLightGolden(tester, MyWidget(), 'my_widget_light');
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [widget] in a [MaterialApp] configured with the given [brightness].
///
/// Use this to isolate a widget under a specific theme mode for testing.
/// The wrapper provides a minimal [MaterialApp] scaffold so the widget tree
/// has access to [Theme], [MediaQuery], and [Navigator].
Widget wrapWithTheme(
  Widget widget, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(body: widget),
  );
}

/// Pumps [widget] with a light theme and matches against the golden file
/// named `goldens/<name>.png`.
///
/// Call within a `testWidgets` body. The golden file path is relative to
/// the test file's directory.
Future<void> pumpLightGolden(
  WidgetTester tester,
  Widget widget,
  String name,
) async {
  await tester.pumpWidget(wrapWithTheme(widget, brightness: Brightness.light));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Pumps [widget] with a dark theme and matches against the golden file
/// named `goldens/${name}_dark.png`.
///
/// Call within a `testWidgets` body. The golden file path is relative to
/// the test file's directory.
Future<void> pumpDarkGolden(
  WidgetTester tester,
  Widget widget,
  String name,
) async {
  await tester.pumpWidget(wrapWithTheme(widget, brightness: Brightness.dark));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${name}_dark.png'),
  );
}

/// Pumps [widget] and produces golden assertions for both light and dark modes.
///
/// Convenience wrapper calling [pumpLightGolden] then [pumpDarkGolden].
Future<void> pumpBothGoldens(
  WidgetTester tester,
  Widget widget,
  String name,
) async {
  await pumpLightGolden(tester, widget, name);
  await pumpDarkGolden(tester, widget, name);
}
