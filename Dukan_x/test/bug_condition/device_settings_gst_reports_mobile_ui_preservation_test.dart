/// Preservation Property Tests — Device Settings & GST Reports Mobile UI Fix
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
///
/// Property 2: Preservation — Non-Mobile Layout And Business Logic Unchanged
///
/// These tests follow the OBSERVATION-FIRST methodology: they observe behavior
/// on the UNFIXED code for inputs where the bug condition does NOT hold
/// (`isBugCondition` returns false) and lock that behavior in so any future
/// regression is caught after the fix lands. The bug condition is
/// `(screen == DeviceSettingsScreen OR screen == GstReportsScreen)
///  AND width < 600`; the NON-bug cases captured here are:
///   * Either screen rendered at width >= 600 (tablet/desktop), including the
///     preserved viewports 768x1024, 1024x1366, 1920x1080.
///   * The exact 600px boundary (tablet, NOT mobile).
///   * All business-logic interactions on both screens at ANY width
///     (settings persistence, report-type / date selection) — these are
///     width-independent by construction.
///
/// Because the fix is gated behind `context.isMobile` (width < 600), every
/// assertion below must hold IDENTICALLY before and after the fix. We therefore
/// assert on STRUCTURAL discriminators of the non-mobile branch (the tax-rate
/// title + badge sharing one row, the GST segment icons, the GST period Row)
/// rather than on incidental text-overflow properties that the fix legitimately
/// adds as safety on mobile.
///
/// EXPECTED OUTCOME on UNFIXED code: ALL tests PASS (baseline to preserve).
///
/// PBT library: dartproptest ^0.2.1 (Gen.interval + forAll)
///
/// Run:
///   flutter test test/bug_condition/device_settings_gst_reports_mobile_ui_preservation_test.dart
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/features/gst/screens/gst_reports_screen.dart';
import 'package:dukanx/features/settings/presentation/screens/device_settings_screen.dart';
import 'package:dukanx/widgets/desktop/desktop_content_container.dart';

// ---------------------------------------------------------------------------
// Input space.
//
// Non-bug widths are >= 600 (the ResponsiveBreakpoints.mobileMax boundary).
// We sample random widths in [600, 2000] for the property runs and always pin
// the explicit boundary (600) and preserved viewport widths (768/1024/1920).
// ---------------------------------------------------------------------------
const int kNumRuns = 8;
const double kTallHeight =
    1400; // tall so the scroll view never vertically clips
const List<double> kPreservedWidths = <double>[600, 768, 1024, 1920];

/// Pumps [screen] inside a real `ProviderScope` + `MaterialApp` at the given
/// logical [width] (mirrors the exploration-test harness). Returns the list of
/// `FlutterError`s captured during build/layout/paint so callers can assert no
/// RenderFlex overflow occurred.
Future<List<FlutterErrorDetails>> _pumpScreenAtWidth(
  WidgetTester tester, {
  required Widget screen,
  required double width,
  double height = kTallHeight,
}) async {
  tester.view.physicalSize = Size(width, height);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    FlutterError.onError = oldHandler;
  }

  return errors;
}

Iterable<FlutterErrorDetails> _overflowErrors(
  List<FlutterErrorDetails> errors,
) => errors.where((e) => e.toString().contains('overflowed'));

/// Random non-mobile widths drawn from [600, 2000] for a property run, with the
/// preserved viewport widths always included so the boundary cases are covered.
List<double> _nonMobileWidths() {
  final widthGen = Gen.interval(600, 2000);
  final widths = <double>[...kPreservedWidths];
  forAll(
    (int w) {
      widths.add(w.toDouble());
      return true;
    },
    [widthGen],
    numRuns: kNumRuns,
  );
  return widths;
}

