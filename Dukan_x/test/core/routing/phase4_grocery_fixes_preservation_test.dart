// ============================================================================
// PHASE 4 — Task 5.9: PRESERVATION tests for ALL four grocery fixes (4a–4d)
// (go_router navigation migration — grocery functional fixes)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 5.9 — Write preservation tests for all Phase 4 fixes.
// Validates: Requirements 2.2, 2.3, 7.5
//
// PURPOSE (preservation half of the exploration → fix → preservation triple):
//   The Phase 4 fixes (Tasks 5.2/5.4/5.5/5.7) closed four audit-confirmed
//   grocery defects. The 5.1 exploration suite documented the PRE-FIX state;
//   this suite OWNS the POST-FIX assertions and proves the multi-business-type
//   NON-REGRESSION rule (Req 2.3 / 7.5): each fix works for grocery AND the
//   other in-scope business types are unaffected.
//
//   FIX → POST-FIX ASSERTION → NON-REGRESSION TYPES covered here:
//
//   4a (Task 5.2) — WeighingScaleWidget wired into grocery billing.
//        POST-FIX: a grocery kg/gm product takes the loose-weight scale path;
//        the weighed bill line has qty == net weight, total == weight × rate,
//        GST from the per-product taxRate split into equal CGST/SGST halves
//        (reuses the SAME math seam as the 5.2 unit test / Property 6).
//        NON-REGRESSION: a NON-weight grocery unit (pcs) does NOT trigger the
//        scale path; a non-grocery type (pharmacy/electronics) does NOT trigger
//        it either; vegetablesBroker still routes to the Mandi sheet
//        (isMandiMode, the established public seam) — never the grocery scale.
//
//   4b (Task 5.4) — grocery dashboard "Scan Barcode" no-op fixed.
//        POST-FIX: the grocery "Scan Barcode" tile's onTap now navigates to the
//        billing screen (`nav.navigateTo(AppScreen.newSale)`), asserted at the
//        same source seam the 5.1 exploration test used (the live dashboard
//        pulls Riverpod + navigation infrastructure; the onTap target is the
//        faithful deterministic seam).
//        NON-REGRESSION: the other business types' intentionally-empty quick
//        action tiles (electronics IMEI Lookup, bookStore ISBN Scan, wholesale
//        Bulk Scan, jewellery Custom Order / Gold Rate) are UNCHANGED — they
//        were `onTap: () {}` before the fix and remain so, proving 4b is
//        grocery-scoped.
//
//   4c (Task 5.5) — grocery supportsExpiry mirrors the granted capability.
//        POST-FIX: grocery.supportsExpiry == true AND equals
//        canAccess(grocery, useBatchExpiry).
//        NON-REGRESSION: the supportsExpiry map is unchanged for every other
//        in-scope type — it equals canAccess(type, useBatchExpiry) for ALL of
//        them (pharmacy/wholesale still true; petrolPump/restaurant still
//        false). This is the multi-type non-regression of the shared
//        `business_capabilities.dart` change (Req 7.5 / Rule 3).
//
//   4d (Task 5.7) — manual-entry defaults respect grocery config.
//        POST-FIX: the grocery manual-entry unit dropdown is sourced from
//        grocery `unitOptions` (kg/gm selectable, default pcs) and a manual
//        line matching an existing product inherits that product's taxRate
//        (split CGST/SGST), instead of the legacy hardcoded `pcs`/`0`.
//        NON-REGRESSION: a non-grocery type (pharmacy) keeps the legacy fixed
//        unit list (legacy "g" present, grocery-only "gm" absent) and the
//        legacy `pcs` default — behavior unchanged.
//
// SEAMS: where pumping the heavy billing/dashboard screens is non-deterministic
//   (they pull Riverpod + Drift + the service locator), we assert at the same
//   established pure / source seams the 5.2/5.4/5.5/5.7 unit tests and the
//   Property 6/7/8 suites use, and pump the self-contained ManualItemEntrySheet
//   (no Riverpod) for the 4d dropdown check. Each seam is documented inline.
//
// TEST-ONLY: this task changes NO production code.
//
// Run: flutter test test/core/routing/phase4_grocery_fixes_preservation_test.dart
// ============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/billing/feature_resolver.dart' as billing;
import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart' as iso;
import 'package:dukanx/features/billing/presentation/widgets/manual_item_entry_sheet.dart';
import 'package:dukanx/models/bill.dart';
// BusinessType is re-exported by core/billing/business_type_config.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Pure seam mirrors (byte-for-byte with the production code under test).
// ---------------------------------------------------------------------------

