// ============================================================================
// PHASE 4 — Task 22.4: PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 30: Pharmacy cards carry
//          non-empty semantic labels
// **Validates: Requirements 26.4, 26.5**
// ============================================================================
//
// Property 30 (design.md — Correctness Properties):
//   *For any* rendered pharmacy quick-action card or alert card, a non-empty
//   semantic accessibility label conveying the card's action or content is
//   attached.
//
// REQUIREMENTS
//   R26.4: WHEN a pharmacy quick-action card is rendered, THE System SHALL
//          attach a non-empty semantic accessibility label that conveys the
//          card's action to assistive technologies.
//   R26.5: WHEN a pharmacy alert card is rendered, THE System SHALL attach a
//          non-empty semantic accessibility label that conveys the alert's
//          content to assistive technologies.
//
// THE PRODUCTION RULE UNDER TEST (task 22.3):
//   * Quick-action cards — `BusinessQuickActions._buildActionButton` wraps the
//     pharmacy tiles in `Semantics(label: <fixed string>, button: true)`. The
//     pharmacy branch supplies three fixed labels:
//        - 'New Prescription, create a new prescription'
//        - 'Drug Lookup, search the medicine master'   (gated on
//          caps.supportsPrescriptions)
//        - 'H1 Register, open the H1 schedule drug register'
//   * Alert cards — `BusinessAlertsWidget._buildAlertItem` wraps the pharmacy
//     alert rows in `Semantics(label: <derived string>)`. The label embeds the
//     displayed count via `_displayCount(n) = n > 999 ? '999+' : n.toString()`:
//        - 'Critical Stock H1 and X schedule drugs low: <disp> items'
//        - 'Expired Medicines, immediate action required: <disp> items'
//        - 'Expiring This Week, review for returns: <disp> items'  (gated on
//          caps.supportsExpiry)
//
// WHAT THIS SUITE PROVES:
//   1. ALERT-LABEL PROPERTY (generated, 200 runs): for ANY arbitrary `counts`
//      map (keys present/absent, values negative/zero/small/>999) the alert
//      label derived by the SAME derivation production uses is always non-empty
//      and well-formed (carries the displayed count and the " items" suffix).
//   2. QUICK-ACTION PROPERTY (generated, 200 runs): for ANY pharmacy
//      quick-action drawn from the fixed action set, its fixed semantic label
//      is non-empty and well-formed ("<action>, <description>").
//   3. WIDGET ANCHORS: the REAL `BusinessAlertsWidget` and
//      `BusinessQuickActions` are pumped for the pharmacy vertical; every label
//      the pure derivation predicts is asserted PRESENT and non-empty on the
//      live render tree — binding the pure properties to production output so
//      neither is vacuous.
//
// PBT library: dartproptest ^0.2.1 (repo-standard).
//   `Gen.tuple([...]).map(...)` builds one `counts` map per run;
//   `forAll((case) => <bool>, [gen], numRuns: N)` returns true iff the property
//   held for every generated case.
//
// Run: flutter test test/features/pharmacy/pharmacy_semantic_labels_property30_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_quick_actions.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';

/// At least 100 generated cases are required by the spec; 200 matches the
/// convention used across this repo's property suites.
const int kNumRuns = 200;

const String _kCriticalKey = 'criticalStock';
const String _kExpiredKey = 'expired';
const String _kExpiringKey = 'expiringSoon';

// ============================================================================
// PURE DERIVATION — mirrors `BusinessAlertsWidget` (alert cards) and
// `BusinessQuickActions` (quick-action cards) EXACTLY. The widget anchors below
// assert these same strings on the live render tree, proving the mirror is
// faithful to production.
// ============================================================================

/// Mirrors `BusinessAlertsWidget._displayCount` (R15.5): >999 caps to "999+".
String _displayCount(int n) => n > 999 ? '999+' : n.toString();

String _criticalLabel(String disp) =>
    'Critical Stock H1 and X schedule drugs low: $disp items';
String _expiredLabel(String disp) =>
    'Expired Medicines, immediate action required: $disp items';
String _expiringLabel(String disp) =>
    'Expiring This Week, review for returns: $disp items';

/// The pharmacy quick-action cards' fixed semantic labels (R26.4). `gated`
/// marks the "Drug Lookup" tile, which only renders when the pharmacy vertical
/// is granted `supportsPrescriptions`.
class _QuickAction {
  const _QuickAction(this.label, {this.gated = false});
  final String label;
  final bool gated;
}

