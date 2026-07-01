// ============================================================================
// TASK 19.2 — PROPERTY TEST
// Feature: pharmacy-vertical-remediation, Property 29: Substitute selection
//   adds to bill and recalculates total
// **Validates: Requirements 25.2, 25.3, 25.5**
// ============================================================================
//
// Property 29 (design.md — Correctness Properties / Req 25):
//   "selecting a substitute adds the product (qty 1) or increments an existing
//    matching line, and the bill total recalculates accordingly."
//
// Acceptance criteria exercised:
//   R25.2 — a selected substitute is added as a NEW line item with quantity 1.
//   R25.5 — if the product is ALREADY a line item, its quantity is incremented
//           by 1 instead of adding a duplicate line.
//   R25.3 — the bill total is RECALCULATED to include the added/incremented
//           line.
//
// ---------------------------------------------------------------------------
// What is under test
// ---------------------------------------------------------------------------
// Task 19.1 wired `SaltSearchScreen.onProductSelected` into
// `BillCreationScreenV2` so that each selection routes through `_addItem`,
// which either appends a new `BillItem` (qty 1) or rebuilds the matching line
// with `qty + 1`; the bill total getters (`_subtotal` / `_totalTax` /
// `_grandTotal`) then recompute by folding over `_items`.
//
// `_addItem` is private widget state, so — per the task — the add/increment +
// total-recalc surface is modelled here as a PURE list operation that mirrors
// the production line math exactly (same `BillItem` constructor arguments and
// the same total-getter folds), and that pure surface is property-tested.
//
// Production new-line path (mirrored in `_applySelection`):
//   BillItem(qty: 1, price: sellingPrice, gstRate: taxRate,
//            cgst: sellingPrice * (taxRate / 200),
//            sgst: sellingPrice * (taxRate / 200))
// Production increment path (mirrored in `_applySelection`):
//   newQty          = existing.qty + 1
//   perUnitDiscount = existing.qty > 0 ? existing.discount / existing.qty : 0
//   taxableBase     = (existing.price - perUnitDiscount).clamp(0, inf)
//   BillItem(qty: newQty, price: existing.price, gstRate: existing.gstRate,
//            discount: perUnitDiscount * newQty,
//            cgst: newQty * (taxableBase * (gstRate / 200)),
//            sgst: newQty * (taxableBase * (gstRate / 200)))
// Substitute-added lines never carry a discount, so `perUnitDiscount` stays 0
// across every increment and `taxableBase` stays `price` — exactly the
// production behaviour for the salt-search path.
//
// Total getters (mirrored in `_subtotalOf` / `_totalTaxOf` / `_grandTotalOf`):
//   _subtotal  = Σ item.total
//   _totalTax  = Σ item.taxAmount
//   _grandTotal = _subtotal + _totalTax
//
// ---------------------------------------------------------------------------
// Independent oracle
// ---------------------------------------------------------------------------
// The property is proven against an oracle that restates the acceptance
// criteria over the SEQUENCE OF SELECTIONS (a multiset of product ids) without
// inspecting the produced list:
//   * Each distinct product id becomes exactly one line (no duplicates).
//   * Lines appear in first-selection order (new products are appended).
//   * A line's quantity equals how many times its id was selected.
//   * A line keeps the price/tax-rate from the FIRST time its id was selected
//     (re-selecting an existing product reuses the existing line, ignoring any
//     differing price/rate on the later selection — the production behaviour).
//   * The recomputed bill total equals the sum of the per-line totals derived
//     from those quantities.
//
// PBT library: dartproptest ^0.2.1 (repo-wide standard). `forAll` returns true
// when the property held for every run and throws a shrinking counterexample
// otherwise.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/pharmacy/substitute_selection_property29_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// At least 100 generated cases are required by the spec (R5.4); 200 matches
/// the dartproptest default and the convention used across this repo's suites.
const int kNumRuns = 200;

/// GST rates the resolver supports (design Req 11.1). Substitute products carry
/// one of these as their tax rate.
const List<double> kRates = <double>[0.0, 5.0, 12.0, 18.0, 28.0];

