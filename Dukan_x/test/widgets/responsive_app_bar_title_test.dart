import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/responsive_app_bar_title.dart';

void main() {
  group('ResponsiveAppBarTitle Widget Tests', () {
    Widget buildTestWidget(
      String title, {
      TextStyle? style,
      double width = 800,
    }) {
      return MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: ResponsiveAppBarTitle(title: title, style: style),
            ),
          ),
        ),
      );
    }

    testWidgets('renders title text correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget('Buy Orders (PO)'));

      expect(find.text('Buy Orders (PO)'), findsOneWidget);
      expect(find.byType(ResponsiveAppBarTitle), findsOneWidget);
    });

    testWidgets('uses maxLines: 1 to prevent wrapping', (tester) async {
      await tester.pumpWidget(
        buildTestWidget('A Very Long Title That Should Not Wrap'),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.maxLines, 1);
    });

    testWidgets('uses TextOverflow.ellipsis', (tester) async {
      await tester.pumpWidget(buildTestWidget('Payment Reminders'));

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('uses font size 16 on mobile (width < 600)', (tester) async {
      await tester.pumpWidget(buildTestWidget('Payment Reminders', width: 360));

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 16);
    });

    testWidgets('uses font size 20 on desktop (width >= 600)', (tester) async {
      await tester.pumpWidget(
        buildTestWidget('Payment Reminders', width: 1024),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 20);
    });

    testWidgets('respects custom style on desktop, keeps original fontSize', (
      tester,
    ) async {
      const customStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      );

      await tester.pumpWidget(
        buildTestWidget('Custom Title', style: customStyle, width: 1024),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 24);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.red);
    });

    testWidgets('overrides custom style fontSize to 16 on mobile', (
      tester,
    ) async {
      const customStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      );

      await tester.pumpWidget(
        buildTestWidget('Custom Title', style: customStyle, width: 375),
      );

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 16);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.color, Colors.blue);
    });

    testWidgets('renders correctly at breakpoint boundary (599px = mobile)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget('Boundary Test', width: 599));

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 16);
    });

    testWidgets('renders correctly at breakpoint boundary (600px = tablet)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget('Boundary Test', width: 600));

      final textWidget = tester.widget<Text>(find.byType(Text).last);
      expect(textWidget.style?.fontSize, 20);
    });
  });
}
