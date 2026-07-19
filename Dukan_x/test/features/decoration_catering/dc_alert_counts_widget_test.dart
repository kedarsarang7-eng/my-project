// ============================================================================
// Task 2.3 — WIDGET TEST: DC alerts computed from dcAlertCountsProvider
// Feature: decoration-catering-remediation
// **Validates: Requirement 2.1 (AC4)**
// ============================================================================
//
// Regression-lock only — per design.md's Current State Assessment, the DC
// branch of `BusinessAlertsWidget` already computes its alert counts from
// `dcAlertCountsProvider` rather than a hardcoded value. This test locks
// that behavior in: it overrides `dcAlertCountsProvider` with a known fake
// `DcAlertSnapshot`, pumps `BusinessAlertsWidget` with a DcTenant session
// (businessType == decorationCatering), and asserts the rendered alert
// counts match the overridden provider value — proving the widget consults
// the provider rather than rendering a hardcoded literal.
//
// Run: flutter test test/features/decoration_catering/dc_alert_counts_widget_test.dart
// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pins the business type to `decorationCatering` (a DcTenant session).
class _DcBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() =>
      BusinessTypeState(type: BusinessType.decorationCatering);
}

/// Pins the business type to `grocery` (used to prove the DC provider
/// override does not leak into other verticals).
class _GroceryBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.grocery);
}

/// Pumps [BusinessAlertsWidget] with the business type pinned to
/// `decorationCatering` and `dcAlertCountsProvider` overridden with
/// [snapshot]. `alertCountsProvider` is overridden with an already-resolved
/// empty map so its service-locator-backed body never executes.
Future<void> pumpDcAlerts(
  WidgetTester tester, {
  required AsyncValue<DcAlertSnapshot> snapshot,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(<String, Object>{});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessTypeProvider.overrideWith(() => _DcBusinessTypeNotifier()),
        alertCountsProvider.overrideWithValue(
          const AsyncValue<Map<String, int>>.data(<String, int>{}),
        ),
        dcAlertCountsProvider.overrideWith((ref) async {
          return snapshot.when(
            data: (s) => s,
            loading: () =>
                Future<DcAlertSnapshot>.delayed(const Duration(days: 1)),
            error: (e, st) => throw e,
          );
        }),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(child: BusinessAlertsWidget()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Feature: decoration-catering-remediation — BusinessAlertsWidget DC '
    'branch computes counts from dcAlertCountsProvider (Requirement 2.1 AC4)',
    () {
      testWidgets(
        'displays the exact values supplied by dcAlertCountsProvider (not '
        'a hardcoded value)',
        (tester) async {
          await pumpDcAlerts(
            tester,
            snapshot: const AsyncValue<DcAlertSnapshot>.data(
              DcAlertSnapshot(
                upcomingEvents: 3,
                advancePending: 5,
                rentalsDue: 2,
              ),
            ),
          );

          // The DC branch renders each count via `_displayCount` — plain
          // decimal string. Verify the rendered counts match the values
          // supplied by the overridden provider.
          expect(find.text('3'), findsOneWidget);
          expect(find.text('5'), findsOneWidget);
          expect(find.text('2'), findsOneWidget);
        },
      );

      testWidgets('renders a second, distinct set of values (proves the widget '
          'consults the provider rather than a hardcoded literal)', (
        tester,
      ) async {
        await pumpDcAlerts(
          tester,
          snapshot: const AsyncValue<DcAlertSnapshot>.data(
            DcAlertSnapshot(
              upcomingEvents: 17,
              advancePending: 9,
              rentalsDue: 0,
            ),
          ),
        );

        expect(find.text('17'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);

        // The first set's values must not be present (proves the display
        // is driven by the provider value, not a fixed literal).
        expect(find.text('3'), findsNothing);
        expect(find.text('5'), findsNothing);
      });

      testWidgets(
        'shows "..." while dcAlertCountsProvider is loading (proves the '
        'widget reads the provider\'s async state instead of rendering a '
        'fixed value)',
        (tester) async {
          tester.view.physicalSize = const Size(1000, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          SharedPreferences.setMockInitialValues(<String, Object>{});

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                businessTypeProvider.overrideWith(
                  () => _DcBusinessTypeNotifier(),
                ),
                alertCountsProvider.overrideWithValue(
                  const AsyncValue<Map<String, int>>.data(<String, int>{}),
                ),
                dcAlertCountsProvider.overrideWithValue(
                  const AsyncValue<DcAlertSnapshot>.loading(),
                ),
              ],
              child: const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: SingleChildScrollView(child: BusinessAlertsWidget()),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          // When dcSnapshot is null (loading/orElse), the widget renders
          // '...' for each of the three DC alert cards.
          expect(find.text('...'), findsNWidgets(3));
        },
      );

      testWidgets('other business types (e.g. grocery) are unaffected by '
          'dcAlertCountsProvider overrides', (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessTypeProvider.overrideWith(
                () => _GroceryBusinessTypeNotifier(),
              ),
              // Grocery branch reads lowStock/expiringSoon from
              // alertCountsProvider — dcAlertCountsProvider override
              // below must have no effect on it.
              alertCountsProvider.overrideWithValue(
                const AsyncValue<Map<String, int>>.data(<String, int>{
                  'lowStock': 11,
                  'expiringSoon': 6,
                }),
              ),
              dcAlertCountsProvider.overrideWithValue(
                const AsyncValue<DcAlertSnapshot>.data(
                  DcAlertSnapshot(
                    upcomingEvents: 42,
                    advancePending: 43,
                    rentalsDue: 44,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SingleChildScrollView(child: BusinessAlertsWidget()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Grocery (the default businessTypeProvider state) displays its
        // own counts from alertCountsProvider.
        expect(find.text('11'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);

        // The DC provider's values must not leak into the grocery branch.
        expect(find.text('42'), findsNothing);
        expect(find.text('43'), findsNothing);
        expect(find.text('44'), findsNothing);
      });
    },
  );
}