/// Floating-point comparison tolerance for recomputed totals. The oracle and
/// the production folds use the same arithmetic ordering, so values are
/// effectively bit-identical; this guards only against incidental rounding.
const double kEpsilon = 1e-3;

// ---------------------------------------------------------------------------
// Selection model + generators
// ---------------------------------------------------------------------------

/// One substitute selection coming back through `onProductSelected`: a product
/// id (drawn from a small pool so repeats are common), a selling price in
/// rupees, and a GST rate.
class _Selection {
  const _Selection(this.id, this.sellingPrice, this.taxRate);
  final String id;
  final double sellingPrice;
  final double taxRate;
}

/// A single selection. The id is drawn from a 5-value pool (`p0`..`p4`) so that
/// across a sequence the same product is frequently re-selected, exercising the
/// increment path (R25.5) alongside the new-line path (R25.2).
final Generator<_Selection> _selectionGen =
    Gen.tuple(<Generator<dynamic>>[
      Gen.interval(0, 4), // 0: product id index (small pool ⇒ repeats)
      Gen.interval(1, 1000000), // 1: selling price in paise (₹0.01 .. ₹10,000)
      Gen.interval(0, kRates.length - 1), // 2: GST-rate index
    ]).map((parts) {
      final int idIndex = parts[0] as int;
      final int pricePaise = parts[1] as int;
      final int rateIndex = parts[2] as int;
      return _Selection('p$idIndex', pricePaise / 100.0, kRates[rateIndex]);
    });

/// A sequence of 1..12 substitute selections, mixing fresh products and
/// re-selections of already-added products.
final Generator<List<_Selection>> _sequenceGen = Gen.array<_Selection>(
  _selectionGen,
  minLength: 1,
  maxLength: 12,
).map((list) => list.cast<_Selection>().toList());

// ---------------------------------------------------------------------------
// Production-mirroring pure surface
// ---------------------------------------------------------------------------

/// Mirrors `BillCreationScreenV2._addItem`: append a new line (qty 1) or, when
/// the product id already exists, rebuild that line with `qty + 1`.
void _applySelection(List<BillItem> items, _Selection s) {
  final existingIndex = items.indexWhere((i) => i.productId == s.id);
  if (existingIndex != -1) {
    final existing = items[existingIndex];
    final newQty = existing.qty + 1;
    final perUnitDiscount = existing.qty > 0
        ? existing.discount / existing.qty
        : 0.0;
    final taxableBase = (existing.price - perUnitDiscount).clamp(
      0.0,
      double.infinity,
    );
    items[existingIndex] = BillItem(
      productId: existing.productId,
      productName: existing.productName,
      qty: newQty,
      price: existing.price,
      unit: existing.unit,
      gstRate: existing.gstRate,
      discount: perUnitDiscount * newQty,
      cgst: newQty * (taxableBase * (existing.gstRate / 200)),
      sgst: newQty * (taxableBase * (existing.gstRate / 200)),
    );
  } else {
    items.add(
      BillItem(
        productId: s.id,
        productName: 'Substitute ${s.id}',
        qty: 1,
        price: s.sellingPrice,
        gstRate: s.taxRate,
        cgst: s.sellingPrice * (s.taxRate / 200),
        sgst: s.sellingPrice * (s.taxRate / 200),
      ),
    );
  }
}

/// Mirrors the bill total getters on `BillCreationScreenV2`.
double _subtotalOf(List<BillItem> items) =>
    items.fold(0.0, (sum, item) => sum + item.total);
double _totalTaxOf(List<BillItem> items) =>
    items.fold(0.0, (sum, item) => sum + item.taxAmount);
double _grandTotalOf(List<BillItem> items) =>
    _subtotalOf(items) + _totalTaxOf(items);

// ---------------------------------------------------------------------------
// Oracle helpers (independent of the produced list)
// ---------------------------------------------------------------------------

/// First-appearance order of ids in the selection sequence.
List<String> _firstAppearanceOrder(List<_Selection> seq) {
  final order = <String>[];
  for (final s in seq) {
    if (!order.contains(s.id)) order.add(s.id);
  }
  return order;
}

/// For each id, the selection that FIRST introduced it (its price/rate win).
Map<String, _Selection> _firstSelectionById(List<_Selection> seq) {
  final first = <String, _Selection>{};
  for (final s in seq) {
    first.putIfAbsent(s.id, () => s);
  }
  return first;
}

