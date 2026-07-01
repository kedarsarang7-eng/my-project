/// Bug Condition Exploration Test — Device Settings & GST Reports Mobile UI Fix
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9**
///
/// Property 1: Bug Condition — Mobile Layout Fits Without Overflow Or Clipping
///
/// This test encodes the EXPECTED (correct, post-fix) behavior for the two
/// affected screens at mobile viewport widths (< 600px). On the UNFIXED code
/// these assertions FAIL — proving the overflow/clipping bug exists. After the
/// fix lands (gated behind `context.isMobile`), the SAME test PASSES — proving
/// the bug is resolved.
///
/// Scoped PBT approach: instead of a random generator we iterate over the
/// concrete failing mobile widths (360, 393, 412) from the bug report so the
/// failures are deterministic and reproducible. The bug condition is:
///   (screen == DeviceSettingsScreen OR screen == GstReportsScreen)
///   AND width < 600 AND layoutOverflowsOrClips(screen, width)
///
/// Run:
///   flutter test test/bug_condition/device_settings_gst_reports_mobile_ui_exploration_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/features/settings/presentation/screens/device_settings_screen.dart';
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';

// ---------------------------------------------------------------------------
// Scoped input space: the concrete failing mobile widths from the bug report.
// All are < 600 (the ResponsiveBreakpoints.mobileMax boundary), so the mobile
// bug condition holds for every case.
// ---------------------------------------------------------------------------
const List<double> kMobileWidths = <double>[360, 393, 412];
const double kMobileHeight = 800;

/// Pumps [screen] inside a real `ProviderScope` + `MaterialApp` at the given
/// logical [width], capturing any `FlutterError`s (RenderFlex overflow, etc.)
/// raised during build/layout/paint instead of letting the binding fail the
/// test immediately. Returns the collected error details.
Future<List<FlutterErrorDetails>> _pumpScreenAtWidth(
  WidgetTester tester, {
  required Widget screen,
  required double width,
}) async {
  tester.view.physicalSize = Size(width, kMobileHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  final errors = <FlutterErrorDetails>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details);

  try {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: screen),
        ),
      ),
    );
    // A couple of frames so layout/paint runs (overflow is reported on paint)
    // and the theme provider's deferred loadSettings() microtask is flushed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    FlutterError.onError = oldHandler;
  }

  return errors;
}

/// Filters [errors] down to RenderFlex / layout overflow reports.
Iterable<FlutterErrorDetails> _overflowErrors(
  List<FlutterErrorDetails> errors,
) => errors.where((e) => e.toString().contains('overflowed'));

