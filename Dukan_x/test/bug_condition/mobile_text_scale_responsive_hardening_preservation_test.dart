/// Windows Preservation Golden Tests — Mobile Text-Scale & Responsive Hardening
///
/// **Validates: Requirements 11.2, 11.3**
///
/// These golden tests freeze the *desktop* (Windows-class) render path of every
/// widget touched by this spec. They follow the established golden convention in
/// `test/golden/widget_golden_test.dart` (`matchesGoldenFile`) and the
/// `test/bug_condition/*_preservation_test.dart` naming convention.
///
/// Why a desktop viewport proves Windows preservation:
///   * The text-scale clamp is a pure pass-through on Windows (design Property 2,
///     `clampTextScaleFactor(s, isWindows: true) == s`). At text scale 1.0 the
///     clamp is the identity on every platform, so a desktop render at scale 1.0
///     reflects the Windows render path byte-for-byte.
///   * Every hardening change is gated so that on desktop it is a no-op:
///       - `DesktopContentContainer` header is now wrapped in `SafeArea`, whose
///         insets are ZERO on desktop (Windows layout unchanged — R11.3).
///       - The shared `OverflowSafe*` primitives use `Flexible`/`Expanded`/
///         `FittedBox`, which lay out identically to the prior bare widgets when
///         there is ample width (desktop) at scale 1.0.
///   * If any fix accidentally shifts desktop pixels, the golden diff fails.
///
/// Surfaces are kept small, deterministic and isolated:
///   * The shared primitives (`OverflowSafeLabelValueRow`, `OverflowSafeInfoBanner`)
///     and the `DesktopContentContainer` header are rendered directly from
///     production code.
///   * The GST segmented control + "Period:" header and the Process Return search
///     hint live inside StatefulWidget screens that require heavy DI (database,
///     service locator, providers). Per the preservation intent we golden the
///     touched sub-widget in isolation, faithfully reproducing its desktop
///     (non-mobile) form with FIXED, locale-independent data.
///
/// Generate baselines:
///   flutter test --update-goldens test/bug_condition/mobile_text_scale_responsive_hardening_preservation_test.dart
/// Verify:
///   flutter test test/bug_condition/mobile_text_scale_responsive_hardening_preservation_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';

// ===========================================================================
// CONSTANTS
// ===========================================================================

/// A representative Windows desktop viewport. Wide enough that `context.isMobile`
/// is false (>= 600 logical px) so every touched widget renders its desktop form.
const Size kDesktopViewport = Size(1280, 800);

/// Baseline text scale. At 1.0 the clamp is the identity on all platforms, so the
/// render matches the Windows pass-through path exactly.
const double kBaselineScale = 1.0;

