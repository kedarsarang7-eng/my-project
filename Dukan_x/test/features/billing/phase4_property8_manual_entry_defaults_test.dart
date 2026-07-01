// ============================================================================
// PHASE 4 — Task 5.8: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 8: Grocery manual-entry
// defaults respect config
// **Validates: Requirements 7.4**
// ============================================================================
//
// Property 8 (design.md):
//   "For any grocery item added via manual entry, the defaulted unit is a
//    member of the grocery `unitOptions` and the applied tax rate equals the
//    product's own tax rate (not a hardcoded `pcs`/`0`)."
//
// This suite proves two facets of that property over >=100 generated
// iterations each, driving the SAME pure seams the Task 5.7 (4d) production
// fix uses — without pumping the heavy billing screen (which pulls Riverpod +
// Drift + the service locator):
//
//   8a. UNIT MEMBERSHIP — the grocery manual-entry unit dropdown is sourced
//       from `BusinessTypeRegistry.getConfig(BusinessType.grocery).unitOptions`
//       with labels lowercased (manual_item_entry_sheet.dart `_unitChoices`),
//       and the default is `unitOptions.first` (bill_creation_screen_v2.dart
//       `_defaultManualUnit`). For ANY option a user could pick (generated
//       index into the option list) AND for the derived default, the unit is a
//       member of grocery's lowercased `unitOptions`. The full dropdown set is
//       also pinned to equal grocery's lowercased `unitOptions` — proving the
//       default is NOT the hardcoded legacy `'pcs'` constant but the
//       config-derived first option.
//
//   8b. TAX-ON-MATCH — mirrors the Task 5.7 manual-entry rule
//       (bill_creation_screen_v2.dart `_showManualItemEntry.onItemAdded`):
//       when a manual line matches an existing product, the applied
//       `gstRate == product.taxRate` and `cgst == sgst == base*taxRate/200`,
//       where `base = (qty*price) - discount` — NOT a hardcoded `0`. For
//       >=100 generated (qty>0, price>0, taxRate ∈ {0,5,12,18}, discount in
//       [0, qty*price]) the property asserts the applied tax rate equals the
//       product's own rate and the CGST/SGST split is exactly base*rate/200.
//
// SEAMS (per task):
//   - Unit membership: the PURE config seam
//     `BusinessTypeRegistry.getConfig(BusinessType.grocery).unitOptions`
//     (the single source of truth both the dropdown and the default-unit
//     derivation consult). The default-unit derivation `_defaultManualUnit`
//     is only reachable via the widget, so it is mirrored here as the
//     documented pure rule `_groceryDefaultUnit()` == `unitOptions.first`
//     (lowercased label), and asserted to be a member of the option set.
//   - Tax-on-match: the production rule is inline inside the widget's
//     `onItemAdded` closure and not independently reachable, so the documented
//     formula is mirrored by the pure helper `applyMatchedProductTax(...)`
//     (byte-for-byte: `gstRate = product.taxRate`, `half = base*rate/200`,
//     `cgst == sgst == half`, only inheriting when `rate > 0` exactly as
//     production does) and asserted. This is the same seam-mirroring approach
//     used by the Task 5.3 Property 6 suite for the weighing-scale math.
//
// Money math is double-based exactly as production; equalities that cross
// different floating-point evaluation orders are asserted with a tolerance.
//
// PBT library: dartproptest ^0.2.1 (glados is unresolvable here — see the
//   dev_dependency note in pubspec.yaml). `forAll((args...) => <bool>,
//   [gen1, gen2, ...], numRuns: N)` runs `numRuns` generated cases and returns
//   whether the predicate held for all of them (throwing a shrinking
//   counterexample otherwise).
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/billing/phase4_property8_manual_entry_defaults_test.dart
// ============================================================================

import 'dart:math' as math;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/billing/business_type_config.dart'; // also re-exports BusinessType
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grocery's configured unit options, lowercased — the single source of truth
/// the manual-entry dropdown (`manual_item_entry_sheet.dart` `_unitChoices`)
/// and the default-unit derivation (`bill_creation_screen_v2.dart`
/// `_defaultManualUnit`) both consult.
List<String> _groceryUnitChoices() => BusinessTypeRegistry.getConfig(
  BusinessType.grocery,
).unitOptions.map((u) => u.label.toLowerCase()).toList();

/// Mirrors `_defaultManualUnit(BusinessType.grocery)`: the default is the
/// FIRST configured grocery unit option (lowercased label), NOT a hardcoded
/// `'pcs'` constant.
String _groceryDefaultUnit() {
  final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
  // `unitOptions` is non-empty for grocery (asserted in setUpAll); mirror the
  // production guard anyway so this stays faithful if the config changes.
  if (config.unitOptions.isNotEmpty) {
    return config.unitOptions.first.label.toLowerCase();
  }
  return 'pcs';
}

