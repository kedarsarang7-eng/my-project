/// MobileShopTheme Tests — Light/Dark Theme Tokens (Task 16.4)
///
/// Validates: Requirements 11.2, 11.6
/// - Light theme produces distinct non-null color tokens
/// - Dark theme produces distinct non-null color tokens
/// - Light and dark themes differ (dark backgrounds need lighter colors)
/// - Typography tokens are non-null with expected properties
/// - ThemeExtension copyWith and lerp behave correctly
/// - MobileShopTheme.of fallback returns light theme when unregistered
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/theme/mobile_shop_theme.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Light Theme Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopTheme.light()', () {
    late MobileShopTheme theme;

    setUp(() {
      theme = MobileShopTheme.light();
    });

    test('all status colors are non-null and distinct', () {
      final statusColors = [
        theme.statusReceived,
        theme.statusInProgress,
        theme.statusCompleted,
        theme.statusOverdue,
        theme.statusPending,
        theme.statusCancelled,
      ];

      // All non-null (type system guarantees, but verify set size = distinct)
      expect(
        statusColors.toSet().length,
        statusColors.length,
        reason: 'All status colors should be distinct',
      );
    });

    test('sync state colors are present and meaningful', () {
      expect(theme.syncConfirmed, isNotNull);
      expect(theme.syncPending, isNotNull);
      expect(theme.syncConflict, isNotNull);
      // Confirmed and conflict should differ
      expect(theme.syncConfirmed, isNot(equals(theme.syncConflict)));
    });

    test('focus indicator color is non-null', () {
      expect(theme.focusIndicator, isNotNull);
    });

    test('chip label style has small semibold properties', () {
      expect(theme.chipLabelStyle.fontSize, 11);
      expect(theme.chipLabelStyle.fontWeight, FontWeight.w600);
    });

    test('metric value style has large bold properties', () {
      expect(theme.metricValueStyle.fontSize, 20);
      expect(theme.metricValueStyle.fontWeight, FontWeight.w700);
    });

    test('section header style has medium semibold properties', () {
      expect(theme.sectionHeaderStyle.fontSize, 14);
      expect(theme.sectionHeaderStyle.fontWeight, FontWeight.w600);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Dark Theme Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopTheme.dark()', () {
    late MobileShopTheme theme;

    setUp(() {
      theme = MobileShopTheme.dark();
    });

    test('all status colors are non-null and distinct', () {
      final statusColors = [
        theme.statusReceived,
        theme.statusInProgress,
        theme.statusCompleted,
        theme.statusOverdue,
        theme.statusPending,
        theme.statusCancelled,
      ];

      expect(
        statusColors.toSet().length,
        statusColors.length,
        reason: 'All dark status colors should be distinct',
      );
    });

    test('dark chip background is darker than light chip background', () {
      final light = MobileShopTheme.light();
      // Dark theme chip background should have lower luminance
      expect(
        theme.chipBackground.computeLuminance(),
        lessThan(light.chipBackground.computeLuminance()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Light vs Dark Differentiation
  // ═══════════════════════════════════════════════════════════════════════════

  group('Light vs Dark differentiation', () {
    test('light and dark status colors differ for all semantic tokens', () {
      final light = MobileShopTheme.light();
      final dark = MobileShopTheme.dark();

      // Every status color should differ between light and dark
      expect(light.statusReceived, isNot(equals(dark.statusReceived)));
      expect(light.statusInProgress, isNot(equals(dark.statusInProgress)));
      expect(light.statusCompleted, isNot(equals(dark.statusCompleted)));
      expect(light.statusOverdue, isNot(equals(dark.statusOverdue)));
      expect(light.statusPending, isNot(equals(dark.statusPending)));
      expect(light.statusCancelled, isNot(equals(dark.statusCancelled)));
    });

    test('focus indicator differs between themes', () {
      final light = MobileShopTheme.light();
      final dark = MobileShopTheme.dark();
      expect(light.focusIndicator, isNot(equals(dark.focusIndicator)));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ThemeExtension Behavior
  // ═══════════════════════════════════════════════════════════════════════════

  group('ThemeExtension behavior', () {
    test('copyWith replaces specified fields only', () {
      final original = MobileShopTheme.light();
      const newColor = Color(0xFFFF0000);

      final modified = original.copyWith(statusReceived: newColor);

      expect(modified.statusReceived, newColor);
      // Other fields remain unchanged
      expect(modified.statusInProgress, original.statusInProgress);
      expect(modified.statusCompleted, original.statusCompleted);
      expect(modified.chipLabelStyle, original.chipLabelStyle);
    });

    test('lerp at 0.0 returns source theme colors', () {
      final light = MobileShopTheme.light();
      final dark = MobileShopTheme.dark();

      final result = light.lerp(dark, 0.0);
      expect(result.statusReceived, light.statusReceived);
    });

    test('lerp at 1.0 returns target theme colors', () {
      final light = MobileShopTheme.light();
      final dark = MobileShopTheme.dark();

      final result = light.lerp(dark, 1.0);
      expect(result.statusReceived, dark.statusReceived);
    });

    test('lerp with null returns self', () {
      final light = MobileShopTheme.light();
      final result = light.lerp(null, 0.5);
      expect(result.statusReceived, light.statusReceived);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MobileShopTheme.of Fallback
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopTheme.of fallback', () {
    testWidgets('returns light theme when extension is not registered', (
      tester,
    ) async {
      late MobileShopTheme resolved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = MobileShopTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // Should fallback to light
      expect(resolved.statusReceived, MobileShopTheme.light().statusReceived);
    });

    testWidgets('returns registered extension when present', (tester) async {
      final dark = MobileShopTheme.dark();
      late MobileShopTheme resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [dark]),
          home: Builder(
            builder: (context) {
              resolved = MobileShopTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.statusReceived, dark.statusReceived);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Breakpoint Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopBreakpoint', () {
    test('phone range is 0–599', () {
      expect(MobileShopBreakpoint.fromWidth(0), MobileShopBreakpoint.phone);
      expect(MobileShopBreakpoint.fromWidth(320), MobileShopBreakpoint.phone);
      expect(MobileShopBreakpoint.fromWidth(599), MobileShopBreakpoint.phone);
    });

    test('tablet range is 600–1023', () {
      expect(MobileShopBreakpoint.fromWidth(600), MobileShopBreakpoint.tablet);
      expect(MobileShopBreakpoint.fromWidth(768), MobileShopBreakpoint.tablet);
      expect(MobileShopBreakpoint.fromWidth(1023), MobileShopBreakpoint.tablet);
    });

    test('desktop range is 1024+', () {
      expect(
        MobileShopBreakpoint.fromWidth(1024),
        MobileShopBreakpoint.desktop,
      );
      expect(
        MobileShopBreakpoint.fromWidth(1920),
        MobileShopBreakpoint.desktop,
      );
    });

    test('convenience getters work correctly', () {
      expect(MobileShopBreakpoint.phone.isPhone, isTrue);
      expect(MobileShopBreakpoint.phone.isTablet, isFalse);
      expect(MobileShopBreakpoint.phone.isDesktop, isFalse);

      expect(MobileShopBreakpoint.tablet.isTablet, isTrue);
      expect(MobileShopBreakpoint.desktop.isDesktop, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Spacing Tokens
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopSpacing', () {
    test('touchTarget is 48dp (WCAG 2.5.5)', () {
      expect(MobileShopSpacing.touchTarget, 48.0);
    });

    test('spacing values are in ascending order', () {
      expect(MobileShopSpacing.xs, lessThan(MobileShopSpacing.sm));
      expect(MobileShopSpacing.sm, lessThan(MobileShopSpacing.md));
      expect(MobileShopSpacing.md, lessThan(MobileShopSpacing.lg));
      expect(MobileShopSpacing.lg, lessThan(MobileShopSpacing.xl));
      expect(MobileShopSpacing.xl, lessThan(MobileShopSpacing.xxl));
    });
  });
}