/// Pumps [child] at the fixed desktop viewport, device pixel ratio 1.0 and text
/// scale 1.0, inside a light Material app. Resets the view on tear-down so one
/// golden cannot leak sizing into the next.
Future<void> _pumpDesktopGolden(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = kDesktopViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        // Explicit scale 1.0 documents the Windows pass-through baseline.
        data: const MediaQueryData(
          size: kDesktopViewport,
          textScaler: TextScaler.linear(kBaselineScale),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Center(child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  // 1. Totals_Card — proforma_screen.dart (R4)
  // Touched widget: OverflowSafeLabelValueRow (Subtotal / Discount / Total).
  // Rendered from production code with fixed amounts.
  // =========================================================================
  group('Preservation (desktop): New Estimate Totals card', () {
    testWidgets('Totals card OverflowSafeLabelValueRow rows match golden', (
      tester,
    ) async {
      await _pumpDesktopGolden(
        tester,
        SizedBox(
          width: 420,
          child: Container(
            key: const Key('totals_card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OverflowSafeLabelValueRow(
                  label: 'Subtotal',
                  value: '\u20B91250',
                  labelStyle: TextStyle(color: Colors.black45),
                  valueStyle: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 12),
                OverflowSafeLabelValueRow(
                  label: 'Discount',
                  labelStyle: const TextStyle(color: Colors.green),
                  valueOverride: SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: '0',
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        prefixText: '- \u20B9',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 24),
                const OverflowSafeLabelValueRow(
                  label: 'Total',
                  value: '\u20B91250',
                  labelStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  valueStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('totals_card')),
        matchesGoldenFile('goldens/mtsr_totals_card_desktop.png'),
      );
    });
  });

  // =========================================================================
  // 2. PO_Info_Banner — buy_orders_screen.dart (R5)
  // Touched widget: OverflowSafeInfoBanner (rendered from production code with
  // the exact production icon/message/color).
  // =========================================================================
  group('Preservation (desktop): New Purchase Order info banner', () {
    testWidgets('PO OverflowSafeInfoBanner matches golden', (tester) async {
      await _pumpDesktopGolden(
        tester,
        const SizedBox(
          width: 600,
          child: OverflowSafeInfoBanner(
            key: Key('po_info_banner'),
            icon: Icons.info,
            message:
                'Purchase Orders are created as PENDING. You can convert them to Stock Entries later.',
            color: Colors.blue,
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('po_info_banner')),
        matchesGoldenFile('goldens/mtsr_po_info_banner_desktop.png'),
      );
    });
  });

  // =========================================================================
  // 3. App_Bar_Header — desktop_content_container.dart (R7, R11.3)
  // Touched widget: DesktopContentContainer header (now wrapped in SafeArea;
  // zero insets on desktop → Windows layout unchanged). Rendered from
  // production code. showBackButton:false keeps the surface deterministic
  // (no Navigator stack in isolation).
  // =========================================================================
  group('Preservation (desktop): DesktopContentContainer header', () {
    testWidgets('header with title + subtitle matches golden', (tester) async {
      await _pumpDesktopGolden(
        tester,
        const SizedBox(
          width: 900,
          height: 200,
          child: DesktopContentContainer(
            key: Key('app_bar_header'),
            title: 'Device Settings',
            subtitle: 'Configure device-specific preferences',
            showBackButton: false,
            child: Center(child: Text('Content')),
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('app_bar_header')),
        matchesGoldenFile('goldens/mtsr_app_bar_header_desktop.png'),
      );
    });
  });

  // =========================================================================
  // 4. GST_Reports_Screen — gst_reports_screen.dart (R6)
  // Touched widgets: the GSTR-1/GSTR-3B/HSN segmented control (labels wrapped
  // in FittedBox(scaleDown) + maxLines:1) and the "Period:" header (maxLines:1
  // + ellipsis). The host screen needs a database + service locator, so we
  // reproduce the desktop (non-mobile) form faithfully with a FIXED period
  // string (no DateTime.now()/locale dependency).
  // =========================================================================
  group('Preservation (desktop): GST Reports header + segmented control', () {
    testWidgets('segmented control + period header match golden', (
      tester,
    ) async {
      await _pumpDesktopGolden(
        tester,
        SizedBox(
          width: 700,
          child: Column(
            key: const Key('gst_header_block'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Non-mobile segmented control: icon + FittedBox(scaleDown) label.
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'gstr1',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('GSTR-1', maxLines: 1),
                    ),
                    icon: Icon(Icons.upload_file),
                  ),
                  ButtonSegment(
                    value: 'gstr3b',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('GSTR-3B', maxLines: 1),
                    ),
                    icon: Icon(Icons.summarize),
                  ),
                  ButtonSegment(
                    value: 'hsn',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('HSN', maxLines: 1),
                    ),
                    icon: Icon(Icons.category),
                  ),
                ],
                selected: const {'gstr1'},
                onSelectionChanged: (_) {},
              ),
              const SizedBox(height: 24),
              // Non-mobile "Period:" header row (fixed dates → deterministic).
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Period: 01 Apr 2025 - 30 Apr 2025',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('gst_header_block')),
        matchesGoldenFile('goldens/mtsr_gst_header_desktop.png'),
      );
    });
  });

  // =========================================================================
  // 5. Process Return search hint — return_inwards_screen.dart (R8)
  // Touched widget: the search hint row (Icon + Expanded(Text maxLines:1,
  // ellipsis, softWrap:false)). Reproduced faithfully in isolation.
  // =========================================================================
  group('Preservation (desktop): Process Return search hint', () {
    testWidgets('search hint row matches golden', (tester) async {
      await _pumpDesktopGolden(
        tester,
        SizedBox(
          width: 500,
          child: Container(
            key: const Key('process_return_search'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: const [
                Icon(Icons.search, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap to select a bill for return',
                    style: TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('process_return_search')),
        matchesGoldenFile('goldens/mtsr_process_return_search_desktop.png'),
      );
    });
  });
}
