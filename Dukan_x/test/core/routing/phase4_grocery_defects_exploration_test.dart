// ============================================================================
// PHASE 4 — Task 5.1: Grocery defect exploration tests (4a–4d)
// (go_router navigation migration — grocery functional fixes)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 5.1 — Write exploration tests for the four grocery defects.
// Validates: Requirements 2.1
//
// PURPOSE (exploration / bug baseline — MUST PASS against UNCHANGED code):
//   Phase 4 fixes four audit-confirmed grocery defects. Per the test-first
//   protocol (Requirement 2), each behavioral change ships as a triple:
//   exploration (this file) → fix → preservation. Every test below documents
//   the AS-IS defect and passes against the current, unchanged production code.
//   The fixes are Tasks 5.2/5.4/5.5/5.7; the preservation tests are Task 5.9.
//
//   THE FOUR DEFECTS AND THE SEAM CHOSEN FOR EACH:
//
//   4a — WeighingScaleWidget is orphaned AND grocery billing has no loose-weight
//        (kg/gm) entry path.
//        SEAM 1 (orphan): a static grep over the whole `lib/` tree (same
//        technique as the Phase 0 smoke test) — the symbol `WeighingScaleWidget`
//        appears ONLY in its own definition file.
//        SEAM 2 (no grocery weight path): the ONLY weight-first entry sheet in
//        billing (`_showMandiEntrySheet`) is gated behind
//        `FeatureResolver.isMandiMode`, which is `type == vegetablesBroker`. So
//        grocery never reaches a kg/gm loose-weight trigger. We assert at the
//        `isMandiMode` seam (deterministic, no heavy screen pumped).
//
//   4b — grocery dashboard "Scan Barcode" quick action onTap is a no-op.
//        SEAM: the onTap is the empty closure `() {}`, which cannot be
//        introspected for emptiness at runtime. We assert at the most faithful
//        deterministic seam — a static source check of
//        `business_quick_actions.dart` — showing the grocery "Scan Barcode"
//        tile's onTap is `() {}` while its sibling "Quick Add Item" navigates.
//        LIMITATION: this proves the no-op at the source seam rather than by
//        pumping the live dashboard (which pulls Riverpod + navigation
//        infrastructure). See the test body note.
//
//   4c — grocery `supportsExpiry` is hardcoded false even though useBatchExpiry
//        IS granted to grocery; the expiring-soon alert never renders.
//        SEAM (contradiction): runtime — `BusinessCapabilities.get(grocery)
//        .supportsExpiry == false` WHILE `FeatureResolver.canAccess('grocery',
//        useBatchExpiry) == true`. SEAM (consequence): the alerts widget gates
//        the grocery expiry alert on `caps.supportsExpiry`, so a false value
//        suppresses it. The widget reads a Drift DB (heavy), so we assert the
//        consequence at the `supportsExpiry` value seam + a static check that
//        the widget branch is gated on it.
//
//   4d — manual/ad-hoc item entry in billing defaults `unit:'pcs'`, `gstRate:0`
//        (and cgst/sgst 0), ignoring grocery's configured `unitOptions`
//        (pcs, kg, gm, ltr, nos) and per-product tax rate.
//        SEAM: the default `BillItem` is constructed inline inside a dialog
//        builder in a large screen (`bill_creation_screen_v2.dart`, ~line 1200),
//        so it cannot be introspected without pumping the heavy screen. We
//        assert at the smallest faithful seam — a static source check that the
//        construction hardcodes `unit: 'pcs'` + `gstRate: 0` and does NOT read
//        the grocery config — and we contrast it with the grocery config which
//        DOES offer kg/gm. LIMITATION documented in the test body.
//
// TEST-ONLY: this task modifies NO production code. All four fixes are later
//   tasks. These tests intentionally pass today to document each AS-IS bug.
//
// ----------------------------------------------------------------------------
// RECONCILIATION (Task 5.9): Phases 4a/4b/4c/4d are now FIXED, so five
//   exploration assertions that documented the PRE-FIX state are historical and
//   would now fail. Per the exploration→fix→preservation methodology they are
//   marked `skip:` (with a descriptive reason and a comment preserving what the
//   pre-fix bug WAS) rather than deleted — keeping the historical intent
//   readable while the suite stays green. The POST-FIX assertions are OWNED by
//   `phase4_grocery_fixes_preservation_test.dart` (task 5.9), so coverage is
//   not weakened. The other exploration assertions in each group (the still-
//   true baselines: isMandiMode gating, the "Quick Add Item" contrast, the
//   alerts-widget gating seam, the grocery kg/gm config contrast) remain ACTIVE.
// ============================================================================