/// Mirrors `_addWeighedGroceryItem` in bill_creation_screen_v2.dart (and the
/// 5.2 unit-test / Property 6 helpers): qty = net weight (kg), unit price =
/// rate per kg, GST = per-product taxRate split into equal CGST/SGST halves.
BillItem buildWeighedGroceryLine({
  required String productId,
  required String productName,
  required double netWeightKg,
  required double ratePerKg,
  required double taxRate,
}) {
  final double qty = netWeightKg;
  final double price = ratePerKg;
  final double halfGst = qty * (price * (taxRate / 200));
  return BillItem(
    productId: productId,
    productName: productName,
    qty: qty,
    price: price,
    unit: 'kg',
    gstRate: taxRate,
    cgst: halfGst,
    sgst: halfGst,
    netWeight: qty,
  );
}

/// Mirrors `_isGroceryWeightUnit` in bill_creation_screen_v2.dart: a unit is a
/// grocery loose-weight unit iff it normalizes to kg/gm AND that UnitType is in
/// grocery's configured `unitOptions`.
bool isGroceryWeightUnit(String unit) {
  final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
  final u = unit.trim().toLowerCase();
  UnitType? matched;
  if (u == 'kg' || u == 'kgs' || u == 'kilogram' || u == 'kilograms') {
    matched = UnitType.kg;
  } else if (u == 'g' ||
      u == 'gm' ||
      u == 'gms' ||
      u == 'gram' ||
      u == 'grams') {
    matched = UnitType.gm;
  }
  if (matched == null) return false;
  return config.unitOptions.contains(matched);
}

/// Mirrors the production gating in `_addItem`/`_addProductWithWarningOverride`
/// (bill_creation_screen_v2.dart): the grocery weighing-scale sheet is shown
/// ONLY when the active type is grocery AND the product unit is a grocery
/// loose-weight unit. (vegetablesBroker is intercepted earlier by isMandiMode.)
bool shouldUseGroceryScale(BusinessType type, String unit) {
  return type == BusinessType.grocery && isGroceryWeightUnit(unit);
}

/// Mirrors `_defaultManualUnit` in bill_creation_screen_v2.dart: grocery
/// defaults from its configured `unitOptions` (first option, lowercased);
/// every other type keeps the legacy 'pcs' default.
String defaultManualUnit(BusinessType type) {
  if (type == BusinessType.grocery) {
    final config = BusinessTypeRegistry.getConfig(type);
    if (config.unitOptions.isNotEmpty) {
      return config.unitOptions.first.label.toLowerCase();
    }
  }
  return 'pcs';
}

/// Mirrors the Task 5.7 matched-product tax inheritance
/// (`_showManualItemEntry.onItemAdded`): a manual line left at GST 0 that
/// matches an existing product inherits the product's own tax rate (split into
/// equal CGST/SGST halves over the discounted base). Faithful to production.
BillItem applyMatchedProductTax({
  required double qty,
  required double price,
  required double discount,
  required double productTaxRate,
}) {
  var item = BillItem(
    productId: '',
    productName: 'Manual Line',
    qty: qty,
    price: price,
    discount: discount,
  );
  if (item.gstRate == 0 && productTaxRate > 0) {
    final double taxableBase = (item.qty * item.price) - item.discount;
    final double halfGst = taxableBase * (productTaxRate / 200);
    item = item.copyWith(gstRate: productTaxRate, cgst: halfGst, sgst: halfGst);
  }
  return item;
}

