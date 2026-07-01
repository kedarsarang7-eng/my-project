// ============================================================================
// MODERN UI COMPONENTS TESTS
// ============================================================================
// Widget tests for modern UI components
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/modern_ui_components.dart';
import 'package:dukanx/core/theme/futuristic_colors.dart';

void main() {
  group('FuturisticColors Tests', () {
    test('should have primary colors defined', () {
      expect(FuturisticColors.primary, isA<Color>());
      expect(FuturisticColors.primaryLight, isA<Color>());
      expect(FuturisticColors.primaryDark, isA<Color>());
    });

    test('should have secondary colors defined', () {
      expect(FuturisticColors.secondary, isA<Color>());
      expect(FuturisticColors.secondaryLight, isA<Color>());
    });

    test('should have status colors defined', () {
      expect(FuturisticColors.success, isA<Color>());
      expect(FuturisticColors.warning, isA<Color>());
      expect(FuturisticColors.error, isA<Color>());
      expect(FuturisticColors.accent2, isA<Color>());
    });

    test('should have text colors defined', () {
      expect(FuturisticColors.textPrimary, isA<Color>());
      expect(FuturisticColors.textSecondary, isA<Color>());
      expect(FuturisticColors.textHint, isA<Color>());
    });
  });

  group('AppSpacing Tests', () {
    test('should have all spacing values', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });

    test('spacing should be incremental', () {
      expect(AppSpacing.xs < AppSpacing.sm, true);
      expect(AppSpacing.sm < AppSpacing.md, true);
      expect(AppSpacing.md < AppSpacing.lg, true);
      expect(AppSpacing.lg < AppSpacing.xl, true);
      expect(AppSpacing.xl < AppSpacing.xxl, true);
    });
  });

  group('AppBorderRadius Tests', () {
    test('should have all border radius values', () {
      expect(AppBorderRadius.sm, 4.0);
      expect(AppBorderRadius.md, 8.0);
      expect(AppBorderRadius.lg, 12.0);
      expect(AppBorderRadius.xl, 16.0);
      expect(AppBorderRadius.xxl, 24.0);
    });
  });

  group('ModernCard Widget Tests', () {
    testWidgets('should render with child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ModernCard(child: const Text('Card Content'))),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(ModernCard), findsOneWidget);
    });

    testWidgets('should handle onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              onTap: () => tapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('should render with custom background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCard(
              backgroundColor: Colors.blue,
              child: const Text('Blue Card'),
            ),
          ),
        ),
      );

      expect(find.text('Blue Card'), findsOneWidget);
    });
  });

  group('StatisticWidget Tests', () {
    testWidgets('should render with label, value, and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticWidget(
              label: 'Total Sales',
              value: '₹50,000',
              icon: Icons.monetization_on,
            ),
          ),
        ),
      );

      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on), findsOneWidget);
    });

    testWidgets('should handle onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticWidget(
              label: 'Clickable Stat',
              value: '100',
              icon: Icons.star,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Clickable Stat'));
      await tester.pump();

      expect(tapped, true);
    });
  });

  group('FuturisticButton Widget Tests', () {
    testWidgets('should render with label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuturisticButton(label: 'Click Me', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('should handle onPressed', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuturisticButton(
              label: 'Press Me',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Press Me'));
      await tester.pump();

      expect(pressed, true);
    });

    testWidgets('should show loading state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuturisticButton(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should be disabled when loading', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FuturisticButton(
              label: 'Disabled',
              onPressed: () => pressed = true,
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pump();

      expect(pressed, false);
    });
  });

  group('EmptyStateWidget Tests', () {
    testWidgets('should render with required fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'No Items',
              description: 'Start adding items to see them here.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('Start adding items to see them here.'), findsOneWidget);
    });

    testWidgets('should render with optional button', (tester) async {
      bool clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.add,
              title: 'Empty',
              description: 'Nothing here yet.',
              buttonLabel: 'Add Now',
              onButtonPressed: () => clicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Now'), findsOneWidget);

      await tester.tap(find.text('Add Now'));
      await tester.pump();

      expect(clicked, true);
    });
  });

  group('ModernListTile Widget Tests', () {
    testWidgets('should render with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ModernListTile(title: 'List Tile Title')),
        ),
      );

      expect(find.text('List Tile Title'), findsOneWidget);
    });

    testWidgets('should render with subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernListTile(
              title: 'Main Title',
              subtitle: 'Secondary Text',
            ),
          ),
        ),
      );

      expect(find.text('Main Title'), findsOneWidget);
      expect(find.text('Secondary Text'), findsOneWidget);
    });

    testWidgets('should render with leading icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernListTile(leadingIcon: Icons.person, title: 'User'),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('should handle onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernListTile(
              title: 'Tappable Tile',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Tile'));
      await tester.pump();

      expect(tapped, true);
    });
  });

  group('AnimatedLoadingWidget Tests', () {
    testWidgets('should render without message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AnimatedLoadingWidget())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render with message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedLoadingWidget(message: 'Loading data...'),
          ),
        ),
      );

      expect(find.text('Loading data...'), findsOneWidget);
    });
  });

  group('AnimatedTabBar Tests', () {
    testWidgets('should render tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              tabs: ['Tab 1', 'Tab 2', 'Tab 3'],
              onTabChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);
      expect(find.text('Tab 3'), findsOneWidget);
    });

    testWidgets('should call onTabChanged when clicking a tab', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              tabs: ['First', 'Second'],
              onTabChanged: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Second'));
      await tester.pump();

      expect(selectedIndex, 1);
    });

    testWidgets('should start with initial index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTabBar(
              tabs: ['A', 'B', 'C'],
              initialIndex: 2,
              onTabChanged: (_) {},
            ),
          ),
        ),
      );

      // Tab C should be selected initially
      expect(find.text('C'), findsOneWidget);
    });
  });
}
