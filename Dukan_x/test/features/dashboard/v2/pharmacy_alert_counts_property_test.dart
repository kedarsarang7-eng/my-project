// ============================================================================
// Task 12.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 19: Pharmacy alert counts
//   reflect the live, tenant-filtered map.
// **Validates: Requirements 15.1, 15.3, 15.4, 15.5**
// ============================================================================
// Property 19 (design.md): For ANY live `counts` map (including null, empty, or
//   maps missing keys) and active tenantId, each pharmacy alert card renders
//   the value for its key counting only records matching the active tenantId,
//   rendering 0 when the key is absent/null and capping any value above 999 as
//   "999+".
//
// UNIT UNDER TEST
//   The pharmacy branch of `BusinessAlertsWidget` (the production widget). The
//   widget consumes the tenant-scoped `counts` map exposed by
//   `alertCountsProvider` and derives each card's displayed count as
//   `_displayCount(counts[key] ?? 0)` — i.e. missing/null keys render "0"
//   (R15.3) and values above 999 render "999+" (R15.5). The counts come from
//   the live provider map, never hardcoded placeholders (R15.1). Because the
//   provider is already tenant-scoped upstream, the widget's contract is to
//   render EXACTLY the supplied map's values; this test pins that contract so
//   only the (tenant-filtered) map can drive the displayed numbers (R15.4).
//
//   `_displayCount` is a private static helper, so rather than duplicate its
//   arithmetic we exercise the REAL widget end-to-end: the pharmacy cards each
//   publish a merged `Semantics` label that embeds the displayed count (e.g.
//   "Critical Stock H1 and X schedule drugs low: 999+ items"). Asserting on the
//   exact rendered semantics label proves the real derivation produced the
//   expected display string for every generated map.
//
// APPROACH (per the repo's no-`forAll`-re-pump-inside-one-`testWidgets`
//   convention is about throwing inside `forAll`; here we instead draw a
//   DETERMINISTIC, deduplicated sample of >= 100 generated `counts` maps from a
//   `dartproptest` Generator with a FIXED seed and pump each one, so the sweep
//   is reproducible). Boundary maps (998/999/1000/1001, empty, key-missing) are
//   pinned in addition to the random sample so the cap edge is always covered.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (glados is unresolvable here; see pubspec dev_dependency
//   note). It composes cleanly with `flutter_test`.
//
// Run: flutter test test/features/dashboard/v2/pharmacy_alert_counts_property_test.dart -r expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

/// Minimal notifier that pins the business type to pharmacy without touching
/// SharedPreferences / the license graph, so the widget renders the pharmacy
/// alert branch deterministically.
class _PharmacyBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.pharmacy);
}

/// The three live-count keys the pharmacy branch reads from the `counts` map.
const String _kCriticalKey = 'criticalStock';
const String _kExpiredKey = 'expired';
const String _kExpiringKey = 'expiringSoon';

/// Re-implements the widget's display contract for the EXPECTED value only:
/// a missing/null key resolves to 0 (R15.3) and any value above 999 caps to
/// "999+" (R15.5). The assertion compares this expectation against the REAL
/// rendered semantics label, so the production `_displayCount` is what is
/// actually being validated.
String _expectedDisplay(Map<String, int> counts, String key) {
  final int value = counts[key] ?? 0;
  return value > 999 ? '999+' : value.toString();
}

String _criticalLabel(String disp) =>
    'Critical Stock H1 and X schedule drugs low: $disp items';
String _expiredLabel(String disp) =>
    'Expired Medicines, immediate action required: $disp items';
