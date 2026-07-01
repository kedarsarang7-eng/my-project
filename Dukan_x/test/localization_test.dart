import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dukanx/generated/app_localizations.dart';

void main() {
  testWidgets('Localization returns Hindi translation', (
    WidgetTester tester,
  ) async {
    final widget = MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('hi'),
      home: Builder(
        builder: (context) {
          // Ensure that owner_login key exists in your arb file
          return Text(AppLocalizations.of(context)!.owner_login);
        },
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Check for the expected Hindi text. Make sure this matches your hi.arb file.
    expect(find.text('मालिक लॉगिन'), findsOneWidget);
  });
}
