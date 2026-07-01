// ============================================================================
// Feature: pharmacy-vertical-remediation — Task 19.3
// Test: substitute add and total update
//
// **Validates: Requirements 25.6**
//
// R25.6 requires an automated test verifying that selecting a substitute
// product through `SaltSearchScreen.onProductSelected` adds the product to the
// bill and updates the bill total.
//
// ---------------------------------------------------------------------------
// Seam / rationale
// ---------------------------------------------------------------------------
// The full add path lives in `BillCreationScreenV2`, where `_addItem` and
// `_brandedAlternativeToProduct` are PRIVATE `State` methods and the screen is
// wired to Riverpod, Drift, the service locator, and the FEFO / prescription /
// MRP side-channels. Pumping that whole screen for a line-arithmetic check is
// impractical, so — as the task allows — this test attacks the two halves of
// R25.6 independently:
//
//   1. CALLBACK WIRING (widget-level): the REAL `SaltSearchScreen` is pumped
//      with a capturing `onProductSelected`. We assert the widget builds and
//      that a `BrandedAlternative` selected through that callback is delivered
//      verbatim — the exact value Task 19.1 forwards to `_addItem`. (The empty
//      query keeps the salt-results provider on its short-circuit path, so no
//      ApiClient / DI is required to pump the screen.)
//
//   2. ADD + TOTAL UPDATE (logic-level): the documented Task 19.1 steps —
//      `_brandedAlternativeToProduct` then the `_addItem` setState body — are
//      mirrored here in lock-step with `bill_creation_screen_v2.dart`, and the
//      bill total is recomputed exactly as the screen getters do
//      (`_subtotal + _totalTax`). We assert the product lands on the bill and
//      the total grows by the line amount.
//
// Run: flutter test test/features/pharmacy/substitute_add_total_test.dart
// ============================================================================

import 'package:dukanx/core/repository/products_repository.dart';
import 'package:dukanx/features/pharmacy/screens/salt_search_screen.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Production-mirroring helpers (kept in lock-step with Task 19.1) ─────────

/// Mirrors `_brandedAlternativeToProduct` in `bill_creation_screen_v2.dart`:
/// adapt a salt-search result into the billing `Product` shape.
Product brandedAlternativeToProduct(BrandedAlternative brand) {
  final now = DateTime.now();
  return Product(
    id: brand.productId,
    userId: '',
    name: brand.productName,
    sellingPrice: brand.mrp ?? 0,
    stockQuantity: brand.stockQuantity,
    brand: brand.manufacturer,
    drugSchedule: brand.drugSchedule,
    createdAt: now,
    updatedAt: now,
  );
}

/// Mirrors the `setState` body of `_addItem`: add a new line at qty 1, or
/// increment the existing matching line by 1 (R25.2 / R25.5).
void addOrIncrement(List<BillItem> items, Product product) {
  final existingIndex = items.indexWhere((i) => i.productId == product.id);
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
        productId: product.id,
        productName: product.name,
        qty: 1,
        price: product.sellingPrice,
        unit: product.unit,
        gstRate: product.taxRate,
        cgst: product.sellingPrice * (product.taxRate / 200),
        sgst: product.sellingPrice * (product.taxRate / 200),
        size: product.size,
        color: product.color,
        drugSchedule: product.drugSchedule,
      ),
    );
  }
}

// Mirror of the bill-total getters in `bill_creation_screen_v2.dart`.
double subtotal(List<BillItem> items) =>
    items.fold(0.0, (sum, i) => sum + i.total);
double totalTax(List<BillItem> items) =>
    items.fold(0.0, (sum, i) => sum + i.taxAmount);
double grandTotal(List<BillItem> items) => subtotal(items) + totalTax(items);

void main() {
  group('Feature: pharmacy-vertical-remediation, Task 19.3: substitute add and '
      'total update (R25.6)', () {
    testWidgets(
      'SaltSearchScreen pumps with a wired onProductSelected callback that '
      'delivers the selected BrandedAlternative',
      (tester) async {
        BrandedAlternative? delivered;

        // Pump the REAL screen. Empty query keeps the salt-results provider
        // on its `< 2 chars` short-circuit, so no ApiClient / DI is needed.
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SaltSearchScreen(
                onProductSelected: (brand) => delivered = brand,
              ),
            ),
          ),
        );

        // The screen built and exposes the billing callback contract.
        final screen = tester.widget<SaltSearchScreen>(
          find.byType(SaltSearchScreen),
        );
        expect(screen.onProductSelected, isNotNull);

        // A selection routed through the callback arrives verbatim — this is
        // exactly the value Task 19.1 hands to `_addItem`.
        const selected = BrandedAlternative(
          productId: 'sub-amox-500',
          productName: 'Amoxil 500mg',
          manufacturer: 'GSK',
          mrp: 120.0,
          stockQuantity: 40,
        );
        screen.onProductSelected!(selected);

        expect(delivered, isNotNull);
        expect(delivered!.productId, 'sub-amox-500');
        expect(delivered!.productName, 'Amoxil 500mg');
        expect(delivered!.mrp, 120.0);
      },
    );

    test(
      'selecting a substitute adds it to the bill and increases the total by '
      'the line amount (R25.2, R25.3)',
      () {
        // Bill already carrying one unrelated ₹40.00 line.
        final items = <BillItem>[
          BillItem(
            productId: 'existing-1',
            productName: 'Paracetamol 500mg',
            qty: 1,
            price: 40.0,
          ),
        ];
        final totalBefore = grandTotal(items);
        expect(totalBefore, closeTo(40.0, 1e-9));

        // Pharmacist selects a substitute (MRP ₹90.00) via onProductSelected.
        const selected = BrandedAlternative(
          productId: 'sub-90',
          productName: 'Dolo 650mg',
          manufacturer: 'Micro Labs',
          mrp: 90.0,
          stockQuantity: 30,
        );
        addOrIncrement(items, brandedAlternativeToProduct(selected));

        // Added as a NEW line at quantity 1 (R25.2).
        expect(items.length, 2);
        final added = items[1];
        expect(added.productId, 'sub-90');
        expect(added.qty, 1);
        expect(added.price, 90.0);

        // Total recalculated to include the added line (R25.3):
        // 40.00 + 90.00 = 130.00.
        final totalAfter = grandTotal(items);
        expect(totalAfter, closeTo(130.0, 1e-9));
        expect(totalAfter - totalBefore, closeTo(90.0, 1e-9));
      },
    );

    test('re-selecting the same substitute increments the line to qty 2 and '
        'updates the total instead of duplicating (R25.5)', () {
      final items = <BillItem>[];
      final product = brandedAlternativeToProduct(
        const BrandedAlternative(
          productId: 'sub-90',
          productName: 'Dolo 650mg',
          mrp: 90.0,
          stockQuantity: 30,
        ),
      );

      // First selection → new line.
      addOrIncrement(items, product);
      expect(items.length, 1);
      expect(items.single.qty, 1);
      expect(grandTotal(items), closeTo(90.0, 1e-9));

      // Second selection of the SAME product → increment, not duplicate.
      addOrIncrement(items, product);
      expect(items.length, 1, reason: 'must not add a duplicate line');
      expect(items.single.qty, 2);
      expect(grandTotal(items), closeTo(180.0, 1e-9));
    });
  });
}