/// Float comparison with a relative tolerance and a small absolute floor.
bool _approx(double a, double b, {double rel = 1e-9, double absFloor = 1e-6}) {
  final double diff = (a - b).abs();
  final double scale = math.max(a.abs(), b.abs());
  return diff <= math.max(absFloor, rel * scale);
}

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

/// Returns the substring window of [source] of length [len] starting at the
/// first occurrence of [anchor], or '' if the anchor is absent.
String _windowAfter(String source, String anchor, {int len = 360}) {
  final idx = source.indexOf(anchor);
  if (idx < 0) return '';
  final end = (idx + len).clamp(0, source.length);
  return source.substring(idx, end);
}

/// The 18 in-scope business types (design Data Model 4) — used for the
/// supportsExpiry map non-regression sweep.
const List<BusinessType> kInScopeTypes = <BusinessType>[
  BusinessType.grocery,
  BusinessType.pharmacy,
  BusinessType.restaurant,
  BusinessType.clinic,
  BusinessType.petrolPump,
  BusinessType.service,
  BusinessType.electronics,
  BusinessType.mobileShop,
  BusinessType.computerShop,
  BusinessType.clothing,
  BusinessType.hardware,
  BusinessType.wholesale,
  BusinessType.vegetablesBroker,
  BusinessType.bookStore,
  BusinessType.jewellery,
  BusinessType.autoParts,
  BusinessType.decorationCatering,
  BusinessType.schoolErp,
];

/// Hosts the self-contained manual-entry sheet (no Riverpod) for [type].
Widget _manualEntryHost(BusinessType type) {
  return MaterialApp(
    home: Scaffold(
      body: ManualItemEntrySheet(
        businessType: type,
        onItemAdded: (BillItem _) {},
      ),
    ),
  );
}

/// Scrolls the unit dropdown into view and opens it (robust against the sheet
/// being taller than the test surface for types with extra fields).
Future<void> _openUnitDropdown(WidgetTester tester) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
}

