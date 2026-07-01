// ============================================================================
// WIDGET TEST HARNESS — Layer 2 Widget Test Suite Scaffold
// ============================================================================
// Provides reusable helpers for widget testing across all 460+ screens and 19
// business types. Tests reside under test/widget/<type>/<module>/.
//
// Helpers:
//   - pumpScreen: wraps a screen in MaterialApp with optional providers
//   - testBuildAndFirstFrame: asserts no exceptions and no layout overflow
//   - testInputValidation: asserts valid inputs accepted, invalid inputs show error
//   - testStates: asserts loading/empty/error/success state rendering
//   - goldenTest: golden_toolkit snapshot with ≥1-pixel diff = failure
//
// Golden Comparison Behavior:
//   A golden test produces a reference PNG per screen per business type.
//   If the rendered output differs from the approved baseline by ≥1 pixel,
//   the test FAILS and records the screen name + business type in the failure
//   message. This ensures visual regressions are caught at the PR level.
//
// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

// ─── pumpScreen ─────────────────────────────────────────────────────────────

/// Wraps [screen] in a [MaterialApp] with a [Scaffold] for widget testing.
///
/// Optionally accepts [theme], [locale], and [surfaceSize] for golden tests.
/// The widget is wrapped in a [MediaQuery] with the given [surfaceSize] to
/// simulate different device dimensions.
Widget buildTestableScreen({
  required Widget screen,
  ThemeData? theme,
  Locale? locale,
  Size surfaceSize = const Size(412, 892), // default Pixel 6 size
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    locale: locale,
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: screen),
  );
}

/// Pumps a screen widget wrapped in the standard test shell.
///
/// Returns after a single frame has been rendered.
/// Set [settle] to false for screens with infinite animations (e.g. loading
/// spinners) where pumpAndSettle would time out.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  ThemeData? theme,
  Locale? locale,
  Size surfaceSize = const Size(412, 892),
  bool settle = true,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  await tester.pumpWidget(
    buildTestableScreen(
      screen: screen,
      theme: theme,
      locale: locale,
      surfaceSize: surfaceSize,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

// ─── testBuildAndFirstFrame ─────────────────────────────────────────────────

/// Asserts that [screen] builds and completes its first frame without
/// throwing an exception and without reporting layout overflow errors.
///
/// Validates Requirement 3.1:
///   "THE Widget_Test_Suite SHALL assert that the Screen builds and completes
///    its first frame without throwing an exception and without reporting
///    layout overflow errors."
void testBuildAndFirstFrame({
  required String screenName,
  required String businessType,
  required Widget Function() screenBuilder,
  ThemeData? theme,
  Size surfaceSize = const Size(412, 892),
}) {
  testWidgets(
    '$screenName [$businessType] — builds and first frame without exceptions or overflow',
    (WidgetTester tester) async {
      // Pump the screen; pumpAndSettle catches overflow via FlutterError
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await pumpScreen(
          tester,
          screen: screenBuilder(),
          theme: theme,
          surfaceSize: surfaceSize,
          settle:
              false, // We only need the first frame, not animation completion
        );
      } finally {
        FlutterError.onError = oldHandler;
      }

      // Filter for overflow errors specifically
      final overflowErrors = errors.where(
        (e) => e.toString().contains('overflowed'),
      );

      expect(
        overflowErrors,
        isEmpty,
        reason: '$screenName [$businessType] has layout overflow errors',
      );

      // Assert no other unhandled exceptions during build
      final buildErrors = errors.where(
        (e) => !e.toString().contains('overflowed'),
      );
      expect(
        buildErrors,
        isEmpty,
        reason: '$screenName [$businessType] threw exceptions during build',
      );
    },
  );
}

// ─── testInputValidation ────────────────────────────────────────────────────

/// Test configuration for a single input field validation scenario.
class InputFieldTestConfig {
  /// Key to find the input field widget.
  final Key fieldKey;

  /// A valid value that should be accepted without error.
  final String validValue;

  /// An invalid value that should trigger a validation error.
  final String invalidValue;

  /// The expected error text when invalid input is provided.
  final String expectedErrorText;

  /// Human-readable field name for test descriptions.
  final String fieldName;

  const InputFieldTestConfig({
    required this.fieldKey,
    required this.validValue,
    required this.invalidValue,
    required this.expectedErrorText,
    required this.fieldName,
  });
}

/// Asserts that input fields accept valid values without error and reject
/// invalid values with a visible validation indicator.
///
/// Validates Requirements 3.2, 3.3:
///   3.2: "valid input values… accepts the input and reports no validation error"
///   3.3: "input that violates a defined validation rule… rejects the input and
///         displays a visible validation error indicator"
void testInputValidation({
  required String screenName,
  required String businessType,
  required Widget Function() screenBuilder,
  required List<InputFieldTestConfig> fields,
  Key? submitButtonKey,
  ThemeData? theme,
  Size surfaceSize = const Size(412, 892),
}) {
  group('$screenName [$businessType] — input validation', () {
    for (final field in fields) {
      testWidgets(
        '${field.fieldName} accepts valid input "${field.validValue}"',
        (WidgetTester tester) async {
          await pumpScreen(
            tester,
            screen: screenBuilder(),
            theme: theme,
            surfaceSize: surfaceSize,
          );

          await tester.enterText(find.byKey(field.fieldKey), field.validValue);
          if (submitButtonKey != null) {
            await tester.tap(find.byKey(submitButtonKey));
          }
          await tester.pumpAndSettle();

          expect(
            find.text(field.expectedErrorText),
            findsNothing,
            reason:
                '${field.fieldName} should accept "${field.validValue}" without error',
          );
        },
      );

      testWidgets(
        '${field.fieldName} rejects invalid input "${field.invalidValue}"',
        (WidgetTester tester) async {
          await pumpScreen(
            tester,
            screen: screenBuilder(),
            theme: theme,
            surfaceSize: surfaceSize,
          );

          await tester.enterText(
            find.byKey(field.fieldKey),
            field.invalidValue,
          );
          if (submitButtonKey != null) {
            await tester.tap(find.byKey(submitButtonKey));
          }
          await tester.pumpAndSettle();

          expect(
            find.text(field.expectedErrorText),
            findsOneWidget,
            reason:
                '${field.fieldName} should show "${field.expectedErrorText}" for invalid input',
          );
        },
      );
    }
  });
}

// ─── testStates ─────────────────────────────────────────────────────────────

/// Configuration for testing a screen's visual states.
class StateTestConfig {
  /// The state name (e.g., 'loading', 'empty', 'error', 'success').
  final String stateName;

  /// Builder that produces the screen in the desired state.
  final Widget Function() screenBuilder;

  /// Finders that should be present in this state.
  final List<Finder> expectedWidgets;

  /// Optional finders that should NOT be present in this state.
  final List<Finder> absentWidgets;

  /// Whether to call pumpAndSettle (false for states with infinite animations).
  final bool settle;

  const StateTestConfig({
    required this.stateName,
    required this.screenBuilder,
    required this.expectedWidgets,
    this.absentWidgets = const [],
    this.settle = true,
  });
}

/// Asserts that a screen renders the correct widgets for each defined state
/// (loading, empty, error, success).
///
/// Validates Requirement 3.4:
///   "WHEN a Screen defines any of the loading, empty, error, or success states,
///    THE Widget_Test_Suite SHALL assert, for each such defined state, that the
///    Screen renders the widgets corresponding to that state."
void testStates({
  required String screenName,
  required String businessType,
  required List<StateTestConfig> states,
  ThemeData? theme,
  Size surfaceSize = const Size(412, 892),
}) {
  group('$screenName [$businessType] — state rendering', () {
    for (final state in states) {
      testWidgets('${state.stateName} state renders expected widgets', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          screen: state.screenBuilder(),
          theme: theme,
          surfaceSize: surfaceSize,
          settle: state.settle,
        );

        for (final finder in state.expectedWidgets) {
          expect(
            finder,
            findsAtLeastNWidgets(1),
            reason:
                '$screenName [${state.stateName}] should render expected widget',
          );
        }

        for (final finder in state.absentWidgets) {
          expect(
            finder,
            findsNothing,
            reason:
                '$screenName [${state.stateName}] should NOT render this widget',
          );
        }
      });
    }
  });
}

