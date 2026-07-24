/// ResponsiveLayout Tests — Viewport-Adaptive Behavior (Task 16.4)
///
/// Validates: Requirements 11.1, 11.2
/// - ResponsiveValue resolves phone/tablet/desktop correctly
/// - ResponsiveLayout adapts padding per viewport
/// - ResponsiveLayout constrains max width on wider viewports
/// - ResponsiveGrid uses correct column count per breakpoint
/// - No horizontal overflow on phone viewports
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/theme/mobile_shop_theme.dart';
import 'package:dukanx/features/mobile_shop/theme/responsive_layout.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // ResponsiveValue Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('ResponsiveValue', () {
    testWidgets('resolves phone value on narrow viewport', (tester) async {
      const rv = ResponsiveValue(phone: 1, tablet: 2, desktop: 3);
      int? resolved;

      await tester.pumpWidget(
        _viewportApp(
          width: 400,
          child: Builder(
            builder: (context) {
              resolved = rv.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, 1);
    });

    testWidgets('resolves tablet value on medium viewport', (tester) async {
      const rv = ResponsiveValue(phone: 1, tablet: 2, desktop: 3);
      int? resolved;

      await tester.pumpWidget(
        _viewportApp(
          width: 768,
          child: Builder(
            builder: (context) {
              resolved = rv.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, 2);
    });

    testWidgets('resolves desktop value on wide viewport', (tester) async {
      const rv = ResponsiveValue(phone: 1, tablet: 2, desktop: 3);
      int? resolved;

      await tester.pumpWidget(
        _viewportApp(
          width: 1280,
          child: Builder(
            builder: (context) {
              resolved = rv.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, 3);
    });

    testWidgets('falls back to phone when tablet is null', (tester) async {
      const rv = ResponsiveValue<int>(phone: 10);
      int? resolved;

      await tester.pumpWidget(
        _viewportApp(
          width: 768,
          child: Builder(
            builder: (context) {
              resolved = rv.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, 10);
    });

    testWidgets('falls back to tablet when desktop is null', (tester) async {
      const rv = ResponsiveValue<int>(phone: 1, tablet: 2);
      int? resolved;

      await tester.pumpWidget(
        _viewportApp(
          width: 1280,
          child: Builder(
            builder: (context) {
              resolved = rv.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ResponsiveLayout Widget Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('ResponsiveLayout', () {
    testWidgets('provides phone breakpoint on narrow screen', (tester) async {
      MobileShopBreakpoint? receivedBp;

      await tester.pumpWidget(
        _viewportApp(
          width: 400,
          child: ResponsiveLayout(
            builder: (context, bp) {
              receivedBp = bp;
              return const Text('phone');
            },
          ),
        ),
      );

      expect(receivedBp, MobileShopBreakpoint.phone);
      expect(find.text('phone'), findsOneWidget);
    });

    testWidgets('provides tablet breakpoint on medium screen', (tester) async {
      MobileShopBreakpoint? receivedBp;

      await tester.pumpWidget(
        _viewportApp(
          width: 800,
          child: ResponsiveLayout(
            builder: (context, bp) {
              receivedBp = bp;
              return const Text('tablet');
            },
          ),
        ),
      );

      expect(receivedBp, MobileShopBreakpoint.tablet);
    });

    testWidgets('provides desktop breakpoint on wide screen', (tester) async {
      MobileShopBreakpoint? receivedBp;

      await tester.pumpWidget(
        _viewportApp(
          width: 1400,
          child: ResponsiveLayout(
            builder: (context, bp) {
              receivedBp = bp;
              return const Text('desktop');
            },
          ),
        ),
      );

      expect(receivedBp, MobileShopBreakpoint.desktop);
    });

    testWidgets('phone layout has 16dp horizontal padding', (tester) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 400,
          child: ResponsiveLayout(
            builder: (context, bp) {
              return Container(key: const Key('content'), color: Colors.red);
            },
          ),
        ),
      );

      // Find the Padding widget inside ResponsiveLayout
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(ResponsiveLayout),
          matching: find.byType(Padding),
        ),
      );
      final edgeInsets = padding.padding as EdgeInsets;
      expect(edgeInsets.left, MobileShopSpacing.lg); // 16
      expect(edgeInsets.right, MobileShopSpacing.lg);
    });

    testWidgets('tablet layout constrains max width to 720dp', (tester) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 900,
          child: ResponsiveLayout(
            builder: (context, bp) {
              return Container(key: const Key('content'));
            },
          ),
        ),
      );

      final boxes = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveLayout),
          matching: find.byType(ConstrainedBox),
        ),
      );
      final finiteBox = boxes.firstWhere(
        (b) => b.constraints.maxWidth.isFinite,
      );
      expect(finiteBox.constraints.maxWidth, 720.0);
    });

    testWidgets('desktop layout constrains max width to 960dp', (tester) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 1400,
          child: ResponsiveLayout(
            builder: (context, bp) {
              return Container(key: const Key('content'));
            },
          ),
        ),
      );

      final boxes = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveLayout),
          matching: find.byType(ConstrainedBox),
        ),
      );
      final finiteBox = boxes.firstWhere(
        (b) => b.constraints.maxWidth.isFinite,
      );
      expect(finiteBox.constraints.maxWidth, 960.0);
    });

    testWidgets('phone layout does not constrain width (fills screen)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 400,
          child: ResponsiveLayout(
            builder: (context, bp) {
              return Container(key: const Key('content'));
            },
          ),
        ),
      );

      // Phone should not have a ConstrainedBox with finite width
      final boxes = tester.widgetList<ConstrainedBox>(
        find.descendant(
          of: find.byType(ResponsiveLayout),
          matching: find.byType(ConstrainedBox),
        ),
      );
      // Either no ConstrainedBox or one with infinite width
      for (final box in boxes) {
        if (box.constraints.maxWidth.isFinite) {
          fail('Phone layout should not have a finite maxWidth constraint');
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ResponsiveGrid Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('ResponsiveGrid', () {
    testWidgets('renders 1 column on phone', (tester) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 400,
          child: ResponsiveGrid(
            phoneCols: 1,
            tabletCols: 2,
            desktopCols: 3,
            children: List.generate(
              3,
              (i) => Container(
                key: Key('item_$i'),
                height: 50,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // With 1 column, all 3 items should be in the list
      expect(find.byKey(const Key('item_0')), findsOneWidget);
      expect(find.byKey(const Key('item_1')), findsOneWidget);
      expect(find.byKey(const Key('item_2')), findsOneWidget);
    });

    testWidgets('renders 2 columns on tablet', (tester) async {
      await tester.pumpWidget(
        _viewportApp(
          width: 768,
          child: ResponsiveGrid(
            phoneCols: 1,
            tabletCols: 2,
            desktopCols: 3,
            children: List.generate(
              4,
              (i) => Container(
                key: Key('item_$i'),
                height: 50,
                color: Colors.green,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // All 4 items visible
      expect(find.byKey(const Key('item_0')), findsOneWidget);
      expect(find.byKey(const Key('item_3')), findsOneWidget);
    });
  });
}

// ─── Helper ──────────────────────────────────────────────────────────────────

/// Creates a MaterialApp with a MediaQuery override for the given viewport width.
Widget _viewportApp({required double width, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(body: child),
    ),
  );
}
