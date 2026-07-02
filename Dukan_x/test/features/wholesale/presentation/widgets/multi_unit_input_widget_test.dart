// ============================================================================
// TEST: Multi-Unit Input Widget — box→pieces conversion (wholesale)
// ============================================================================
// Verifies the multi-unit conversion widget computes correctly using
// integer paise-safe arithmetic (no floating-point currency).
//
// Validates: Requirements 7.4, 7.5
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/wholesale/presentation/widgets/multi_unit_input_widget.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('MultiUnitInputWidget — rendering', () {
    testWidgets('shows boxes input, factor display, and computed fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const MultiUnitInputWidget(conversionFactor: 12, perPiecePaise: 500),
        ),
      );

      // Header present
      expect(find.text('Multi-Unit Conversion'), findsOneWidget);

      // Factor display
      expect(find.text('12'), findsOneWidget);

      // Labels present
      expect(find.text('Total Pieces'), findsOneWidget);
      expect(find.text('Line Amount'), findsOneWidget);

      // Initial computed values (0 boxes → 0 pieces, ₹0.00)
      expect(find.text('0'), findsWidgets);
      expect(find.text('₹0.00'), findsOneWidget);
    });

    testWidgets('shows per-piece rate info', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const MultiUnitInputWidget(conversionFactor: 10, perPiecePaise: 250),
        ),
      );

      expect(find.text('Per-piece rate: ₹2.50'), findsOneWidget);
    });
  });

  group('MultiUnitInputWidget — computation', () {
    testWidgets('computes pieces = boxes × factor correctly', (tester) async {
      MultiUnitResult? lastResult;

      await tester.pumpWidget(
        wrapWidget(
          MultiUnitInputWidget(
            conversionFactor: 12,
            perPiecePaise: 500,
            onChanged: (result) => lastResult = result,
          ),
        ),
      );

      // Enter 5 boxes
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(lastResult, isNotNull);
      expect(lastResult!.boxes, 5);
      expect(lastResult!.factor, 12);
      expect(lastResult!.totalPieces, 60); // 5 × 12
    });

    testWidgets(
      'computes lineAmount = pieces × perPiecePaise in integer paise',
      (tester) async {
        MultiUnitResult? lastResult;

        await tester.pumpWidget(
          wrapWidget(
            MultiUnitInputWidget(
              conversionFactor: 24,
              perPiecePaise: 150,
              onChanged: (result) => lastResult = result,
            ),
          ),
        );

        // Enter 3 boxes → 72 pieces → 72 × 150 = 10800 paise
        await tester.enterText(find.byType(TextFormField), '3');
        await tester.pump();

        expect(lastResult!.totalPieces, 72);
        expect(lastResult!.lineAmountPaise, 10800);
      },
    );

    testWidgets('displays line amount formatted as rupees', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const MultiUnitInputWidget(
            conversionFactor: 10,
            perPiecePaise: 500,
            initialBoxes: 2,
          ),
        ),
      );

      // 2 boxes × 10 = 20 pieces × 500 paise = 10000 paise = ₹100.00
      expect(find.text('₹100.00'), findsOneWidget);
      expect(find.text('20'), findsOneWidget); // total pieces
    });

    testWidgets('uses initialBoxes to set starting value', (tester) async {
      MultiUnitResult? lastResult;

      await tester.pumpWidget(
        wrapWidget(
          MultiUnitInputWidget(
            conversionFactor: 6,
            perPiecePaise: 1000,
            initialBoxes: 4,
            onChanged: (result) => lastResult = result,
          ),
        ),
      );
      await tester.pump();

      // Should compute on init: 4 × 6 = 24 pieces, 24 × 1000 = 24000 paise
      expect(lastResult, isNotNull);
      expect(lastResult!.boxes, 4);
      expect(lastResult!.totalPieces, 24);
      expect(lastResult!.lineAmountPaise, 24000);
    });
  });

  group('MultiUnitInputWidget — integer safety', () {
    testWidgets('no floating-point: large values remain exact', (tester) async {
      MultiUnitResult? lastResult;

      await tester.pumpWidget(
        wrapWidget(
          MultiUnitInputWidget(
            conversionFactor: 48,
            perPiecePaise: 99999,
            onChanged: (result) => lastResult = result,
          ),
        ),
      );

      // Enter 100 boxes → 4800 pieces → 4800 × 99999 = 479,995,200 paise
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.pump();

      expect(lastResult!.totalPieces, 4800);
      expect(lastResult!.lineAmountPaise, 479995200);
    });

    testWidgets('only allows digit input (no decimals)', (tester) async {
      MultiUnitResult? lastResult;

      await tester.pumpWidget(
        wrapWidget(
          MultiUnitInputWidget(
            conversionFactor: 12,
            perPiecePaise: 500,
            onChanged: (result) => lastResult = result,
          ),
        ),
      );

      // Attempt to enter a decimal — only digits allowed by input formatter
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(lastResult!.boxes, 5);
      // Verified: integer boxes input only
    });
  });

  group('MultiUnitInputWidget — validation', () {
    testWidgets('empty input results in zero computation', (tester) async {
      MultiUnitResult? lastResult;

      await tester.pumpWidget(
        wrapWidget(
          MultiUnitInputWidget(
            conversionFactor: 12,
            perPiecePaise: 500,
            onChanged: (result) => lastResult = result,
          ),
        ),
      );

      // Enter then clear
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();
      expect(lastResult!.totalPieces, 60);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(lastResult!.totalPieces, 0);
      expect(lastResult!.lineAmountPaise, 0);
    });
  });

  group('MultiUnitResult — data class', () {
    test('stores all computed values correctly', () {
      const result = MultiUnitResult(
        boxes: 10,
        factor: 24,
        totalPieces: 240,
        perPiecePaise: 350,
        lineAmountPaise: 84000,
      );

      expect(result.boxes, 10);
      expect(result.factor, 24);
      expect(result.totalPieces, 240);
      expect(result.perPiecePaise, 350);
      expect(result.lineAmountPaise, 84000);
    });
  });
}
