// ============================================================================
// Task 2.2 — WIDGET TEST (standard flutter_test, NOT a property test)
// Feature: cross-platform-responsive-ui
// _Requirements: 1.6_
// ============================================================================
// Verifies the context helpers exposed by `ResponsiveContext on BuildContext`
// (from `package:dukanx/core/responsive/responsive_context.dart`) report the
// expected Form_Factor, orientation, keyboard visibility, Safe_Area insets,
// and Accessibility text scale when a probe widget is pumped under controlled
// `MediaQuery` values.
//
// Approach: a probe widget captures the live `BuildContext` from a `Builder`
// so that, after pumping, the extension getters can be evaluated against the
// `MediaQueryData` that was supplied. A `Directionality` wrapper is provided
// because `MediaQuery` alone is not a complete widget subtree for some text
// inheritance, and it keeps the probe minimal (no MaterialApp needed).
//
// Run: flutter test test/core/responsive/responsive_context_test.dart
// ============================================================================

import 'package:dukanx/core/responsive/responsive_breakpoints.dart';
import 'package:dukanx/core/responsive/responsive_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pumps a probe under the given [data] and returns the captured BuildContext
  // so the ResponsiveContext getters can be evaluated against that MediaQuery.
  Future<BuildContext> pumpProbe(
    WidgetTester tester,
    MediaQueryData data,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: data,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  group('ResponsiveContext — Form_Factor classification (Req 1.6)', () {
    testWidgets('mobile width (400x800) => mobile, isMobile, portrait', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(400, 800)),
      );

      expect(context.formFactor, FormFactor.mobile);
      expect(context.isMobile, isTrue);
      expect(context.isTablet, isFalse);
      expect(context.isDesktop, isFalse);
      expect(context.isPortrait, isTrue);
      expect(context.isLandscape, isFalse);
      expect(context.orientation, Orientation.portrait);
      expect(context.screenWidth, 400);
      expect(context.screenHeight, 800);
    });

    testWidgets('tablet portrait width (700x1000) => tablet', (tester) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(700, 1000)),
      );

      expect(context.formFactor, FormFactor.tablet);
      expect(context.isTablet, isTrue);
      expect(context.isMobile, isFalse);
      expect(context.isDesktop, isFalse);
      expect(context.isPortrait, isTrue);
    });

    testWidgets('tablet landscape width (800x600) => tablet, landscape', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(800, 600)),
      );

      expect(context.formFactor, FormFactor.tablet);
      expect(context.isTablet, isTrue);
      expect(context.isLandscape, isTrue);
      expect(context.isPortrait, isFalse);
      expect(context.orientation, Orientation.landscape);
    });

    testWidgets('desktop width (1400x900) => desktop, isDesktop, landscape', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(1400, 900)),
      );

      expect(context.formFactor, FormFactor.desktop);
      expect(context.isDesktop, isTrue);
      expect(context.isMobile, isFalse);
      expect(context.isTablet, isFalse);
      expect(context.isLandscape, isTrue);
      expect(context.screenWidth, 1400);
      expect(context.screenHeight, 900);
    });
  });

  group('ResponsiveContext — keyboard visibility (Req 1.6)', () {
    testWidgets('bottom viewInsets of 300 => keyboard visible, height 300', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(
          size: Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
      );

      expect(context.isKeyboardVisible, isTrue);
      expect(context.keyboardHeight, 300);
    });

    testWidgets('zero bottom viewInsets => keyboard hidden, height 0', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(400, 800)),
      );

      expect(context.isKeyboardVisible, isFalse);
      expect(context.keyboardHeight, 0);
    });
  });

  group('ResponsiveContext — safe-area insets (Req 1.6)', () {
    testWidgets('padding (top 44, bottom 34) => safeAreaPadding matches', (
      tester,
    ) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
      );

      expect(
        context.safeAreaPadding,
        const EdgeInsets.only(top: 44, bottom: 34),
      );
      expect(context.safeAreaPadding.top, 44);
      expect(context.safeAreaPadding.bottom, 34);
    });
  });

  group('ResponsiveContext — accessibility text scale (Req 1.6)', () {
    testWidgets('textScaler linear 1.5 => textScale == 1.5', (tester) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(
          size: Size(400, 800),
          textScaler: TextScaler.linear(1.5),
        ),
      );

      expect(context.textScale, 1.5);
    });

    testWidgets('default textScaler => textScale == 1.0', (tester) async {
      final context = await pumpProbe(
        tester,
        const MediaQueryData(size: Size(400, 800)),
      );

      expect(context.textScale, 1.0);
    });
  });
}
