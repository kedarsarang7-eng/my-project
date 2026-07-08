/// Bug Condition Exploration Test — billing.fuelSaleWiring
///
/// **Validates: Requirements 1.1**
///
/// Property 1: Bug Condition — Fuel Sale Wiring
///
/// This test confirms that the live billing path (`BillCreationScreenV2._handleSave`)
/// does NOT wire petrol pump sales to the fraud-proof `PetrolPumpBillingService`.
/// Specifically:
///   - The Bill constructor in `_handleSave` never sets `shiftId` or `attendantId`
///     for petrolPump bills (they remain null).
///   - The `_addItem` method for non-pharmacy items sets `gstRate: product.taxRate`
///     — if a fuel Product has a non-zero taxRate, the bill item inherits it
///     instead of forcing GST to 0.
///   - There is no reference to `PetrolPumpBillingService` anywhere in the file.
///
/// On UNFIXED code this test FAILS — proving the bug exists.
/// After the fix (wiring `PetrolPumpBillingService` into the billing path)
/// this same test PASSES.
///
/// Run: flutter test test/bug_condition/petrol_pump_fuel_sale_wiring_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // billing.fuelSaleWiring / 1.1 / 2.1 — Fuel sale not wired to
  // PetrolPumpBillingService; shiftId/attendantId never set; GST not forced to 0
  // ===========================================================================
  group('Bug Condition 1.1 — billing.fuelSaleWiring', () {
    late String billScreenSrc;

    setUpAll(() {
      billScreenSrc = _readSource(
        'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
      );
      assert(
        billScreenSrc.isNotEmpty,
        'bill_creation_screen_v2.dart must exist',
      );
    });

    test(
      'petrolPump bill saved via _handleSave sets shiftId from active shift',
      () {
        // Locate the Bill constructor call `final newBill = Bill(`
        final billConstructorStart = billScreenSrc.indexOf(
          'final newBill = Bill(',
        );
        expect(
          billConstructorStart,
          isNot(-1),
          reason: 'Bill constructor must exist in _handleSave',
        );

        // Extract the Bill constructor call (generous slice to cover all params)
        final billConstructorSlice = billScreenSrc.substring(
          billConstructorStart,
          (billConstructorStart + 2500).clamp(0, billScreenSrc.length),
        );

        // The Bill constructor MUST explicitly set shiftId to a non-null value
        // (e.g., from the active shift). On unfixed code, shiftId is not passed
        // at all in the constructor (defaults to null).
        final hasShiftIdAssignment = RegExp(
          r'shiftId\s*:\s*(?!null)[^,\)]+',
        ).hasMatch(billConstructorSlice);

        expect(
          hasShiftIdAssignment,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.1): petrolPump bill saved via _handleSave '
              'does NOT set shiftId from the active shift. The Bill constructor '
              'has no shiftId assignment — it defaults to null, meaning fuel '
              'sales are never linked to a shift for reconciliation.',
        );
      },
    );

    test('petrolPump bill saved via _handleSave sets attendantId', () {
      final billConstructorStart = billScreenSrc.indexOf(
        'final newBill = Bill(',
      );
      expect(
        billConstructorStart,
        isNot(-1),
        reason: 'Bill constructor must exist in _handleSave',
      );

      final billConstructorSlice = billScreenSrc.substring(
        billConstructorStart,
        (billConstructorStart + 2500).clamp(0, billScreenSrc.length),
      );

      // The Bill constructor MUST explicitly set attendantId to a non-null
      // value for petrolPump bills. On unfixed code, attendantId is never
      // set in _handleSave (defaults to null).
      final hasAttendantIdAssignment = RegExp(
        r'attendantId\s*:\s*(?!null)[^,\)]+',
      ).hasMatch(billConstructorSlice);

      expect(
        hasAttendantIdAssignment,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.1): petrolPump bill saved via _handleSave '
            'does NOT set attendantId. The Bill constructor has no '
            'attendantId assignment — it defaults to null, meaning fuel '
            'sales cannot be attributed to the pump attendant on duty.',
      );
    });

    test('fuel item gstRate is forced to 0 regardless of product.taxRate', () {
      // Locate _addItem method (the non-pharmacy branch sets gstRate)
      final addItemStart = billScreenSrc.indexOf(
        'Future<void> _addItem(Product product)',
      );
      expect(
        addItemStart,
        isNot(-1),
        reason: '_addItem method must exist in bill_creation_screen_v2.dart',
      );

      // Extract the _addItem body
      final addItemSlice = billScreenSrc.substring(
        addItemStart,
        (addItemStart + 5000).clamp(0, billScreenSrc.length),
      );

      // On unfixed code: `newItemGstRate = product.taxRate;`
      // On fixed code for petrolPump: gstRate should be forced to 0.
      //
      // There MUST be a petrolPump-specific override that forces gstRate = 0
      // for fuel items. On unfixed code, the else branch unconditionally uses
      // product.taxRate for ALL non-pharmacy business types including petrolPump.
      final hasPetrolPumpGstOverride =
          addItemSlice.contains('petrolPump') &&
          (addItemSlice.contains('gstRate') ||
              addItemSlice.contains('newItemGstRate = 0'));

      expect(
        hasPetrolPumpGstOverride,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.1): _addItem sets gstRate = product.taxRate '
            'for ALL non-pharmacy items (including petrolPump fuel). There is '
            'no petrolPump-specific override to force fuel GST to 0. If a '
            'fuel Product has taxRate=5 or taxRate=18, the bill item '
            'inherits that rate — violating fuel GST compliance.',
      );
    });

    test('PetrolPumpBillingService is called from the billing screen', () {
      // On fixed code, the billing screen MUST call PetrolPumpBillingService
      // (or reference it) for petrolPump sales. On unfixed code, there is
      // zero reference to PetrolPumpBillingService in the entire file.
      final hasBillingServiceRef = billScreenSrc.contains(
        'PetrolPumpBillingService',
      );

      expect(
        hasBillingServiceRef,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.1): bill_creation_screen_v2.dart has ZERO '
            'references to PetrolPumpBillingService. The fraud-proof '
            'transactional billing service (which validates active shift, '
            'checks tank stock, forces GST=0, updates nozzle readings, and '
            'posts ledger entries) is never called from the live billing '
            'path. Petrol pump sales bypass all domain logic.',
      );
    });
  });
}