// ─── goldenTest ─────────────────────────────────────────────────────────────

/// Golden snapshot comparison behavior:
///
/// - Produces one golden PNG per screen per business type
/// - Golden files are stored under `test/widget/<type>/<module>/goldens/`
/// - A difference of ≥1 pixel from the approved baseline FAILS the test
/// - On failure, the test message records: screen name + business type
/// - To update baselines: `flutter test --update-goldens`
///
/// Validates Requirements 3.5, 3.6:
///   3.5: "at least one golden snapshot test, using golden_toolkit, for every
///         Screen under each Business_Type"
///   3.6: "IF a golden snapshot differs from its approved baseline by one or
///         more pixels, THEN… fail the affected test and record the name of
///         the differing Screen and its Business_Type"
void goldenScreenTest({
  required String screenName,
  required String businessType,
  required String module,
  required Widget Function() screenBuilder,
  ThemeData? theme,
  Size surfaceSize = const Size(412, 892),
  String? goldenFileName,
}) {
  testGoldens('$screenName [$businessType] — golden snapshot', (
    WidgetTester tester,
  ) async {
    await loadAppFonts();

    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      buildTestableScreen(
        screen: screenBuilder(),
        theme: theme,
        surfaceSize: surfaceSize,
      ),
    );
    await tester.pumpAndSettle();

    // File name follows: <screen_snake_case>_<type>
    // NOTE: golden_toolkit appends .png automatically — do NOT include extension
    final fileName =
        goldenFileName ?? '${_toSnakeCase(screenName)}_$businessType';

    // ≥1-pixel diff fails; records screen + type in failure message
    await screenMatchesGolden(
      tester,
      fileName,
      // golden_toolkit uses a tolerance of 0 by default — any pixel diff fails
    );
  });
}

/// Converts PascalCase or camelCase to snake_case.
String _toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      )
      .replaceAll(RegExp(r'^_'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .toLowerCase();
}