import 'dart:io';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/billing/feature_resolver.dart' as billing;
import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart' as iso;
import 'package:flutter_test/flutter_test.dart';

/// Reads a file under the Dukan_x package root (test cwd == package root).
String _readLibFile(String relativePath) {
  final file = File(relativePath);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Expected file to exist for the seam check: $relativePath',
  );
  return file.readAsStringSync();
}

/// Recursively collects every `.dart` file path under [dir].
List<File> _dartFilesUnder(Directory dir) {
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Normalizes Windows/POSIX separators for stable path comparison.
String _norm(String path) => path.replaceAll('\\', '/');

/// Returns the substring window of [source] of length [len] starting at the
/// first occurrence of [anchor], or '' if the anchor is absent.
String _windowAfter(String source, String anchor, {int len = 240}) {
  final idx = source.indexOf(anchor);
  if (idx < 0) return '';
  final end = (idx + len).clamp(0, source.length);
  return source.substring(idx, end);
}

void main() {
  final String grocery = BusinessType.grocery.name; // 'grocery'

  group('Feature: gorouter-navigation-migration — Phase 4 grocery defect '
      'exploration (Req 2.1)', () {
    // ======================================================================
    // 4a — WeighingScaleWidget is orphaned AND grocery has no loose-weight path
    // ======================================================================
    group('4a: WeighingScaleWidget orphaned + no grocery kg/gm weight path', () {
      const String defFileSuffix = 'lib/widgets/weighing_scale_widget.dart';
      const String symbol = 'WeighingScaleWidget';

      test(
        'SEAM 1 — "$symbol" is referenced NOWHERE in lib/ except its own '
        'definition file (orphaned widget)',
        () {
          final libDir = Directory('lib');
          final dartFiles = _dartFilesUnder(libDir);

          expect(
            dartFiles,
            isNotEmpty,
            reason:
                'lib/ must contain Dart files (test cwd should be the Dukan_x '
                'package root).',
          );

          final offenders = <String>[];
          for (final file in dartFiles) {
            final path = _norm(file.path);
            if (path.endsWith(defFileSuffix)) {
              // The definition file legitimately contains the symbol.
              continue;
            }
            if (file.readAsStringSync().contains(symbol)) {
              offenders.add(path);
            }
          }

          expect(
            offenders,
            isEmpty,
            reason:
                'BUG (4a): "$symbol" is built but never wired. It must appear '
                'only in its definition ($defFileSuffix). Found references in: '
                '$offenders. Task 5.2 wires it into grocery billing.',
          );

          // Sanity: the definition file DOES exist and defines the widget.
          final defContent = _readLibFile(defFileSuffix);
          expect(
            defContent.contains('class $symbol extends StatefulWidget'),
            isTrue,
            reason:
                'The orphaned widget must still be defined in $defFileSuffix.',
          );
        },
        // HISTORICAL: documented the PRE-FIX bug that `WeighingScaleWidget`
        // was built but never wired (referenced only in its own definition).
        // Task 5.2 wired it into grocery billing
        // (bill_creation_screen_v2.dart `_showGroceryWeightSheet` /
        // `_addWeighedGroceryItem`), so the orphan assertion is now FALSE by
        // design. The post-fix behavior is owned by
        // phase4_grocery_fixes_preservation_test.dart (task 5.9), group 4a.
        skip:
            'Superseded by Phase 4 fix — see phase4 preservation test '
            '(task 5.9)',
      );

      test('SEAM 2 — the ONLY weight-first billing sheet is gated to '
          'vegetablesBroker (isMandiMode); grocery has NO kg/gm trigger', () {
        // `_showMandiEntrySheet` (the kg/net-weight entry sheet) is the single
        // weight-first path in bill_creation_screen_v2.dart, and it is only
        // invoked when `FeatureResolver(type).isMandiMode` is true.
        final groceryResolver = billing.FeatureResolver(BusinessType.grocery);
        final mandiResolver = billing.FeatureResolver(
          BusinessType.vegetablesBroker,
        );

        expect(
          groceryResolver.isMandiMode,
          isFalse,
          reason:
              'BUG (4a): grocery is NOT mandi mode, so the only weight-entry '
              'sheet (_showMandiEntrySheet) is never triggered for grocery — '
              'no loose-weight (kg/gm) entry path exists today.',
        );
        expect(
          mandiResolver.isMandiMode,
          isTrue,
          reason:
              'Baseline: the weight sheet trigger (isMandiMode) is exclusive to '
              'vegetablesBroker, confirming the grocery gap is by exclusion.',
        );

        // Document the seam at the source: the weight sheet is invoked only
        // under an isMandiMode guard (never an unconditional grocery branch).
        final billSource = _readLibFile(
          'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
        );
        expect(
          billSource.contains('_showMandiEntrySheet'),
          isTrue,
          reason: 'The weight-entry sheet method must exist as the seam.',
        );
        expect(
          billSource.contains('features.isMandiMode'),
          isTrue,
          reason:
              'The weight sheet must be gated behind isMandiMode (mandi-only), '
              'documenting that grocery has no weight-entry trigger today.',
        );
      });
    });

    // ======================================================================
    // 4b — grocery "Scan Barcode" quick action onTap is a no-op
    // ======================================================================
    group('4b: grocery dashboard "Scan Barcode" onTap is a no-op', () {
      const String quickActionsFile =
          'lib/features/dashboard/v2/widgets/business_quick_actions.dart';

      // LIMITATION: an empty closure `() {}` cannot be introspected at runtime,
      // and pumping the live dashboard pulls Riverpod + navigation
      // infrastructure. We therefore assert at the source seam, which is exactly
      // what the grocery tile binds today.
      test(
        'the grocery "Scan Barcode" tile binds an EMPTY onTap closure '
        '(() {}) — no navigation',
        () {
          final source = _readLibFile(quickActionsFile);

          final scanWindow = _windowAfter(source, "label: 'Scan Barcode'");
          expect(
            scanWindow,
            isNotEmpty,
            reason:
                'The grocery "Scan Barcode" quick action must exist as the seam.',
          );
          expect(
            scanWindow.contains('onTap: () {}'),
            isTrue,
            reason:
                'BUG (4b): the grocery "Scan Barcode" tile binds onTap: () {} — '
                'a no-op. Task 5.4 routes it to the billing barcode flow. '
                'Window: $scanWindow',
          );
        },
        // HISTORICAL: documented the PRE-FIX bug that the grocery
        // "Scan Barcode" tile bound an empty `onTap: () {}` (a live, tappable
        // no-op). Task 5.4 changed it to
        // `onTap: () => nav.navigateTo(AppScreen.newSale)`, so the empty-
        // closure assertion is now FALSE by design. Post-fix behavior is
        // owned by phase4_grocery_fixes_preservation_test.dart (task 5.9),
        // group 4b.
        skip:
            'Superseded by Phase 4 fix — see phase4 preservation test '
            '(task 5.9)',
      );

      test('CONTRAST — the sibling "Quick Add Item" tile DOES navigate '
          '(proving the no-op is the anomaly)', () {
        final source = _readLibFile(quickActionsFile);

        final addWindow = _windowAfter(source, "label: 'Quick Add Item'");
        expect(
          addWindow,
          isNotEmpty,
          reason: 'The "Quick Add Item" tile must exist for contrast.',
        );
        expect(
          addWindow.contains('nav.navigateTo(AppScreen.stockEntry)'),
          isTrue,
          reason:
              'Baseline: "Quick Add Item" navigates to stockEntry, so a working '
              'tile pattern exists — "Scan Barcode" being empty is the bug.',
        );
      });

      test('the no-op tile IS reachable: grocery has the barcode-scan '
          'capability (so the tile renders)', () {
        final caps = BusinessCapabilities.get(BusinessType.grocery);
        expect(
          caps.supportsBarcodeScan,
          isTrue,
          reason:
              'grocery supportsBarcodeScan == true, so the "Scan Barcode" tile '
              'is rendered — making the empty onTap a live, tappable no-op.',
        );
      });
    });

    // ======================================================================
    // 4c — grocery supportsExpiry forced false despite useBatchExpiry granted
    // ======================================================================
    group('4c: grocery supportsExpiry contradicts the granted capability', () {
      test(
        'CONTRADICTION — supportsExpiry is FALSE for grocery WHILE '
        'useBatchExpiry IS granted to grocery',
        () {
          final caps = BusinessCapabilities.get(BusinessType.grocery);

          // The registry GRANTS useBatchExpiry to grocery...
          expect(
            iso.FeatureResolver.canAccess(
              grocery,
              BusinessCapability.useBatchExpiry,
            ),
            isTrue,
            reason:
                'grocery IS granted useBatchExpiry in businessCapabilityRegistry.',
          );

          // ...yet supportsExpiry is hardcoded false for grocery (the
          // `type != BusinessType.grocery` clause). This is the self-contradiction.
          expect(
            caps.supportsExpiry,
            isFalse,
            reason:
                'BUG (4c): supportsExpiry is forced false for grocery despite '
                'useBatchExpiry being granted. Task 5.5 removes the grocery clause.',
          );

          // The underlying batch flag (without the grocery clause) IS true,
          // proving the suppression is purely the special-cased clause.
          expect(
            caps.supportsBatch,
            isTrue,
            reason:
                'supportsBatch (no grocery special-case) is true for grocery — '
                'isolating the supportsExpiry suppression to the grocery clause.',
          );
        },
        // HISTORICAL: documented the PRE-FIX self-contradiction that grocery
        // `supportsExpiry` was forced FALSE despite `useBatchExpiry` being
        // granted. Task 5.5 removed the `type != BusinessType.grocery` clause
        // in business_capabilities.dart, so grocery.supportsExpiry is now
        // TRUE and the `isFalse` assertion is obsolete by design. Post-fix
        // behavior (and the multi-type non-regression of the supportsExpiry
        // map) is owned by phase4_grocery_fixes_preservation_test.dart
        // (task 5.9), group 4c.
        skip:
            'Superseded by Phase 4 fix — see phase4 preservation test '
            '(task 5.9)',
      );

      test(
        'CONSEQUENCE — the dashboard expiry alert is gated on '
        'caps.supportsExpiry, so it never renders for grocery',
        () {
          // The alerts widget builds the grocery expiry alert only when
          // `caps.supportsExpiry` is true. With it forced false, the alert is
          // suppressed regardless of expiring batches in the Drift DB. We assert
          // the gating at the source seam (the widget reads a real DB, so it is
          // not pumped here).
          final alertsSource = _readLibFile(
            'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
          );
          expect(
            alertsSource.contains('caps.supportsExpiry && expiringCount > 0'),
            isTrue,
            reason:
                'BUG (4c) consequence: the grocery expiry alert is gated on '
                'caps.supportsExpiry (false for grocery), so expiringSoon never '
                'surfaces.',
          );

          // Re-confirm the gate value the widget reads is false for grocery.
          expect(
            BusinessCapabilities.get(BusinessType.grocery).supportsExpiry,
            isFalse,
            reason:
                'The gate the alerts widget reads resolves to false for grocery, '
                'suppressing the expiry alert.',
          );
        },
        // HISTORICAL: documented the PRE-FIX consequence that, because
        // grocery `supportsExpiry` was false, the dashboard expiry alert
        // (gated on `caps.supportsExpiry && expiringCount > 0`) never
        // surfaced for grocery. After Task 5.5 the gate value is TRUE for
        // grocery, so the `isFalse` re-confirmation is obsolete by design.
        // The post-fix consequence (the same alert gating, now surfacing for
        // grocery) is owned by phase4_grocery_fixes_preservation_test.dart
        // (task 5.9), group 4c ("POST-FIX (consequence)").
        skip:
            'Superseded by Phase 4 fix — see phase4 preservation test '
            '(task 5.9)',
      );
    });

    // ======================================================================
    // 4d — manual/ad-hoc entry defaults ignore grocery unitOptions / tax rate
    // ======================================================================
    group('4d: manual entry defaults unit:pcs / gst:0 ignore grocery config', () {
      const String billFile =
          'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart';

      // LIMITATION: the default BillItem is constructed inline inside a dialog
      // builder in this large screen (~line 1200), so it cannot be introspected
      // without pumping the heavy screen + providers. We assert at the smallest
      // faithful seam: the hardcoded literals in the construction, and the
      // grocery config it ignores.
      test(
        'the ad-hoc/manual entry constructs BillItem with HARDCODED '
        "unit:'pcs' and gstRate:0 (cgst/sgst 0)",
        () {
          final source = _readLibFile(billFile);

          // The construction window starting at the hardcoded unit literal.
          final window = _windowAfter(source, "unit: 'pcs'", len: 120);
          expect(
            window,
            isNotEmpty,
            reason:
                "The manual-entry default must hardcode unit: 'pcs' as the seam.",
          );
          expect(
            window.contains('gstRate: 0'),
            isTrue,
            reason:
                "BUG (4d): manual entry hardcodes unit:'pcs' + gstRate:0, "
                'ignoring grocery config. Task 5.7 reads unitOptions/taxRate. '
                'Window: $window',
          );
          expect(
            window.contains('cgst: 0') && window.contains('sgst: 0'),
            isTrue,
            reason: 'The hardcoded default also zeroes cgst/sgst.',
          );

          // And the construction does NOT consult the grocery config (no read of
          // unitOptions / defaultGstRate / taxRate at this seam).
          expect(
            window.contains('unitOptions') ||
                window.contains('defaultGstRate') ||
                window.contains('taxRate'),
            isFalse,
            reason:
                'BUG (4d): the default line item ignores config — it reads no '
                'unitOptions/defaultGstRate/taxRate. Window: $window',
          );
        },
        // HISTORICAL: documented the PRE-FIX bug that the ad-hoc/manual entry
        // hardcoded `unit:'pcs'` + `gstRate:0` and ignored grocery config.
        // Task 5.7 rewrote this path to default the unit from the active
        // type's `unitOptions` (grocery → pcs/kg/gm/ltr/nos) via
        // `_defaultManualUnit` and to inherit a matched product's `taxRate`,
        // so the hardcoded-literal seam (`unit: 'pcs'`) no longer exists and
        // this assertion is obsolete by design. Post-fix behavior is owned by
        // phase4_grocery_fixes_preservation_test.dart (task 5.9), group 4d
        // (and the Task 5.7 unit test + Property 8 suite).
        skip:
            'Superseded by Phase 4 fix — see phase4 preservation test '
            '(task 5.9)',
      );

      test('CONTRAST — grocery config DOES offer kg/gm units (and an editable '
          'GST), which the hardcoded default ignores', () {
        final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);

        // Grocery is weight-capable: its unitOptions include kg and gm.
        expect(
          config.unitOptions,
          containsAll(<UnitType>[UnitType.kg, UnitType.gm]),
          reason:
              'grocery unitOptions include kg/gm (pcs, kg, gm, ltr, nos) — the '
              "hardcoded 'pcs' default ignores these.",
        );

        // GST is editable / per-product for grocery, so a flat 0 default
        // ignores the product-driven tax rate the fix should honor.
        expect(
          config.gstEditable,
          isTrue,
          reason:
              'grocery GST is editable (per product/config); the hardcoded '
              'gstRate:0 ignores the product tax rate.',
        );
      });
    });
  });
}
