// ============================================================================
// Task 12.3 — WIDGET TEST (example-based)
// Feature: pharmacy-vertical-remediation
// **Validates: Requirements 15.6**
// ============================================================================
// R15.6: The System SHALL include an automated test verifying that the pharmacy
//   alert cards render the critical-stock, expired, and expiring values from a
//   supplied live `counts` map rather than hardcoded values.
//
// UNIT UNDER TEST
//   The pharmacy branch of `BusinessAlertsWidget`. It reads
//   `counts['criticalStock']`, `counts['expired']`, and `counts['expiringSoon']`
//   from the live `alertCountsProvider` map and renders each via `_displayCount`
//   (missing/null → 0, value > 999 → "999+"). This test pins that the rendered
//   numbers track the SUPPLIED map rather than any hardcoded placeholder by
//   pumping two distinct maps and asserting each renders its own supplied
//   values, plus the boundary/missing-key behaviour.
//
// HOW WE ASSERT
//   `_displayCount` is private, and the rendered count badge is a bare `Text`
//   that could collide across cards. Each pharmacy card publishes a merged
//   `Semantics` label that embeds its displayed count (e.g.
//   "Critical Stock H1 and X schedule drugs low: 7 items"), so we assert on the
//   exact semantics label — this exercises the real production derivation.
//
//   `businessTypeProvider` is overridden to pin the pharmacy branch, and
//   `alertCountsProvider` is overridden with an already-resolved value so the
//   service-locator-backed provider body never runs; only the supplied map can
//   drive the displayed numbers.
//
// Run: flutter test test/features/pharmacy/pharmacy_alert_counts_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

/// Pins the business type to pharmacy without touching SharedPreferences or the
/// license graph, so the widget renders the pharmacy alert branch.
class _PharmacyBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.pharmacy);
}

const String _kCriticalKey = 'criticalStock';
const String _kExpiredKey = 'expired';
const String _kExpiringKey = 'expiringSoon';

String _criticalLabel(String disp) =>
    'Critical Stock H1 and X schedule drugs low: $disp items';
String _expiredLabel(String disp) =>
    'Expired Medicines, immediate action required: $disp items';
String _expiringLabel(String disp) =>
    'Expiring This Week, review for returns: $disp items';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The "Expiring This Week" card is gated by the same capability lookup the
  // widget uses, so mirror that gate in the assertions.
  final bool supportsExpiry = BusinessCapabilities.get(
    BusinessType.pharmacy,
  ).supportsExpiry;

  /// Pumps the pharmacy alerts widget with the supplied live [counts] map.
  Future<SemanticsHandle> pumpWithCounts(
    WidgetTester tester,
    Map<String, int> counts,
  ) async {
    final semantics = tester.ensureSemantics();

    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessTypeProvider.overrideWith(
            () => _PharmacyBusinessTypeNotifier(),
          ),
          // Supply the live counts map through the real provider seam as an
          // already-resolved value: the provider body never runs, so only the
          // supplied map can drive the rendered numbers (R15.6).
          alertCountsProvider.overrideWithValue(
            AsyncValue<Map<String, int>>.data(counts),
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
    // Let the single-value stream deliver so the data branch renders.
    await tester.pump();
    await tester.pump();

    return semantics;
  }

  group('Feature: pharmacy-vertical-remediation — pharmacy alert cards render '
      'supplied live counts (R15.6)', () {
    testWidgets('renders the exact supplied critical/expired/expiring values', (
      tester,
    ) async {
      final semantics = await pumpWithCounts(tester, <String, int>{
        _kCriticalKey: 7,
        _kExpiredKey: 3,
        _kExpiringKey: 15,
      });

      expect(find.bySemanticsLabel(_criticalLabel('7')), findsOneWidget);
      expect(find.bySemanticsLabel(_expiredLabel('3')), findsOneWidget);
      if (supportsExpiry) {
        expect(find.bySemanticsLabel(_expiringLabel('15')), findsOneWidget);
      }

      semantics.dispose();
    });

    testWidgets(
      'tracks a DIFFERENT supplied map (proves values are not hardcoded)',
      (tester) async {
        // A second, distinct map must produce distinct rendered values. If the
        // pharmacy branch used hardcoded placeholders, these would not appear.
        final semantics = await pumpWithCounts(tester, <String, int>{
          _kCriticalKey: 42,
          _kExpiredKey: 99,
          _kExpiringKey: 1,
        });

        expect(find.bySemanticsLabel(_criticalLabel('42')), findsOneWidget);
        expect(find.bySemanticsLabel(_expiredLabel('99')), findsOneWidget);
        if (supportsExpiry) {
          expect(find.bySemanticsLabel(_expiringLabel('1')), findsOneWidget);
        }

        // And the values from the first map must NOT be present here.
        expect(find.bySemanticsLabel(_criticalLabel('7')), findsNothing);
        expect(find.bySemanticsLabel(_expiredLabel('3')), findsNothing);

        semantics.dispose();
      },
    );

    testWidgets('caps values above 999 as "999+" (R15.5 display contract)', (
      tester,
    ) async {
      final semantics = await pumpWithCounts(tester, <String, int>{
        _kCriticalKey: 1000,
        _kExpiredKey: 5000,
        _kExpiringKey: 1500,
      });

      expect(find.bySemanticsLabel(_criticalLabel('999+')), findsOneWidget);
      expect(find.bySemanticsLabel(_expiredLabel('999+')), findsOneWidget);
      if (supportsExpiry) {
        expect(find.bySemanticsLabel(_expiringLabel('999+')), findsOneWidget);
      }

      semantics.dispose();
    });

    testWidgets('renders exactly 999 (boundary) without capping', (
      tester,
    ) async {
      final semantics = await pumpWithCounts(tester, <String, int>{
        _kCriticalKey: 999,
        _kExpiredKey: 999,
        _kExpiringKey: 999,
      });

      expect(find.bySemanticsLabel(_criticalLabel('999')), findsOneWidget);
      expect(find.bySemanticsLabel(_expiredLabel('999')), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('renders 0 for missing keys without error', (tester) async {
      // Only the critical key is present; expired/expiring keys are absent
      // and must render 0 (R15.3).
      final semantics = await pumpWithCounts(tester, <String, int>{
        _kCriticalKey: 5,
      });

      expect(find.bySemanticsLabel(_criticalLabel('5')), findsOneWidget);
      expect(find.bySemanticsLabel(_expiredLabel('0')), findsOneWidget);
      if (supportsExpiry) {
        expect(find.bySemanticsLabel(_expiringLabel('0')), findsOneWidget);
      }

      semantics.dispose();
    });

    testWidgets('renders 0 for every card on an empty counts map', (
      tester,
    ) async {
      final semantics = await pumpWithCounts(tester, <String, int>{});

      expect(find.bySemanticsLabel(_criticalLabel('0')), findsOneWidget);
      expect(find.bySemanticsLabel(_expiredLabel('0')), findsOneWidget);
      if (supportsExpiry) {
        expect(find.bySemanticsLabel(_expiringLabel('0')), findsOneWidget);
      }

      semantics.dispose();
    });
  });
}
