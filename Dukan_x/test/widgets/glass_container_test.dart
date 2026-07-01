// ============================================================================
// WIDGET TESTS - UI COMPONENTS
// ============================================================================
// Tests for core UI widget components
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/glass_container.dart';

void main() {
  group('GlassContainer Widget Tests', () {
    testWidgets('should render with default parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(child: const Text('Test Content')),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('should render with custom blur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(blur: 20.0, child: const Text('Blurred')),
          ),
        ),
      );

      expect(find.text('Blurred'), findsOneWidget);
    });

    testWidgets('should render with custom opacity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(opacity: 0.5, child: const Text('Opaque')),
          ),
        ),
      );

      expect(find.text('Opaque'), findsOneWidget);
    });

    testWidgets('should render with custom border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              borderRadius: BorderRadius.circular(24),
              child: const Text('Rounded'),
            ),
          ),
        ),
      );

      expect(find.text('Rounded'), findsOneWidget);
    });

    testWidgets('should render with padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: const Text('Padded'),
            ),
          ),
        ),
      );

      expect(find.text('Padded'), findsOneWidget);
    });

    testWidgets('should render with margin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              margin: const EdgeInsets.all(8),
              child: const Text('Margined'),
            ),
          ),
        ),
      );

      expect(find.text('Margined'), findsOneWidget);
    });

    testWidgets('should render with fixed dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              width: 200,
              height: 100,
              child: const Text('Fixed Size'),
            ),
          ),
        ),
      );

      final container = tester.widget<GlassContainer>(
        find.byType(GlassContainer),
      );
      expect(container.width, 200);
      expect(container.height, 100);
    });

    testWidgets('should render with gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
              ),
              child: const Text('Gradient'),
            ),
          ),
        ),
      );

      expect(find.text('Gradient'), findsOneWidget);
    });

    testWidgets('should render with border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              border: Border.all(color: Colors.white, width: 2),
              child: const Text('Bordered'),
            ),
          ),
        ),
      );

      expect(find.text('Bordered'), findsOneWidget);
    });

    testWidgets('should render complex child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star),
                  SizedBox(height: 8),
                  Text('Complex Child'),
                  Text('Multiple Widgets'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Complex Child'), findsOneWidget);
      expect(find.text('Multiple Widgets'), findsOneWidget);
    });

    testWidgets('should render nested GlassContainers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: GlassContainer(opacity: 0.3, child: const Text('Nested')),
            ),
          ),
        ),
      );

      expect(find.byType(GlassContainer), findsNWidgets(2));
      expect(find.text('Nested'), findsOneWidget);
    });
  });

  group('Widget Accessibility Tests', () {
    testWidgets('GlassContainer content should be visible and accessible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(child: const Text('Accessible Content')),
          ),
        ),
      );

      // Content should be findable and visible
      expect(find.text('Accessible Content'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
    });
  });

  group('Widget State Tests', () {
    testWidgets('should handle widget rebuild', (tester) async {
      bool showContent = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: GlassContainer(
                  child: showContent
                      ? const Text('Content A')
                      : const Text('Content B'),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => showContent = !showContent),
                  child: const Icon(Icons.swap_horiz),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Content A'), findsOneWidget);
      expect(find.text('Content B'), findsNothing);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();

      expect(find.text('Content A'), findsNothing);
      expect(find.text('Content B'), findsOneWidget);
    });
  });
}