const List<_QuickAction> _pharmacyQuickActions = <_QuickAction>[
  _QuickAction('New Prescription, create a new prescription'),
  _QuickAction('Drug Lookup, search the medicine master', gated: true),
  _QuickAction('H1 Register, open the H1 schedule drug register'),
];

/// A semantic label is "well-formed" for an alert card when it is non-empty,
/// embeds the displayed count, and ends with the " items" suffix — i.e. it
/// actually conveys the alert's content (R26.5) rather than being a blank or
/// placeholder string.
bool _wellFormedAlertLabel(String label, String disp) =>
    label.isNotEmpty && label.contains(': ') && label.endsWith('$disp items');

/// A quick-action label is "well-formed" when it is non-empty and reads as
/// "<action>, <description>" with both halves non-empty — i.e. it conveys the
/// card's action (R26.4).
bool _wellFormedActionLabel(String label) {
  if (label.isEmpty || !label.contains(', ')) return false;
  final int i = label.indexOf(', ');
  final String action = label.substring(0, i);
  final String description = label.substring(i + 2);
  return action.isNotEmpty && description.isNotEmpty;
}

// ============================================================================
// INPUT SPACE — arbitrary `counts` maps.
//   Each of the three relevant keys is independently present or absent, and its
//   value ranges over negatives, zero, small counts, and values above the 999
//   display cap. Absent keys exercise the production `?? 0` fallback (R15.3).
// ============================================================================

final Generator<Map<String, int>> _countsGen =
    Gen.tuple([
      Gen.elementOf<bool>(<bool>[true, false]), // criticalStock present?
      Gen.interval(-50, 5000), // criticalStock value
      Gen.elementOf<bool>(<bool>[true, false]), // expired present?
      Gen.interval(-50, 5000), // expired value
      Gen.elementOf<bool>(<bool>[true, false]), // expiringSoon present?
      Gen.interval(-50, 5000), // expiringSoon value
    ]).map((parts) {
      final counts = <String, int>{};
      if (parts[0] as bool) counts[_kCriticalKey] = parts[1] as int;
      if (parts[2] as bool) counts[_kExpiredKey] = parts[3] as int;
      if (parts[4] as bool) counts[_kExpiringKey] = parts[5] as int;
      return counts;
    });

// ============================================================================
// WIDGET SEAM — pins the pharmacy branch without touching SharedPreferences or
// the license graph (mirrors pharmacy_alert_counts_test.dart).
// ============================================================================