void main() {
  late AppDatabase testDb;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The shared theme provider lazily reads SharedPreferences in a microtask.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // GstReportsScreen resolves AppDatabase from the service locator in its
    // State field initializers; register an in-memory DB so it can build.
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
  // PROPERTY 2.1 — Device Settings non-mobile layout preserved at width >= 600
  //
  // Observation (unfixed): DeviceSettingsScreen has no mobile branch, so the
  // "Default Tax Rate (GST)" title and the "18%" badge sit in a single
  // `Row(spaceBetween)` — i.e. they share one horizontal line — and the
  // 0..28 (divisions 28) tax-rate slider renders. At width >= 600 this layout
  // MUST be preserved (the fix only stacks them vertically when width < 600).
  // **Validates: Requirements 3.1, 3.3**
  // =========================================================================
  group('Preservation: DeviceSettingsScreen non-mobile layout at width >= 600', () {
    testWidgets(
      'For random widths in [600, 2000] (+ 768/1024/1920): tax-rate title and '
      '"18%" badge share one row, slider is 0..28/28, no overflow',
      (tester) async {
        for (final width in _nonMobileWidths()) {
          final errors = await _pumpScreenAtWidth(
            tester,
            screen: const DeviceSettingsScreen(),
            width: width,
          );

          // All section/card titles render (no character-by-character collapse).
          expect(
            find.text('Default Tax Rate (GST)'),
            findsOneWidget,
            reason: 'Tax-rate title must render at width $width',
          );
          expect(find.text('Push Notifications'), findsOneWidget);
          expect(find.text('Auto Sync'), findsOneWidget);
          expect(find.text('Cloud Backup'), findsOneWidget);

          // Non-mobile discriminator: title + badge are horizontally aligned
          // (same Row). On the mobile stack they would be on separate lines.
          final titleCenter = tester.getCenter(
            find.text('Default Tax Rate (GST)'),
          );
          final badgeCenter = tester.getCenter(find.text('18%'));
          expect(
            (titleCenter.dy - badgeCenter.dy).abs(),
            lessThan(20.0),
            reason:
                'At width $width (non-mobile) the tax-rate title and "18%" '
                'badge must be on the same horizontal row.',
          );
          expect(
            badgeCenter.dx,
            greaterThan(titleCenter.dx),
            reason: 'The "18%" badge must sit to the right of the title (Row).',
          );

          // Tax-rate slider business config preserved (0..28, 28 divisions, 18).
          final slider = tester.widget<Slider>(find.byType(Slider));
          expect(slider.min, equals(0.0));
          expect(slider.max, equals(28.0));
          expect(slider.divisions, equals(28));
          expect(slider.value, equals(18.0));

          // No RenderFlex overflow at non-mobile widths.
          expect(
            _overflowErrors(errors),
            isEmpty,
            reason: 'DeviceSettingsScreen must not overflow at width $width',
          );
        }
      },
    );
  });

  // =========================================================================
  // PROPERTY 2.2 — GST Reports non-mobile layout preserved at width >= 600
  //
  // Observation (unfixed): the SegmentedButton keeps its icons on non-mobile
  // (`context.isMobile ? null : Icon(...)`), the period card renders as a `Row`
  // (Flexible period Text + inline quick-date chips), and all three report
  // labels are present. At width >= 600 this layout MUST be preserved (the fix
  // only drops icons / switches to a Column and a Wrap when width < 600).
  // **Validates: Requirements 3.2, 3.3**
  // =========================================================================
  group('Preservation: GstReportsScreen non-mobile layout at width >= 600', () {
    testWidgets(
      'For random widths in [600, 2000] (+ 768/1024/1920): segment icons '
      'present, all three labels render, period text present, no overflow',
      (tester) async {
        for (final width in _nonMobileWidths()) {
          final errors = await _pumpScreenAtWidth(
            tester,
            screen: const GstReportsScreen(),
            width: width,
          );

          // All three report-type labels render without clipping.
          expect(find.text('GSTR-1'), findsOneWidget);
          expect(find.text('GSTR-3B'), findsOneWidget);
          expect(find.text('HSN'), findsOneWidget);

          // Non-mobile discriminator: every segment defines an icon (mobile
          // drops them to null). We inspect the widget definition rather than
          // painted icons because Material 3 replaces the SELECTED segment's
          // icon with a checkmark. A null icon here means the mobile branch was
          // wrongly taken at width >= 600.
          final segButton = tester.widget<SegmentedButton<String>>(
            find.byType(SegmentedButton<String>),
          );
          expect(segButton.segments.length, equals(3));
          for (final seg in segButton.segments) {
            expect(
              seg.icon,
              isNotNull,
              reason:
                  'Non-mobile segment (${seg.value}) must keep its icon at '
                  'width $width',
            );
          }

          // Period header renders within bounds (non-mobile Row branch).
          expect(find.textContaining('Period:'), findsOneWidget);

          // Quick-date chips render.
          expect(find.text('Month'), findsOneWidget);
          expect(find.text('Last Month'), findsOneWidget);
          expect(find.text('Quarter'), findsOneWidget);

          // No RenderFlex overflow at non-mobile widths.
          expect(
            _overflowErrors(errors),
            isEmpty,
            reason: 'GstReportsScreen must not overflow at width $width',
          );
        }
      },
    );
  });

  // =========================================================================
  // PROPERTY 2.3 — The exact 600px boundary uses the NON-mobile layout
  //
  // Observation: ResponsiveBreakpoints classify 600 as tablet (width < 600 is
  // false). Both screens MUST therefore use their non-mobile layout at exactly
  // 600px — the boundary belongs to preservation, not the fix.
  // **Validates: Requirements 3.1, 3.2, 3.3**
  // =========================================================================
  group('Preservation: 600px boundary uses non-mobile layout', () {
    testWidgets('context.isMobile is false at exactly 600px', (tester) async {
      tester.view.physicalSize = const Size(600, kTallHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      late bool isMobileAt600;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobileAt600 = context.isMobile;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        isMobileAt600,
        isFalse,
        reason: '600px is tablet (width < 600 is false), so isMobile is false.',
      );
    });

    testWidgets('DeviceSettingsScreen at 600px keeps the tax-rate Row layout', (
      tester,
    ) async {
      await _pumpScreenAtWidth(
        tester,
        screen: const DeviceSettingsScreen(),
        width: 600,
      );

      final titleCenter = tester.getCenter(find.text('Default Tax Rate (GST)'));
      final badgeCenter = tester.getCenter(find.text('18%'));
      expect(
        (titleCenter.dy - badgeCenter.dy).abs(),
        lessThan(20.0),
        reason: 'At 600px the title and "18%" badge must share one row.',
      );
    });

    testWidgets(
      'GstReportsScreen at 600px keeps the segment icons (non-mobile)',
      (tester) async {
        await _pumpScreenAtWidth(
          tester,
          screen: const GstReportsScreen(),
          width: 600,
        );

        expect(find.byType(SegmentedButton<String>), findsOneWidget);
        final segButton = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        expect(segButton.segments.length, equals(3));
        for (final seg in segButton.segments) {
          expect(
            seg.icon,
            isNotNull,
            reason:
                'At 600px (non-mobile) segment ${seg.value} must keep '
                'its icon.',
          );
        }
      },
    );
  });

  // =========================================================================
  // PROPERTY 2.4 — Device Settings business logic is width-independent
  //
  // Observation: toggles, backup-frequency selection, and the tax-rate slider
  // config behave the same regardless of width. We exercise each interaction at
  // a mobile width (360) and a non-mobile width (1400) and assert identical
  // outcomes — confirming the fix must not couple any logic to width.
  // **Validates: Requirement 3.4**
  // =========================================================================
  group(
    'Preservation: DeviceSettingsScreen business logic is width-independent',
    () {
      testWidgets(
        'toggling a switch flips its value identically at 360 and 1400',
        (tester) async {
          for (final width in <double>[360, 1400]) {
            await _pumpScreenAtWidth(
              tester,
              screen: const DeviceSettingsScreen(),
              width: width,
            );

            final switchFinder = find.byType(Switch).first;
            final before = tester.widget<Switch>(switchFinder).value;
            await tester.tap(switchFinder);
            await tester.pump();
            final after = tester.widget<Switch>(switchFinder).value;

            expect(
              after,
              equals(!before),
              reason:
                  'Switch must flip from $before to ${!before} at width $width',
            );
          }
        },
      );

      testWidgets(
        'selecting a backup frequency persists identically at 360 and 1400',
        (tester) async {
          for (final width in <double>[360, 1400]) {
            await _pumpScreenAtWidth(
              tester,
              // Unique key per width forces a fresh State so selection from a
              // previous width does not leak into this one.
              screen: DeviceSettingsScreen(key: ValueKey('ds-bf-$width')),
              width: width,
            );

            // Default subtitle is "Daily".
            expect(find.text('Daily'), findsOneWidget);

            // Opening the modal bottom sheet trips a benign debug-only
            // framework warning (ListTile inside a DecoratedBox). It is
            // app-rendering noise unrelated to width and to this fix, so
            // suppress only that exact message while still surfacing any other
            // error.
            final prevHandler = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('ListTile background color')) {
                return;
              }
              prevHandler?.call(details);
            };
            try {
              // Open the backup-frequency bottom sheet and choose "Weekly".
              await tester.tap(find.text('Backup Frequency'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Weekly').last);
              await tester.pumpAndSettle();
            } finally {
              FlutterError.onError = prevHandler;
            }

            expect(
              find.text('Weekly'),
              findsOneWidget,
              reason:
                  'Backup frequency must persist as "Weekly" at width $width',
            );
            expect(
              find.text('Daily'),
              findsNothing,
              reason:
                  'Previous "Daily" subtitle must be replaced at width $width',
            );
          }
        },
      );

      testWidgets('tax-rate slider config is identical at 360 and 1400', (
        tester,
      ) async {
        Slider sliderAt(double w) {
          return tester.widget<Slider>(find.byType(Slider));
        }

        await _pumpScreenAtWidth(
          tester,
          screen: const DeviceSettingsScreen(),
          width: 360,
        );
        final mobileSlider = sliderAt(360);

        await _pumpScreenAtWidth(
          tester,
          screen: const DeviceSettingsScreen(),
          width: 1400,
        );
        final desktopSlider = sliderAt(1400);

        expect(mobileSlider.min, equals(desktopSlider.min));
        expect(mobileSlider.max, equals(desktopSlider.max));
        expect(mobileSlider.divisions, equals(desktopSlider.divisions));
        expect(mobileSlider.value, equals(desktopSlider.value));
        // And matches the documented domain (0..28, divisions 28, initial 18).
        expect(desktopSlider.min, equals(0.0));
        expect(desktopSlider.max, equals(28.0));
        expect(desktopSlider.divisions, equals(28));
        expect(desktopSlider.value, equals(18.0));
      });
    },
  );

  // =========================================================================
  // PROPERTY 2.5 — GST Reports business logic is width-independent
  //
  // Observation: report-type selection and the quick-date chips compute the
  // same result regardless of width. The date range produced by a quick-date
  // chip is the input that drives report generation / JSON-CSV export, so its
  // width-independence preserves the generation behavior. (Full generation +
  // export E2E is covered by the integration tests in the design; here we lock
  // the width-independence property the fix must not break.)
  // **Validates: Requirements 3.5**
  // =========================================================================
  group('Preservation: GstReportsScreen business logic is width-independent', () {
    testWidgets('report-type selection updates identically at 360 and 1400', (
      tester,
    ) async {
      for (final width in <double>[360, 1400]) {
        await _pumpScreenAtWidth(
          tester,
          // Unique key per width forces a fresh State so selection from a
          // previous width does not leak into this one.
          screen: GstReportsScreen(key: ValueKey('gst-rt-$width')),
          width: width,
        );

        // Default selection is gstr1.
        var button = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        expect(button.selected, equals(<String>{'gstr1'}));

        // Select GSTR-3B.
        await tester.tap(find.text('GSTR-3B'));
        await tester.pump();
        button = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        expect(
          button.selected,
          equals(<String>{'gstr3b'}),
          reason: 'Report type must switch to gstr3b at width $width',
        );

        // Select HSN.
        await tester.tap(find.text('HSN'));
        await tester.pump();
        button = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        expect(
          button.selected,
          equals(<String>{'hsn'}),
          reason: 'Report type must switch to hsn at width $width',
        );
      }
    });

    testWidgets(
      'the "Quarter" quick-date chip computes the same period at 360 and 1400',
      (tester) async {
        String periodAtWidth() {
          final text = tester.widget<Text>(find.textContaining('Period:'));
          return text.data ?? '';
        }

        // Mobile width.
        await _pumpScreenAtWidth(
          tester,
          screen: GstReportsScreen(key: const ValueKey('gst-q-mobile')),
          width: 360,
        );
        await tester.tap(find.text('Quarter'));
        await tester.pump();
        final mobilePeriod = periodAtWidth();

        // Non-mobile width.
        await _pumpScreenAtWidth(
          tester,
          screen: GstReportsScreen(key: const ValueKey('gst-q-desktop')),
          width: 1400,
        );
        await tester.tap(find.text('Quarter'));
        await tester.pump();
        final desktopPeriod = periodAtWidth();

        expect(
          mobilePeriod,
          equals(desktopPeriod),
          reason:
              'The quarter period range must be identical regardless of width '
              '(mobile="$mobilePeriod", desktop="$desktopPeriod").',
        );
        expect(mobilePeriod, startsWith('Period:'));
      },
    );
  });

  // =========================================================================
  // PROPERTY 2.6 — Shared header component unchanged (other screens unaffected)
  //
  // Observation: the fix is scoped to the two screen bodies and MUST NOT modify
  // the shared `DesktopContentContainer`, which every other screen (and the
  // sibling-spec screens) relies on. At width >= 600 the shared header renders a
  // 20px title; locking this proves the shared component is untouched.
  // **Validates: Requirements 3.6, 3.7**
  // =========================================================================
  group(
    'Preservation: shared DesktopContentContainer header at width >= 600',
    () {
      testWidgets(
        'For random widths in [600, 2000] (+ 768/1024/1920): a generic title '
        'renders at fontSize 20 with no overflow',
        (tester) async {
          for (final width in _nonMobileWidths()) {
            tester.view.physicalSize = Size(width, kTallHeight);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());
            addTearDown(() => tester.view.resetDevicePixelRatio());

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: width,
                    height: kTallHeight,
                    child: const DesktopContentContainer(
                      title: 'Some Other Screen',
                      showBackButton: false,
                      child: Center(child: Text('Content')),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final titleFinder = find.text('Some Other Screen');
            expect(
              titleFinder,
              findsOneWidget,
              reason: 'Shared header title must render at width $width',
            );
            final titleWidget = tester.widget<Text>(titleFinder);
            expect(
              titleWidget.style?.fontSize,
              equals(20),
              reason:
                  'Shared header title must be 20px at non-mobile width $width',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'Shared header must not overflow at width $width',
            );
          }
        },
      );
    },
  );
}