/// Selection count per id (the expected line quantity).
Map<String, int> _countsById(List<_Selection> seq) {
  final counts = <String, int>{};
  for (final s in seq) {
    counts[s.id] = (counts[s.id] ?? 0) + 1;
  }
  return counts;
}

void main() {
  group('Feature: pharmacy-vertical-remediation, Property 29: Substitute '
      'selection adds to bill and recalculates total — Req 25.2, 25.3, 25.5', () {
    // ----------------------------------------------------------------------
    // (A) STRUCTURE: each selection adds a new qty-1 line (R25.2) or
    //     increments the matching line (R25.5); the line count equals the
    //     number of distinct products and lines keep first-selection order.
    // ----------------------------------------------------------------------
    test('Property 29a: selections produce one line per distinct product with '
        'quantity = selection count (add qty 1 / increment)', () {
      final bool held = forAll(
        (List<_Selection> seq) {
          final items = <BillItem>[];
          for (final s in seq) {
            _applySelection(items, s);
          }

          final order = _firstAppearanceOrder(seq);
          final counts = _countsById(seq);
          final firsts = _firstSelectionById(seq);

          // One line per distinct product — never a duplicate line (R25.5).
          if (items.length != order.length) return false;

          // Lines appear in first-selection order (new products appended).
          for (var i = 0; i < order.length; i++) {
            if (items[i].productId != order[i]) return false;
          }

          for (final item in items) {
            // Quantity equals how many times the product was selected:
            // exactly 1 for a single selection (R25.2), +1 per re-selection
            // (R25.5).
            if (item.qty != counts[item.productId]!.toDouble()) return false;

            // The line keeps the price/rate from the first selection of its
            // id (re-selection reuses the existing line).
            final first = firsts[item.productId]!;
            if (item.price != first.sellingPrice) return false;
            if (item.gstRate != first.taxRate) return false;
          }
          return true;
        },
        [_sequenceGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'Each substitute selection adds a new line with quantity 1 or '
            'increments the matching line; the bill holds exactly one line per '
            'distinct product with quantity equal to its selection count.',
      );
    });

    // ----------------------------------------------------------------------
    // (B) TOTAL RECALCULATION: the recomputed bill total equals the sum over
    //     lines derived from the selection multiset (R25.3).
    // ----------------------------------------------------------------------
    test('Property 29b: the bill total recalculates to the sum of all line '
        'totals after every selection', () {
      final bool held = forAll(
        (List<_Selection> seq) {
          final items = <BillItem>[];
          for (final s in seq) {
            _applySelection(items, s);
          }

          // Oracle: rebuild each expected line from the selection multiset
          // (quantity = count, price/rate = first selection) using the same
          // arithmetic the production line uses, then sum.
          final counts = _countsById(seq);
          final firsts = _firstSelectionById(seq);
          double expectedSubtotal = 0.0;
          double expectedTax = 0.0;
          for (final entry in counts.entries) {
            final first = firsts[entry.key]!;
            final qty = entry.value.toDouble();
            final price = first.sellingPrice;
            final rate = first.taxRate;
            final cgst = qty * (price * (rate / 200));
            final sgst = qty * (price * (rate / 200));
            final lineTax = cgst + sgst; // igst = 0
            final lineTotal = (qty * price) + lineTax; // discount = 0
            expectedSubtotal += lineTotal;
            expectedTax += lineTax;
          }
          final expectedGrand = expectedSubtotal + expectedTax;

          // Recomputed totals from the produced items (mirrors the getters).
          final subtotal = _subtotalOf(items);
          final totalTax = _totalTaxOf(items);
          final grandTotal = _grandTotalOf(items);

          if ((subtotal - expectedSubtotal).abs() > kEpsilon) return false;
          if ((totalTax - expectedTax).abs() > kEpsilon) return false;
          if ((grandTotal - expectedGrand).abs() > kEpsilon) return false;

          // The grand total is internally consistent with its parts.
          if ((grandTotal - (subtotal + totalTax)).abs() > kEpsilon) {
            return false;
          }
          return true;
        },
        [_sequenceGen],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'After each substitute selection the bill total recalculates to '
            'include the added/incremented line, equalling the sum of all '
            'line totals.',
      );
    });

    // ----------------------------------------------------------------------
    // (C) MONOTONIC RECALC: adding a positively-priced substitute strictly
    //     increases the recomputed grand total (R25.3 — the added line is
    //     included), whether it is a new line or an increment.
    // ----------------------------------------------------------------------
    test(
      'Property 29c: each positively-priced selection strictly increases the '
      'recomputed grand total',
      () {
        final bool held = forAll(
          (List<_Selection> seq) {
            final items = <BillItem>[];
            var previous = 0.0;
            for (final s in seq) {
              _applySelection(items, s);
              final current = _grandTotalOf(items);
              // Selling price is always ≥ ₹0.01 and rates are ≥ 0, so every
              // selection contributes a strictly positive amount.
              if (!(current > previous)) return false;
              previous = current;
            }
            return true;
          },
          [_sequenceGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Every substitute selection (new line or increment) adds a '
              'positive line amount, so the recalculated total strictly grows.',
        );
      },
    );

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin the add / increment / recalc behaviour.
    // ----------------------------------------------------------------------
    test('Property 29 anchor: a fresh selection adds a qty-1 line and the '
        'total includes it (R25.2, R25.3)', () {
      final items = <BillItem>[];
      _applySelection(items, const _Selection('a', 100.0, 12.0));

      expect(items.length, 1);
      expect(items.single.qty, 1.0);
      expect(items.single.price, 100.0);
      // 100 + 12% GST = 112 line total; grand = subtotal(112) + tax(12) = 124.
      expect(_subtotalOf(items), closeTo(112.0, kEpsilon));
      expect(_totalTaxOf(items), closeTo(12.0, kEpsilon));
      expect(_grandTotalOf(items), closeTo(124.0, kEpsilon));
    });

    test('Property 29 anchor: re-selecting the same product increments qty '
        'instead of adding a duplicate line (R25.5)', () {
      final items = <BillItem>[];
      _applySelection(items, const _Selection('a', 100.0, 12.0));
      _applySelection(items, const _Selection('a', 100.0, 12.0));

      expect(items.length, 1, reason: 'no duplicate line');
      expect(items.single.qty, 2.0, reason: 'quantity incremented to 2');
      // 2 × 100 = 200 + 12% (24) = 224 subtotal; grand = 224 + 24 = 248.
      expect(_subtotalOf(items), closeTo(224.0, kEpsilon));
      expect(_totalTaxOf(items), closeTo(24.0, kEpsilon));
      expect(_grandTotalOf(items), closeTo(248.0, kEpsilon));
    });

    test('Property 29 anchor: distinct products produce distinct lines whose '
        'totals sum into the bill total (R25.2, R25.3)', () {
      final items = <BillItem>[];
      _applySelection(items, const _Selection('a', 100.0, 12.0));
      _applySelection(items, const _Selection('b', 50.0, 5.0));

      expect(items.length, 2);
      expect(items.map((e) => e.productId).toList(), <String>['a', 'b']);
      // a: 100 + 12 = 112 ; b: 50 + 2.5 = 52.5 ; subtotal = 164.5
      // tax = 12 + 2.5 = 14.5 ; grand = 164.5 + 14.5 = 179.
      expect(_subtotalOf(items), closeTo(164.5, kEpsilon));
      expect(_totalTaxOf(items), closeTo(14.5, kEpsilon));
      expect(_grandTotalOf(items), closeTo(179.0, kEpsilon));
    });

    test('Property 29 anchor: re-selecting an existing product reuses its line '
        'price, ignoring a differing later price (R25.5)', () {
      final items = <BillItem>[];
      _applySelection(items, const _Selection('a', 100.0, 12.0));
      // Later selection of the same id carries a different price/rate; the
      // existing line is reused (qty incremented) with its original values.
      _applySelection(items, const _Selection('a', 999.0, 28.0));

      expect(items.length, 1);
      expect(items.single.qty, 2.0);
      expect(items.single.price, 100.0, reason: 'original price reused');
      expect(items.single.gstRate, 12.0, reason: 'original rate reused');
    });
  });
}