class _PharmacyBusinessTypeNotifier extends BusinessTypeNotifier {
  @override
  BusinessTypeState build() => BusinessTypeState(type: BusinessType.pharmacy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Capability gates the widget itself applies, mirrored so the anchors only
  // assert on cards that actually render for the pharmacy vertical.
  final BusinessCapabilities caps = BusinessCapabilities.get(
    BusinessType.pharmacy,
  );
  final bool supportsExpiry = caps.supportsExpiry;
  final bool supportsPrescriptions = caps.supportsPrescriptions;

  /// Pumps the pharmacy alerts widget with the supplied live [counts] map and
  /// returns the semantics handle (caller disposes).
  Future<SemanticsHandle> pumpAlerts(
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
    await tester.pump();
    await tester.pump();
    return semantics;
  }

  /// Pumps the pharmacy quick-actions widget and returns the semantics handle.
  Future<SemanticsHandle> pumpQuickActions(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 1600);
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
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SingleChildScrollView(child: BusinessQuickActions()),
          ),
        ),
      ),
    );
    await tester.pump();
    return semantics;
  }

  group('Feature: pharmacy-vertical-remediation, Property 30: Pharmacy cards '
      'carry non-empty semantic labels', () {
    // ----------------------------------------------------------------------
    // PROPERTY 30a — alert cards: derived label is always non-empty and
    // well-formed for ANY arbitrary counts map (R26.5).
    // ----------------------------------------------------------------------
    test('Property 30: every pharmacy alert card label is non-empty and '
        'well-formed for any counts map (R26.5)', () {
      final bool held = forAll(
        (Map<String, int> counts) {
          final String crit = _displayCount(counts[_kCriticalKey] ?? 0);
          final String exp = _displayCount(counts[_kExpiredKey] ?? 0);
          final String expg = _displayCount(counts[_kExpiringKey] ?? 0);

          // The two always-present cards plus the expiry card (rendered only
          // when the vertical supports expiry, matching production gating).
          final labels = <MapEntry<String, String>>[
            MapEntry(_criticalLabel(crit), crit),
            MapEntry(_expiredLabel(exp), exp),
            if (supportsExpiry) MapEntry(_expiringLabel(expg), expg),
          ];

          return labels.every((e) => _wellFormedAlertLabel(e.key, e.value));
        },
        [_countsGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Every pharmacy alert card must carry a non-empty, well-formed '
            'semantic label embedding its displayed count (Property 30, R26.5).',
      );
    });

    // ----------------------------------------------------------------------
    // PROPERTY 30b — quick-action cards: each fixed label in the pharmacy
    // action set is non-empty and well-formed (R26.4).
    // ----------------------------------------------------------------------
    test('Property 30: every pharmacy quick-action card label is non-empty '
        'and well-formed (R26.4)', () {
      final bool held = forAll(
        (_QuickAction action) => _wellFormedActionLabel(action.label),
        [Gen.elementOf<_QuickAction>(_pharmacyQuickActions)],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Every pharmacy quick-action card must carry a non-empty, '
            'well-formed semantic label conveying its action (Property 30, '
            'R26.4).',
      );
    });

    // ----------------------------------------------------------------------
    // WIDGET ANCHOR — alert cards: the live BusinessAlertsWidget actually
    // attaches each predicted non-empty label across representative maps,
    // binding Property 30a to production output.
    // ----------------------------------------------------------------------
    testWidgets('Property 30 anchor: live pharmacy alert cards attach the '
        'predicted non-empty labels (R26.5)', (tester) async {
      // Representative maps spanning the input space: typical, missing-key,
      // boundary (999), and over-cap (>999) values.
      final maps = <Map<String, int>>[
        <String, int>{_kCriticalKey: 7, _kExpiredKey: 3, _kExpiringKey: 15},
        <String, int>{_kCriticalKey: 5}, // others absent -> 0
        <String, int>{
          _kCriticalKey: 999,
          _kExpiredKey: 999,
          _kExpiringKey: 999,
        },
        <String, int>{
          _kCriticalKey: 1000,
          _kExpiredKey: 5000,
          _kExpiringKey: 1500,
        },
        <String, int>{}, // entirely empty -> all 0
      ];

      for (final counts in maps) {
        final semantics = await pumpAlerts(tester, counts);

        final String crit = _displayCount(counts[_kCriticalKey] ?? 0);
        final String exp = _displayCount(counts[_kExpiredKey] ?? 0);
        final String expg = _displayCount(counts[_kExpiringKey] ?? 0);

        final critLabel = _criticalLabel(crit);
        final expLabel = _expiredLabel(exp);
        expect(critLabel, isNotEmpty);
        expect(expLabel, isNotEmpty);
        expect(find.bySemanticsLabel(critLabel), findsOneWidget);
        expect(find.bySemanticsLabel(expLabel), findsOneWidget);
        if (supportsExpiry) {
          final expgLabel = _expiringLabel(expg);
          expect(expgLabel, isNotEmpty);
          expect(find.bySemanticsLabel(expgLabel), findsOneWidget);
        }

        semantics.dispose();
      }
    });

    // ----------------------------------------------------------------------
    // WIDGET ANCHOR — quick-action cards: the live BusinessQuickActions
    // attaches each predicted non-empty label, binding Property 30b to
    // production output.
    // ----------------------------------------------------------------------
    testWidgets('Property 30 anchor: live pharmacy quick-action cards attach '
        'the predicted non-empty labels (R26.4)', (tester) async {
      final semantics = await pumpQuickActions(tester);

      for (final action in _pharmacyQuickActions) {
        if (action.gated && !supportsPrescriptions) continue;
        expect(action.label, isNotEmpty);
        // The explicit Semantics label is attached, then merged with the
        // tile's own visible Text (the InkWell button merges its descendants),
        // so the rendered node label is e.g. "<semanticLabel>\n<tile text>".
        // The card therefore CARRIES the non-empty action label (R26.4); match
        // it as a substring of the merged node label.
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(action.label))),
          findsOneWidget,
          reason:
              'Pharmacy quick-action card "${action.label}" must expose its '
              'non-empty semantic label (Property 30, R26.4).',
        );
      }

      semantics.dispose();
    });
  });
}