String _expiringLabel(String disp) =>
    'Expiring This Week, review for returns: $disp items';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // >= 100 generated maps are required; 110 random + the pinned boundary maps
  // comfortably exceeds the minimum while keeping the suite fast.
  const int kGeneratedCount = 110;

  // Whether the pharmacy vertical exposes the "Expiring This Week" card is
  // resolved by the SAME capability lookup the widget uses, so the assertions
  // mirror the production branch exactly.
  final BusinessCapabilities pharmacyCaps = BusinessCapabilities.get(
    BusinessType.pharmacy,
  );
  final bool supportsExpiry = pharmacyCaps.supportsExpiry;

  // Generator: for each of the three keys independently decide presence (a
  // missing key must render 0) and, when present, a value spanning 0..2000 so
  // the 999/1000 cap boundary is exercised. The presence pool is skewed toward
  // present so both present and absent keys appear across the sample.
  final Generator<Map<String, int>> countsGen =
      Gen.tuple(<Generator>[
        Gen.elementOf<bool>(<bool>[true, false, true]),
        Gen.interval(0, 2000),
        Gen.elementOf<bool>(<bool>[true, false, true]),
        Gen.interval(0, 2000),
        Gen.elementOf<bool>(<bool>[true, false, true]),
        Gen.interval(0, 2000),
      ]).map((parts) {
        final map = <String, int>{};
        if (parts[0] as bool) map[_kCriticalKey] = parts[1] as int;
        if (parts[2] as bool) map[_kExpiredKey] = parts[3] as int;
        if (parts[4] as bool) map[_kExpiringKey] = parts[5] as int;
        return map;
      });

  // Pinned boundary / degenerate maps: empty map and key-missing maps (all → 0,
  // R15.3) plus the values straddling the cap edge (R15.5).
  final List<Map<String, int>> pinned = <Map<String, int>>[
    <String, int>{}, // empty → every card 0
    <String, int>{_kCriticalKey: 0, _kExpiredKey: 0, _kExpiringKey: 0},
    <String, int>{_kCriticalKey: 5}, // expired/expiring keys missing → 0
    <String, int>{_kCriticalKey: 998, _kExpiredKey: 999, _kExpiringKey: 1000},
    <String, int>{_kCriticalKey: 1000, _kExpiredKey: 1001, _kExpiringKey: 2000},
    <String, int>{_kExpiredKey: 1500}, // critical/expiring missing → 0
  ];

  final List<Map<String, int>> cases = <Map<String, int>>[
    ...pinned,
    ..._sampleMaps(countsGen, kGeneratedCount),
  ];

  group(
    'Feature: pharmacy-vertical-remediation, Property 19: Pharmacy alert counts '
    'reflect the live, tenant-filtered map',
    () {
      testWidgets(
        'Property 19: pharmacy cards render counts[key] (missing/null → 0, '
        '> 999 → "999+") from the live map for ${cases.length} maps',
        (WidgetTester tester) async {
          // bySemanticsLabel requires the semantics tree to be built. The
          // handle must be disposed inside the test body (the disposal check
          // runs before addTearDown callbacks), so it is released explicitly
          // after the sweep below.
          final semantics = tester.ensureSemantics();

          // Generous surface so the three stacked cards never overflow.
          tester.view.physicalSize = const Size(1000, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // The fixed notifier overrides build(), so prefs are never read, but
          // initialise mock prefs defensively for any incidental access.
          SharedPreferences.setMockInitialValues(<String, Object>{});

          for (var i = 0; i < cases.length; i++) {
            final counts = cases[i];

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  businessTypeProvider.overrideWith(
                    () => _PharmacyBusinessTypeNotifier(),
                  ),
                  // Live counts map fed through the real provider seam as an
                  // already-resolved value, so the data branch renders
                  // immediately and the provider body (service-locator backed)
                  // never runs — only the supplied, already-tenant-scoped map
                  // can drive the displayed numbers (R15.1 / R15.4).
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
            // Let the single-value stream deliver so the widget leaves the
            // loading state and renders the data branch.
            await tester.pump();
            await tester.pump();

            final String criticalDisp = _expectedDisplay(counts, _kCriticalKey);
            final String expiredDisp = _expectedDisplay(counts, _kExpiredKey);
            final String expiringDisp = _expectedDisplay(counts, _kExpiringKey);

            final String where = 'case #${i + 1} counts=$counts';

            // R15.1 / R15.3 / R15.5 — critical-stock card always renders, value
            // sourced from counts['criticalStock'] (missing → 0, > 999 →
            // "999+").
            expect(
              find.bySemanticsLabel(_criticalLabel(criticalDisp)),
              findsOneWidget,
              reason:
                  '$where: critical-stock card should render "$criticalDisp".',
            );

            // R15.1 / R15.3 / R15.5 — expired card always renders.
            expect(
              find.bySemanticsLabel(_expiredLabel(expiredDisp)),
              findsOneWidget,
              reason: '$where: expired card should render "$expiredDisp".',
            );

            // R15.1 / R15.3 / R15.5 — expiring card renders iff the pharmacy
            // vertical supports expiry (mirrors the widget's capability gate).
            if (supportsExpiry) {
              expect(
                find.bySemanticsLabel(_expiringLabel(expiringDisp)),
                findsOneWidget,
                reason: '$where: expiring card should render "$expiringDisp".',
              );
            }
          }

          // Release the semantics handle before the test body ends so the
          // framework's end-of-test disposal verification passes.
          semantics.dispose();
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}

/// Draws a deterministic, deduplicated sample of [count] `counts` maps from
/// [gen] using a fixed seed, so the suite is fully reproducible run-to-run.
List<Map<String, int>> _sampleMaps(Generator<Map<String, int>> gen, int count) {
  final rand = Random('pharmacy-vertical-remediation-property-19');
  final seen = <String>{};
  final out = <Map<String, int>>[];
  var guard = 0;
  while (out.length < count && guard < count * 50) {
    guard++;
    final map = gen.generate(rand).value;
    // Canonical key for dedup: sorted entries.
    final keys = map.keys.toList()..sort();
    final canonical = keys.map((k) => '$k=${map[k]}').join('|');
    if (seen.add(canonical)) out.add(map);
  }
  return out;
}
