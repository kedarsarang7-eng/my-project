/// Keyboard Behavior Tests — Focus Traversal and Shortcuts (Task 16.4)
///
/// Validates: Requirements 11.1, 11.5
/// - FocusableActionItem handles Enter/Space activation
/// - FocusableActionItem shows visible focus indicator
/// - FocusableActionItem enforces 48dp minimum size
/// - MobileShopFocusGroup establishes traversal boundary
/// - MobileShopKeyboardShortcuts binds Ctrl+R, Ctrl+F, Escape
/// - SkipToContentAction visible only when focused
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/theme/mobile_shop_theme.dart';
import 'package:dukanx/features/mobile_shop/theme/keyboard_behavior.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // FocusableActionItem Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('FocusableActionItem', () {
    testWidgets('activates on tap', (tester) async {
      var activated = false;

      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Add device',
            onActivate: () => activated = true,
            child: const Text('Add'),
          ),
        ),
      );

      await tester.tap(find.text('Add'));
      expect(activated, isTrue);
    });

    testWidgets('activates on Enter key when focused', (tester) async {
      var activated = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Submit',
            focusNode: focusNode,
            onActivate: () => activated = true,
            child: const Text('Submit'),
          ),
        ),
      );

      // Request focus
      focusNode.requestFocus();
      await tester.pump();

      // Simulate Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(activated, isTrue);

      focusNode.dispose();
    });

    testWidgets('activates on Space key when focused', (tester) async {
      var activated = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Toggle',
            focusNode: focusNode,
            onActivate: () => activated = true,
            child: const Text('Toggle'),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(activated, isTrue);

      focusNode.dispose();
    });

    testWidgets('enforces 48dp minimum size', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Tiny',
            onActivate: () {},
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

      final box = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(FocusableActionItem),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(box.constraints.minWidth, MobileShopSpacing.touchTarget);
      expect(box.constraints.minHeight, MobileShopSpacing.touchTarget);
    });

    testWidgets('shows focus indicator decoration when focused', (
      tester,
    ) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Focusable',
            focusNode: focusNode,
            onActivate: () {},
            child: const Text('Focus me'),
          ),
        ),
      );

      // Before focus: FocusIndicatorDecoration renders child directly
      focusNode.requestFocus();
      await tester.pump();

      // After focus: should find a DecoratedBox inside FocusIndicatorDecoration
      expect(find.byType(DecoratedBox), findsOneWidget);

      focusNode.dispose();
    });

    testWidgets('does not accept focus when onActivate is null', (
      tester,
    ) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Disabled',
            focusNode: focusNode,
            onActivate: null,
            child: const Text('No Action'),
          ),
        ),
      );

      // Try to request focus — should not be focusable
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);

      focusNode.dispose();
    });

    testWidgets('exposes button semantics with label', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: FocusableActionItem(
            semanticLabel: 'Edit IMEI',
            onActivate: () {},
            child: const Icon(Icons.edit),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Edit IMEI'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FocusIndicatorDecoration Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('FocusIndicatorDecoration', () {
    testWidgets('shows border decoration when focused', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: const FocusIndicatorDecoration(
            isFocused: true,
            child: Text('Focused'),
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('shows only child when not focused', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: const FocusIndicatorDecoration(
            isFocused: false,
            child: Text('Not Focused'),
          ),
        ),
      );

      // When not focused, it returns child directly — no DecoratedBox
      expect(
        find.descendant(
          of: find.byType(FocusIndicatorDecoration),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MobileShopFocusGroup Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopFocusGroup', () {
    testWidgets('wraps children in FocusTraversalGroup', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: MobileShopFocusGroup(
            child: Column(children: const [Text('A'), Text('B')]),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MobileShopFocusGroup),
          matching: find.byType(FocusTraversalGroup),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses reading order policy by default', (tester) async {
      await tester.pumpWidget(
        _themeApp(child: MobileShopFocusGroup(child: const Text('Content'))),
      );

      final group = tester.widget<FocusTraversalGroup>(
        find.descendant(
          of: find.byType(MobileShopFocusGroup),
          matching: find.byType(FocusTraversalGroup),
        ),
      );
      expect(group.policy, isA<ReadingOrderTraversalPolicy>());
    });

    testWidgets('accepts custom policy', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: MobileShopFocusGroup(
            policy: OrderedTraversalPolicy(),
            child: const Text('Content'),
          ),
        ),
      );

      final group = tester.widget<FocusTraversalGroup>(
        find.descendant(
          of: find.byType(MobileShopFocusGroup),
          matching: find.byType(FocusTraversalGroup),
        ),
      );
      expect(group.policy, isA<OrderedTraversalPolicy>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MobileShopKeyboardShortcuts Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('MobileShopKeyboardShortcuts', () {
    testWidgets('Ctrl+R triggers onRefresh', (tester) async {
      var refreshed = false;

      await tester.pumpWidget(
        _themeApp(
          child: MobileShopKeyboardShortcuts(
            onRefresh: () => refreshed = true,
            child: const Text('Content'),
          ),
        ),
      );

      // Focus the widget tree
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(refreshed, isTrue);
    });

    testWidgets('Ctrl+F triggers onSearch', (tester) async {
      var searched = false;

      await tester.pumpWidget(
        _themeApp(
          child: MobileShopKeyboardShortcuts(
            onSearch: () => searched = true,
            child: const Text('Content'),
          ),
        ),
      );

      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(searched, isTrue);
    });

    testWidgets('Escape triggers onEscape', (tester) async {
      var escaped = false;

      await tester.pumpWidget(
        _themeApp(
          child: MobileShopKeyboardShortcuts(
            onEscape: () => escaped = true,
            child: const Text('Content'),
          ),
        ),
      );

      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(escaped, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SkipToContentAction Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('SkipToContentAction', () {
    testWidgets('is invisible (opacity 0) when not focused', (tester) async {
      final contentNode = FocusNode();

      await tester.pumpWidget(
        _themeApp(
          child: Column(
            children: [
              SkipToContentAction(contentFocusNode: contentNode),
              Focus(focusNode: contentNode, child: const Text('Main')),
            ],
          ),
        ),
      );

      await tester.pump();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);

      contentNode.dispose();
    });
  });
}

// ─── Helper ──────────────────────────────────────────────────────────────────

/// Creates a MaterialApp with MobileShopTheme registered.
Widget _themeApp({required Widget child}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [MobileShopTheme.light()]),
    home: Scaffold(body: child),
  );
}
