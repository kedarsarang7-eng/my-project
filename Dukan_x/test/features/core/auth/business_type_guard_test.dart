import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/features/core/auth/business_type_guard.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock SharedPreferences
void setMockSharedPreferences(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
}

void main() {
  setUp(() {
    setMockSharedPreferences({});
  });

  Widget createTestedWidget(BusinessType currentType, BusinessGuard guard) {
    return ProviderScope(
      overrides: [
        businessTypeProvider.overrideWith(
          () => MockBusinessTypeNotifier(currentType),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: guard)),
    );
  }

  testWidgets('BusinessGuard shows child when type matches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createTestedWidget(
        BusinessType.clinic,
        BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          child: const Text('Authorized Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authorized Content'), findsOneWidget);
    expect(find.byType(SizedBox), findsNothing);
  });

  testWidgets('BusinessGuard hides child when type mismatch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createTestedWidget(
        BusinessType.grocery,
        BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          child: const Text('Authorized Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authorized Content'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('BusinessGuard shows denial message when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createTestedWidget(
        BusinessType.grocery,
        BusinessGuard(
          allowedTypes: const [BusinessType.clinic],
          denialMessage: 'Access Denied',
          child: const Text('Authorized Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authorized Content'), findsNothing);
    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
}

class MockBusinessTypeNotifier extends Notifier<BusinessTypeState>
    implements BusinessTypeNotifier {
  final BusinessType _type;
  MockBusinessTypeNotifier(this._type);

  @override
  BusinessTypeState build() {
    return BusinessTypeState(type: _type);
  }

  @override
  Future<void> setBusinessType(BusinessType type, {String? customName}) async {}
}
