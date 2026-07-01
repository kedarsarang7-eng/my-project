// ============================================================================
// Pharmacy sidebar entry → screen resolution tests
// ============================================================================
//
// Spec: pharmacy-vertical-remediation
// Task 10.4 — Write resolution tests for new sidebar entries.
// Validates: Requirements 13.6, 16.6
//
// WHAT THIS PROVES:
//   Req 13.6 — for each of the four new pharmacy sidebar entries (Salt Search,
//   Patient Registry, Narcotic Register, H1 Register), activation resolves the
//   sidebar itemId to the correct screen widget (and never a placeholder).
//
//   Req 16.6 — the Expenses entry resolves to the Expenses screen and the
//   Bank/Cash entry resolves to the Bank screen, with the test passing only
//   when BOTH resolutions succeed.
//
// HOW:
//   `SidebarNavigationHandler.tryGetScreenForItem(itemId, context)` is the
//   single source of truth for itemId → screen mapping. It takes a
//   BuildContext, so each case is exercised through a pumped `Builder` that
//   captures a real context. We assert the returned widget is exactly the
//   expected screen type via `isA<...>` (which inherently excludes the private
//   `_PlaceholderScreen`) and is non-null.
// ============================================================================

import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';

// Target pharmacy / shared screens the entries must resolve to.
import 'package:dukanx/features/pharmacy/screens/salt_search_screen.dart';
import 'package:dukanx/features/pharmacy/screens/patient_registry_screen.dart';
import 'package:dukanx/features/pharmacy/screens/narcotic_register_screen.dart';
import 'package:dukanx/features/prescriptions/presentation/screens/h1_register_screen.dart';
import 'package:dukanx/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:dukanx/features/bank/presentation/screens/bank_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a minimal widget tree and returns the screen resolved by
/// [SidebarNavigationHandler.tryGetScreenForItem] for [itemId], using a real
/// [BuildContext] captured from a pumped [Builder].
Future<Widget?> _resolve(WidgetTester tester, String itemId) async {
  late Widget? resolved;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          resolved = SidebarNavigationHandler.tryGetScreenForItem(
            itemId,
            context,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pharmacy sidebar entry resolution (Req 13.6)', () {
    testWidgets('salt_search resolves to SaltSearchScreen', (tester) async {
      final screen = await _resolve(tester, 'salt_search');
      expect(
        screen,
        isNotNull,
        reason: 'salt_search must resolve to a screen.',
      );
      expect(
        screen,
        isA<SaltSearchScreen>(),
        reason:
            'salt_search must resolve to SaltSearchScreen, never a placeholder.',
      );
    });

    testWidgets('patient_registry resolves to PatientRegistryScreen', (
      tester,
    ) async {
      final screen = await _resolve(tester, 'patient_registry');
      expect(screen, isNotNull);
      expect(
        screen,
        isA<PatientRegistryScreen>(),
        reason:
            'patient_registry must resolve to PatientRegistryScreen, never a '
            'placeholder.',
      );
    });

    testWidgets('narcotic_register resolves to NarcoticRegisterScreen', (
      tester,
    ) async {
      final screen = await _resolve(tester, 'narcotic_register');
      expect(screen, isNotNull);
      expect(
        screen,
        isA<NarcoticRegisterScreen>(),
        reason:
            'narcotic_register must resolve to NarcoticRegisterScreen, never a '
            'placeholder.',
      );
    });

    testWidgets('h1_register resolves to H1RegisterScreen', (tester) async {
      final screen = await _resolve(tester, 'h1_register');
      expect(screen, isNotNull);
      expect(
        screen,
        isA<H1RegisterScreen>(),
        reason:
            'h1_register must resolve to H1RegisterScreen, never a placeholder.',
      );
    });
  });

  group('Expenses and Bank/Cash sidebar resolution (Req 16.6)', () {
    // Req 16.6 explicitly requires the test to pass only when BOTH the Expenses
    // and Bank/Cash resolutions succeed — asserted together in one test.
    testWidgets('expenses → ExpensesScreen AND bank_accounts → BankScreen', (
      tester,
    ) async {
      final expenses = await _resolve(tester, 'expenses');
      expect(expenses, isNotNull, reason: 'expenses must resolve to a screen.');
      expect(
        expenses,
        isA<ExpensesScreen>(),
        reason: 'expenses must resolve to the existing ExpensesScreen.',
      );

      final bank = await _resolve(tester, 'bank_accounts');
      expect(
        bank,
        isNotNull,
        reason: 'bank_accounts must resolve to a screen.',
      );
      expect(
        bank,
        isA<BankScreen>(),
        reason: 'bank_accounts must resolve to the existing BankScreen.',
      );
    });
  });
}