void main() {
  late AppDatabase testDb;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The shared theme provider lazily reads SharedPreferences in a microtask;
    // provide an in-memory store so that read does not throw during the test.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // GstReportsScreen constructs GST services in its State field initializers,
    // which resolve `AppDatabase` from the service locator. Register an
    // in-memory database so the real screen can build in the test harness.
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
    sl.allowReassignment = true;
    if (sl.isRegistered<AppDatabase>()) {
      sl.unregister<AppDatabase>();
    }
    sl.registerSingleton<AppDatabase>(testDb);
  });

  tearDownAll(() async {
    if (sl.isRegistered<AppDatabase>()) {
      sl.unregister<AppDatabase>();
    }
    await testDb.close();
  });

  // =========================================================================
  // DEVICE SETTINGS — Bug Condition (screen == DeviceSettingsScreen, w < 600)
  // =========================================================================
  group('Bug Condition: DeviceSettingsScreen at mobile widths', () {
    for (final width in kMobileWidths) {
      testWidgets(
        'at ${width.toInt()}px MUST lay out with no RenderFlex overflow '
        '(covers Req 1.4, 1.5)',
        (tester) async {
          final errors = await _pumpScreenAtWidth(
            tester,
            screen: const DeviceSettingsScreen(),
            width: width,
          );

          // EXPECTED (post-fix): the "Default Tax Rate (GST)" row and the
          // toggle rows fit within the viewport with no overflow.
          // UNFIXED: the spaceBetween Row with a non-Flexible title +
          // "18%" badge overflows the narrow viewport → this FAILS.
          expect(
            _overflowErrors(errors),
            isEmpty,
            reason:
                'DeviceSettingsScreen at ${width.toInt()}px reported a '
                'RenderFlex overflow. The "Default Tax Rate (GST)" header Row '
                '(spaceBetween, non-Flexible title + "18%" badge) exceeds the '
                'available width on mobile.',
          );
        },
      );
    }

    testWidgets(
      'tax-rate title "Default Tax Rate (GST)" MUST be single-line + ellipsis '
      'at 360px (covers Req 1.1, 1.4)',
      (tester) async {
        await _pumpScreenAtWidth(
          tester,
          screen: const DeviceSettingsScreen(),
          width: 360,
        );

        final titleFinder = find.text('Default Tax Rate (GST)');
        expect(titleFinder, findsOneWidget);

        final titleWidget = tester.widget<Text>(titleFinder);
        // EXPECTED (post-fix): bounded to a single line with ellipsis so it
        // never renders character-by-character / overflows.
        // UNFIXED: this Text has no maxLines/overflow set → FAILS.
        expect(
          titleWidget.maxLines,
          equals(1),
          reason:
              'Tax-rate title must be capped to a single line (maxLines: 1) on '
              'mobile. Unfixed code leaves maxLines null, allowing awkward '
              'character-by-character wrapping / overflow.',
        );
        expect(
          titleWidget.overflow,
          equals(TextOverflow.ellipsis),
          reason:
              'Tax-rate title must use TextOverflow.ellipsis on mobile. '
              'Unfixed code leaves overflow unset.',
        );
      },
    );

    testWidgets(
      'switch-tile subtitle "Sync data automatically when online" MUST be '
      'bounded (<=2 lines + ellipsis) at 360px (covers Req 1.2, 1.5)',
      (tester) async {
        await _pumpScreenAtWidth(
          tester,
          screen: const DeviceSettingsScreen(),
          width: 360,
        );

        final subtitleFinder = find.text('Sync data automatically when online');
        expect(subtitleFinder, findsOneWidget);

        final subtitleWidget = tester.widget<Text>(subtitleFinder);
        // EXPECTED (post-fix): subtitle wraps to at most two lines with
        // ellipsis. UNFIXED: maxLines/overflow are unset → FAILS.
        expect(
          subtitleWidget.maxLines,
          isNotNull,
          reason:
              'Toggle subtitle must cap its line count (maxLines set) on '
              'mobile to wrap cleanly. Unfixed code leaves maxLines null.',
        );
        expect(
          subtitleWidget.maxLines,
          lessThanOrEqualTo(2),
          reason: 'Toggle subtitle must wrap to at most two lines on mobile.',
        );
        expect(
          subtitleWidget.overflow,
          equals(TextOverflow.ellipsis),
          reason:
              'Toggle subtitle must use TextOverflow.ellipsis on mobile. '
              'Unfixed code leaves overflow unset.',
        );
      },
    );
  });

  // =========================================================================
  // GST REPORTS — Bug Condition (screen == GstReportsScreen, w < 600)
  // =========================================================================
  group('Bug Condition: GstReportsScreen at mobile widths', () {
    for (final width in kMobileWidths) {
      testWidgets(
        'at ${width.toInt()}px MUST lay out with no RenderFlex overflow '
        '(covers Req 1.6, 1.7)',
        (tester) async {
          final errors = await _pumpScreenAtWidth(
            tester,
            screen: const GstReportsScreen(),
            width: width,
          );

          // EXPECTED (post-fix): the period header and the segmented control
          // fit within the viewport with no overflow.
          // UNFIXED: the mobile period Row holds a non-Flexible Text and the
          // SegmentedButton keeps intrinsic sizing → overflow/clipping → FAILS.
          expect(
            _overflowErrors(errors),
            isEmpty,
            reason:
                'GstReportsScreen at ${width.toInt()}px reported a RenderFlex '
                'overflow. The period header Text (non-Flexible in the mobile '
                'Row) and/or the GSTR-1/GSTR-3B/HSN segmented control exceed '
                'the available width on mobile.',
          );
        },
      );
    }

    testWidgets(
      'period header "Period: …" MUST be bounded with ellipsis at 393px '
      '(covers Req 1.6)',
      (tester) async {
        await _pumpScreenAtWidth(
          tester,
          screen: const GstReportsScreen(),
          width: 393,
        );

        // The period text is "Period: dd/mm/yyyy - dd/mm/yyyy"; match the
        // stable prefix so the dynamic dates do not break the finder.
        final periodFinder = find.textContaining('Period:');
        expect(periodFinder, findsOneWidget);

        final periodWidget = tester.widget<Text>(periodFinder);
        // EXPECTED (post-fix): in the mobile Column branch the period Text is
        // wrapped in Expanded with overflow: ellipsis (mirroring the non-mobile
        // branch). UNFIXED: the mobile branch sets no overflow → FAILS.
        expect(
          periodWidget.overflow,
          equals(TextOverflow.ellipsis),
          reason:
              'GST period header must use TextOverflow.ellipsis on mobile so '
              'it stays within the screen bounds. Unfixed mobile branch leaves '
              'overflow unset, causing right-edge overflow at 393px.',
        );
      },
    );

    testWidgets(
      'segmented control labels GSTR-1 / GSTR-3B / HSN MUST all be present '
      'without clipping at 360px (covers Req 1.7)',
      (tester) async {
        final errors = await _pumpScreenAtWidth(
          tester,
          screen: const GstReportsScreen(),
          width: 360,
        );

        // All three labels must be laid out (readable, not clipped away).
        expect(find.text('GSTR-1'), findsOneWidget);
        expect(find.text('GSTR-3B'), findsOneWidget);
        expect(find.text('HSN'), findsOneWidget);

        // EXPECTED (post-fix): the segmented control is sized full-width on
        // mobile so the three labels share the row without clipping/overflow.
        // UNFIXED: intrinsic sizing under 360px clips/overflows → FAILS.
        expect(
          _overflowErrors(errors),
          isEmpty,
          reason:
              'GST segmented control (GSTR-1 / GSTR-3B / HSN) overflowed at '
              '360px. On mobile it must be sized responsively (full-width) so '
              'all three labels fit without clipping.',
        );
      },
    );
  });
}