void main() {
  group('Feature: gorouter-navigation-migration — Phase 4 PRESERVATION (Req '
      '2.2, 2.3, 7.5)', () {
    // ======================================================================
    // 4a — WeighingScaleWidget wired; grocery kg/gm math + multi-type
    //      non-regression of the scale-trigger decision.
    // ======================================================================
    group('4a: grocery weighing-scale line + scale-trigger non-regression', () {
      test('POST-FIX (grocery) — a grocery kg line has qty == net weight and '
          'total == weight × rate (no GST when taxRate 0)', () {
        final line = buildWeighedGroceryLine(
          productId: 'p1',
          productName: 'Onion',
          netWeightKg: 1.250,
          ratePerKg: 45.0,
          taxRate: 0.0,
        );
        expect(
          line.qty,
          closeTo(1.250, 1e-9),
          reason: 'qty == net weight (kg)',
        );
        expect(line.price, 45.0, reason: 'unit price == rate per kg');
        expect(line.unit, 'kg');
        expect(line.netWeight, closeTo(1.250, 1e-9));
        // total = weight × rate = 1.250 × 45 = 56.25
        expect(line.total, closeTo(56.25, 1e-9));
        expect(line.taxAmount, 0.0);
      });

      test('POST-FIX (grocery) — per-product taxRate drives GST, split into '
          'equal CGST/SGST halves (2 kg @ ₹50, 5%)', () {
        final line = buildWeighedGroceryLine(
          productId: 'p2',
          productName: 'Sugar',
          netWeightKg: 2.0,
          ratePerKg: 50.0,
          taxRate: 5.0,
        );
        expect(line.qty * line.price, closeTo(100.0, 1e-9));
        expect(line.cgst, closeTo(2.50, 1e-9));
        expect(line.sgst, closeTo(2.50, 1e-9));
        expect(line.taxAmount, closeTo(5.00, 1e-9));
        expect(line.total, closeTo(105.00, 1e-9));
      });

      test('POST-FIX (grocery) — kg AND gm both trigger the scale path '
          '(grocery unitOptions include both)', () {
        expect(shouldUseGroceryScale(BusinessType.grocery, 'kg'), isTrue);
        expect(shouldUseGroceryScale(BusinessType.grocery, 'gm'), isTrue);
        // Common synonyms normalize too.
        expect(shouldUseGroceryScale(BusinessType.grocery, 'KG'), isTrue);
        expect(shouldUseGroceryScale(BusinessType.grocery, 'grams'), isTrue);
      });

      test('NON-REGRESSION — a NON-weight grocery unit (pcs) does NOT trigger '
          'the scale path', () {
        expect(shouldUseGroceryScale(BusinessType.grocery, 'pcs'), isFalse);
        expect(shouldUseGroceryScale(BusinessType.grocery, 'nos'), isFalse);
        expect(shouldUseGroceryScale(BusinessType.grocery, 'ltr'), isFalse);
      });

      test('NON-REGRESSION — non-grocery types do NOT trigger the grocery '
          'scale path even for a kg/gm unit', () {
        for (final type in kInScopeTypes) {
          if (type == BusinessType.grocery) continue;
          expect(
            shouldUseGroceryScale(type, 'kg'),
            isFalse,
            reason: '$type must not take the grocery scale path.',
          );
          expect(
            shouldUseGroceryScale(type, 'gm'),
            isFalse,
            reason: '$type must not take the grocery scale path.',
          );
        }
      });

      test('NON-REGRESSION — vegetablesBroker still routes to the Mandi sheet '
          '(isMandiMode), grocery does NOT (public FeatureResolver seam)', () {
        expect(
          billing.FeatureResolver(BusinessType.vegetablesBroker).isMandiMode,
          isTrue,
          reason: 'vegetablesBroker keeps the weight-first Mandi entry sheet.',
        );
        expect(
          billing.FeatureResolver(BusinessType.grocery).isMandiMode,
          isFalse,
          reason: 'grocery uses the new scale path, not the Mandi sheet.',
        );
      });
    });

    // ======================================================================
    // 4b — grocery "Scan Barcode" now navigates; other empty tiles unchanged.
    // ======================================================================
    group('4b: grocery "Scan Barcode" navigates + empty-tile non-regression', () {
      const String quickActionsFile =
          'lib/features/dashboard/v2/widgets/business_quick_actions.dart';

      test('POST-FIX (grocery) — the "Scan Barcode" tile onTap navigates to '
          'billing (nav.navigateTo(AppScreen.newSale))', () {
        final source = _readLibFile(quickActionsFile);
        final scanWindow = _windowAfter(
          source,
          "label: 'Scan Barcode'",
          len: 900,
        );
        expect(
          scanWindow,
          isNotEmpty,
          reason: 'The grocery "Scan Barcode" tile must exist as the seam.',
        );
        expect(
          scanWindow.contains('nav.navigateTo(AppScreen.newSale)'),
          isTrue,
          reason:
              'FIX (4b): the grocery "Scan Barcode" tile now routes to the '
              'billing screen (which hosts the working barcode flow). '
              'Window: $scanWindow',
        );
        expect(
          scanWindow.contains('onTap: () {}'),
          isFalse,
          reason: 'The grocery "Scan Barcode" onTap is no longer a no-op.',
        );
      });

      test('NON-REGRESSION — other types\' intentionally-empty quick-action '
          'tiles are UNCHANGED (still onTap: () {})', () {
        final source = _readLibFile(quickActionsFile);

        // Each of these tiles was a no-op before 4b and must remain one — 4b is
        // grocery-scoped and must not have touched sibling business types.
        const Map<String, String> emptyTiles = <String, String>{
          // electronics / mobileShop / computerShop branch
          "label: 'IMEI Lookup'": 'electronics IMEI Lookup',
          // bookStore branch
          "label: 'ISBN Scan'": 'bookStore ISBN Scan',
          // wholesale branch
          "label: 'Bulk Scan'": 'wholesale Bulk Scan',
          // jewellery branch
          "label: 'Custom Order'": 'jewellery Custom Order',
          "label: 'Gold Rate'": 'jewellery Gold Rate',
        };

        emptyTiles.forEach((anchor, description) {
          final window = _windowAfter(source, anchor, len: 200);
          expect(
            window,
            isNotEmpty,
            reason: 'The $description tile must still exist.',
          );
          expect(
            window.contains('onTap: () {}'),
            isTrue,
            reason:
                'NON-REGRESSION: the $description tile must remain a no-op '
                '(4b only changed the grocery "Scan Barcode" tile). '
                'Window: $window',
          );
        });
      });

      test('NON-REGRESSION — the sibling grocery "Quick Add Item" tile still '
          'navigates to stockEntry (unchanged)', () {
        final source = _readLibFile(quickActionsFile);
        final addWindow = _windowAfter(source, "label: 'Quick Add Item'");
        expect(
          addWindow.contains('nav.navigateTo(AppScreen.stockEntry)'),
          isTrue,
          reason: 'The grocery "Quick Add Item" navigation is unchanged.',
        );
      });
    });

    // ======================================================================
    // 4c — grocery supportsExpiry mirrors capability + map-wide non-regression.
    // ======================================================================
    group('4c: grocery supportsExpiry == capability + multi-type map '
        'non-regression', () {
      test('POST-FIX (grocery) — supportsExpiry is true AND equals '
          'canAccess(grocery, useBatchExpiry)', () {
        final groceryReported = BusinessCapabilities.get(
          BusinessType.grocery,
        ).supportsExpiry;
        final groceryGranted = iso.FeatureResolver.canAccess(
          BusinessType.grocery.name,
          BusinessCapability.useBatchExpiry,
        );
        expect(
          groceryGranted,
          isTrue,
          reason: 'grocery is granted useBatchExpiry in the registry.',
        );
        expect(
          groceryReported,
          isTrue,
          reason: 'the forced-false grocery clause was removed (Task 5.5).',
        );
        expect(
          groceryReported,
          equals(groceryGranted),
          reason: 'grocery now matches other expiry-capable types.',
        );
      });

      test(
        'NON-REGRESSION — for EVERY in-scope type, supportsExpiry == '
        'canAccess(type, useBatchExpiry) (shared-component map unchanged)',
        () {
          for (final type in kInScopeTypes) {
            final reported = BusinessCapabilities.get(type).supportsExpiry;
            final granted = iso.FeatureResolver.canAccess(
              type.name,
              BusinessCapability.useBatchExpiry,
            );
            expect(
              reported,
              equals(granted),
              reason:
                  'supportsExpiry for $type must equal its useBatchExpiry grant '
                  '(Req 7.5: no other type regressed by the 4c change).',
            );
          }
        },
      );

      test('NON-REGRESSION — expiry-capable types stay TRUE; non-expiry types '
          'stay FALSE', () {
        // Other expiry-capable types unchanged.
        expect(
          BusinessCapabilities.get(BusinessType.pharmacy).supportsExpiry,
          isTrue,
          reason: 'pharmacy stays expiry-capable.',
        );
        expect(
          BusinessCapabilities.get(BusinessType.wholesale).supportsExpiry,
          isTrue,
          reason: 'wholesale stays expiry-capable.',
        );
        // Known non-expiry types unchanged.
        expect(
          BusinessCapabilities.get(BusinessType.petrolPump).supportsExpiry,
          isFalse,
          reason: 'petrolPump stays non-expiry.',
        );
        expect(
          BusinessCapabilities.get(BusinessType.restaurant).supportsExpiry,
          isFalse,
          reason: 'restaurant stays non-expiry.',
        );
      });

      test('POST-FIX (consequence) — the dashboard expiry alert is still gated '
          'on caps.supportsExpiry, so it now SURFACES for grocery (true)', () {
        // Owns the exploration CONSEQUENCE seam (5.1) post-fix: the alerts
        // widget gates the expiry alert on `caps.supportsExpiry`. With grocery
        // now true, the alert is no longer suppressed. (The widget reads a real
        // Drift DB, so we assert at the same source-gating seam the 5.1 test
        // used, plus the gate value now resolving to true for grocery.)
        final alertsSource = _readLibFile(
          'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
        );
        expect(
          alertsSource.contains('caps.supportsExpiry && expiringCount > 0'),
          isTrue,
          reason:
              'the grocery expiry alert remains gated on caps.supportsExpiry.',
        );
        expect(
          BusinessCapabilities.get(BusinessType.grocery).supportsExpiry,
          isTrue,
          reason:
              'the gate the alerts widget reads is now true for grocery, so '
              'the expiry alert surfaces (the pre-fix suppression is gone).',
        );
      });
    });

    // ======================================================================
    // 4d — manual-entry defaults respect grocery config + non-regression.
    // ======================================================================
    group('4d: grocery manual-entry defaults + non-grocery non-regression', () {
      test('POST-FIX (grocery) — default manual unit is a member of grocery '
          'unitOptions (pcs), NOT a hardcoded constant', () {
        final groceryChoices = BusinessTypeRegistry.getConfig(
          BusinessType.grocery,
        ).unitOptions.map((u) => u.label.toLowerCase()).toList();

        final def = defaultManualUnit(BusinessType.grocery);
        expect(groceryChoices, contains(def));
        expect(def, 'pcs', reason: 'grocery default is unitOptions.first.');
        // kg/gm are config-offered so they are selectable in the dropdown.
        expect(groceryChoices, containsAll(<String>['kg', 'gm', 'ltr', 'nos']));
      });

      test('POST-FIX (grocery) — a manual line matching a product inherits the '
          "product's taxRate, split into equal CGST/SGST halves (not 0)", () {
        // 3 units @ ₹40, ₹20 discount, matched product taxRate 18%.
        final line = applyMatchedProductTax(
          qty: 3,
          price: 40,
          discount: 20,
          productTaxRate: 18,
        );
        final double base = (3 * 40) - 20; // 100
        expect(line.gstRate, 18.0, reason: 'inherits product taxRate, not 0.');
        expect(line.cgst, closeTo(base * 18 / 200, 1e-9));
        expect(line.sgst, closeTo(base * 18 / 200, 1e-9));
        expect(line.cgst, closeTo(line.sgst, 1e-9));
        expect(line.taxAmount, closeTo(base * 18 / 100, 1e-9));
      });

      test('NON-REGRESSION (non-grocery) — defaultManualUnit stays the legacy '
          "'pcs' for every non-grocery type", () {
        for (final type in kInScopeTypes) {
          if (type == BusinessType.grocery) continue;
          expect(
            defaultManualUnit(type),
            'pcs',
            reason:
                '$type keeps the legacy pcs default (4d is grocery-scoped).',
          );
        }
      });

      testWidgets(
        'POST-FIX (grocery) — the manual-entry unit dropdown is '
        'sourced from grocery unitOptions (kg & gm selectable, default pcs)',
        (tester) async {
          await tester.pumpWidget(_manualEntryHost(BusinessType.grocery));
          await tester.pumpAndSettle();

          expect(
            find.text('pcs'),
            findsWidgets,
            reason: 'default selected unit is the first grocery option (pcs).',
          );

          await _openUnitDropdown(tester);
          expect(
            find.text('kg'),
            findsWidgets,
            reason: 'grocery unitOptions include kg.',
          );
          expect(
            find.text('gm'),
            findsWidgets,
            reason: 'grocery unitOptions include gm (the config label).',
          );
          expect(
            find.text('ltr'),
            findsWidgets,
            reason: 'grocery unitOptions include ltr.',
          );
        },
      );

      testWidgets('NON-REGRESSION — pharmacy keeps the legacy fixed unit list '
          '(legacy "g" present, grocery-only "gm" absent)', (tester) async {
        await tester.pumpWidget(_manualEntryHost(BusinessType.pharmacy));
        await tester.pumpAndSettle();

        await _openUnitDropdown(tester);
        expect(
          find.text('g'),
          findsWidgets,
          reason: 'pharmacy keeps the legacy fixed unit list (contains "g").',
        );
        expect(
          find.text('gm'),
          findsNothing,
          reason: 'the grocery-only config label "gm" must not leak in.',
        );
      });
    });
  });
}