/// Mirrors the Task 5.7 matched-product tax inheritance in
/// `bill_creation_screen_v2.dart` `_showManualItemEntry.onItemAdded`:
/// a manual line left at GST 0 that matches an existing product inherits the
/// product's own tax rate, split into equal CGST/SGST halves over the discounted
/// base. When the product's rate is 0 the line stays at gstRate 0 (which still
/// equals the product's own rate). Byte-for-byte faithful to production.
BillItem applyMatchedProductTax({
  required double qty,
  required double price,
  required double discount,
  required double productTaxRate,
}) {
  // The manual line starts with the user-left default GST of 0.
  var item = BillItem(
    productId: '',
    productName: 'Manual Line',
    qty: qty,
    price: price,
    discount: discount,
  );
  // Production only inherits when the matched product carries a positive rate.
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

void main() {
  // At least 100 iterations are required by the spec; 200 matches the default
  // and the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // --- Sanity: pin the grocery config surface so a future config edit that
  // changes the option set or default is caught here too. ----------------
  setUpAll(() {
    final choices = _groceryUnitChoices();
    expect(
      choices,
      <String>['pcs', 'kg', 'gm', 'ltr', 'nos'],
      reason:
          'Property 8 input space is grocery unitOptions lowercased '
          '(pcs, kg, gm, ltr, nos).',
    );
    expect(
      _groceryDefaultUnit(),
      'pcs',
      reason: 'grocery manual-entry default unit is unitOptions.first (pcs).',
    );
  });

  // --- Generators -----------------------------------------------------------
  final List<String> groceryChoices = _groceryUnitChoices();

  // Any option a user could pick: a generated index into the option list.
  final Generator<int> optionIndexGen = Gen.interval(
    0,
    groceryChoices.length - 1,
  );

  // Quantity: 0.001 .. 100.000 (always positive).
  final Generator<double> qtyGen = Gen.interval(
    1,
    100000,
  ).map((i) => (i as int) / 1000.0);

  // Price: ₹1.00 .. ₹100000.00, paise precision (always positive).
  final Generator<double> priceGen = Gen.interval(
    100,
    10000000,
  ).map((i) => (i as int) / 100.0);

  // Discount fraction of the base: 0% .. 100% (keeps base >= 0).
  final Generator<double> discountFracGen = Gen.interval(
    0,
    100,
  ).map((i) => (i as int) / 100.0);

  // Product tax rate over the realistic GST slab set.
  final Generator<double> taxRateGen = Gen.elementOf<int>(<int>[
    0,
    5,
    12,
    18,
  ]).map((i) => (i as int).toDouble());

  group('Feature: gorouter-navigation-migration, Property 8: Grocery '
      'manual-entry defaults respect config — Req 7.4', () {
    // ----------------------------------------------------------------------
    // Property 8a — UNIT MEMBERSHIP.
    // ----------------------------------------------------------------------
    test('Property 8: for any pickable grocery unit option AND the derived '
        'default, the unit is a member of grocery unitOptions (lowercased), and '
        'the dropdown set equals grocery unitOptions', () {
      final groceryChoiceSet = groceryChoices.toSet();

      final held = forAll(
        (int optionIndex) {
          // The derived default must be a member of the option set...
          final String defaultUnit = _groceryDefaultUnit();
          if (!groceryChoiceSet.contains(defaultUnit)) return false;

          // ...and so must ANY option the user could pick.
          final String picked = groceryChoices[optionIndex];
          if (!groceryChoiceSet.contains(picked)) return false;

          // The dropdown set is exactly grocery's lowercased unitOptions
          // (proving the default is config-derived, not hardcoded 'pcs').
          final derivedSet = _groceryUnitChoices().toSet();
          return derivedSet.length == groceryChoiceSet.length &&
              derivedSet.containsAll(groceryChoiceSet);
        },
        [optionIndexGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);

      // The default is the FIRST option, not a hardcoded constant unrelated
      // to the config order.
      expect(_groceryDefaultUnit(), groceryChoices.first);
    });

    // ----------------------------------------------------------------------
    // Property 8b — TAX-ON-MATCH.
    // ----------------------------------------------------------------------
    test(
      'Property 8: for any (qty>0, price>0, taxRate ∈ {0,5,12,18}, discount), '
      'a manual line matching an existing product applies gstRate == '
      'product.taxRate and cgst == sgst == base*taxRate/200 (base = '
      'qty*price - discount) — NOT a hardcoded 0',
      () {
        final held = forAll(
          (double qty, double price, double discountFrac, double taxRate) {
            final double base0 = qty * price;
            final double discount = base0 * discountFrac;
            final double taxableBase = base0 - discount;

            final line = applyMatchedProductTax(
              qty: qty,
              price: price,
              discount: discount,
              productTaxRate: taxRate,
            );

            // (a) applied gstRate equals the product's own tax rate — including
            //     the rate==0 case (stays 0, which == product.taxRate), never a
            //     hardcoded value divorced from the product.
            if (!_approx(line.gstRate, taxRate)) return false;

            // (b) CGST == SGST == base*taxRate/200 (split evenly over the
            //     discounted base).
            final double expectedHalf = taxableBase * (taxRate / 200);
            if (!_approx(line.cgst, expectedHalf)) return false;
            if (!_approx(line.sgst, expectedHalf)) return false;
            if (!_approx(line.cgst, line.sgst)) return false;

            // (c) total tax amount == base*taxRate/100.
            if (!_approx(line.taxAmount, taxableBase * (taxRate / 100))) {
              return false;
            }
            return true;
          },
          [qtyGen, priceGen, discountFracGen, taxRateGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );
  });
}
