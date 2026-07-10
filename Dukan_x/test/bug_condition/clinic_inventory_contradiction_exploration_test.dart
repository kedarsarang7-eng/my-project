// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: inventory.threeWayContradiction (Requirement 1.2)
//
// The clinic business type has a three-way contradiction:
//   1. business_type_config.dart's clinic `modules` list advertises 'inventory'
//   2. ClinicBillingService.addPrescriptionToBill() deducts real stock via
//      InventoryService.deductStockInTransaction when a medicine has productId
//   3. BUT business_capability.dart's clinic registry grants ZERO inventory
//      capabilities AND no clinic sidebar item resolves to an inventory screen
//
// This means stock is deducted but can never be viewed, stocked-in, or
// reconciled through any clinic-reachable UI.
//
// This test asserts that clinic SHOULD have inventory visibility (canAccess
// returns true for useInventoryList/useVisibleStock/useStockEntry) and that
// a sidebar item resolves to an inventory screen. On UNFIXED code these
// assertions FAIL because the capabilities are not granted and no sidebar
// item exists.
//
// **Validates: Requirements 1.2**
//
// COUNTEREXAMPLE (documented after first run):
// FeatureResolver.canAccess('clinic', useInventoryList) == false
// FeatureResolver.canAccess('clinic', useVisibleStock) == false
// FeatureResolver.canAccess('clinic', useStockEntry) == false
// Zero clinic sidebar item ids resolve to InventoryDashboardScreen
// Yet addPrescriptionToBill deducts stock via deductStockInTransaction when
// a prescribed medicine has a linked productId — stock is deducted into an
// invisible void.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';

void main() {
  group('Bug Condition 1.2 — inventory.threeWayContradiction', () {
    // =========================================================================
    // Sub-Test 1: Clinic must have useInventoryList capability granted.
    // On UNFIXED code this FAILS — clinic's registry entry has zero inventory
    // capabilities (comment: "// 2. Inventory // All ❌").
    // =========================================================================
    test('clinic has useInventoryList capability granted', () {
      final hasCapability = FeatureResolver.canAccess(
        'clinic',
        BusinessCapability.useInventoryList,
      );

      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): FeatureResolver.canAccess("clinic", '
            'BusinessCapability.useInventoryList) == false.\n\n'
            'The clinic capability registry in business_capability.dart has:\n'
            '  // 2. Inventory\n'
            '  // All ❌\n\n'
            'Yet ClinicBillingService.addPrescriptionToBill() calls\n'
            'InventoryService.deductStockInTransaction() when a prescribed\n'
            'medicine has a linked productId — stock is deducted but no\n'
            'clinic screen can show that this happened or let clinic staff\n'
            'stock it back in. The fix must grant useInventoryList to clinic.',
      );
    });

    // =========================================================================
    // Sub-Test 2: Clinic must have useVisibleStock capability granted.
    // On UNFIXED code this FAILS — same reason as above.
    // =========================================================================
    test('clinic has useVisibleStock capability granted', () {
      final hasCapability = FeatureResolver.canAccess(
        'clinic',
        BusinessCapability.useVisibleStock,
      );

      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): FeatureResolver.canAccess("clinic", '
            'BusinessCapability.useVisibleStock) == false.\n\n'
            'Clinic cannot view available stock even though stock is\n'
            'actively deducted by addPrescriptionToBill. The three-way\n'
            'contradiction: modules list says "inventory", deduction happens,\n'
            'but capability is denied so no stock screen is reachable.',
      );
    });

    // =========================================================================
    // Sub-Test 3: Clinic must have useStockEntry capability granted.
    // On UNFIXED code this FAILS — same reason as above.
    // =========================================================================
    test('clinic has useStockEntry capability granted', () {
      final hasCapability = FeatureResolver.canAccess(
        'clinic',
        BusinessCapability.useStockEntry,
      );

      expect(
        hasCapability,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): FeatureResolver.canAccess("clinic", '
            'BusinessCapability.useStockEntry) == false.\n\n'
            'Stock is deducted by ClinicBillingService but clinic cannot\n'
            'stock-in (replenish) medicine inventory because useStockEntry\n'
            'is not granted. This means dispensed stock can never be\n'
            'replenished through any clinic-reachable workflow.',
      );
    });

    // =========================================================================
    // Sub-Test 4: A clinic sidebar item must resolve to an inventory screen.
    // We check the sidebar configuration source to see if any item with id
    // containing 'inventory' exists in _getClinicSections(). On UNFIXED code
    // this FAILS — no clinic sidebar item points to inventory.
    // =========================================================================
    test('clinic sidebar has an inventory item in _getClinicSections()', () {
      final sidebarSrc = File(
        'lib/widgets/desktop/sidebar_configuration.dart',
      ).readAsStringSync();

      // Extract _getClinicSections() body
      final funcIdx = sidebarSrc.indexOf('_getClinicSections() {');
      expect(funcIdx, isNot(-1), reason: '_getClinicSections must exist');

      final bodyStart = sidebarSrc.indexOf('{', funcIdx);
      int depth = 0;
      int bodyEnd = -1;
      for (int i = bodyStart; i < sidebarSrc.length; i++) {
        if (sidebarSrc[i] == '{') depth++;
        if (sidebarSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            bodyEnd = i + 1;
            break;
          }
        }
      }
      expect(bodyEnd, isNot(-1));

      final clinicSectionsBody = sidebarSrc.substring(bodyStart, bodyEnd);

      // Look for a sidebar item id related to inventory (e.g. 'clinic_inventory')
      final hasInventoryItem =
          clinicSectionsBody.contains("'clinic_inventory'") ||
          clinicSectionsBody.contains('"clinic_inventory"') ||
          (clinicSectionsBody.contains("'inventory'") &&
              clinicSectionsBody.contains('InventoryDashboardScreen'));

      expect(
        hasInventoryItem,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): _getClinicSections() has ZERO inventory '
            'sidebar items. No item id resolves to InventoryDashboardScreen '
            'for clinic.\n\n'
            'The clinic sidebar sections are: Clinic Dashboard, Patient '
            'Management, Clinical Desk, Billing & Revenue, Reports & '
            'Accounts, System — none includes an inventory screen.\n\n'
            'Yet addPrescriptionToBill deducts stock from inventory. The '
            'dispensed medicine stock is invisible and un-reconcilable.\n\n'
            'The fix must add a SidebarMenuItem (e.g. id: "clinic_inventory") '
            'gated by BusinessCapability.useInventoryList that resolves to '
            'InventoryDashboardScreen.',
      );
    });

    // =========================================================================
    // Sub-Test 5: SidebarNavigationHandler must map a clinic inventory id to
    // InventoryDashboardScreen. On UNFIXED code no such case exists.
    // =========================================================================
    test('SidebarNavigationHandler resolves clinic_inventory to a screen', () {
      final navSrc = File(
        'lib/widgets/desktop/sidebar_navigation_handler.dart',
      ).readAsStringSync();

      // Check if 'clinic_inventory' case exists in the navigation handler
      final hasClinicInventoryCase =
          navSrc.contains("case 'clinic_inventory'") ||
          navSrc.contains('case "clinic_inventory"');

      expect(
        hasClinicInventoryCase,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.2): SidebarNavigationHandler has NO case for '
            '"clinic_inventory". The clinic sidebar has no inventory entry '
            'point — even if we added an item id, it would resolve to the '
            'placeholder screen.\n\n'
            'The fix must add:\n'
            '  case \'clinic_inventory\':\n'
            '    return const InventoryDashboardScreen();\n\n'
            'So that dispensed/deducted medicine stock is viewable.',
      );
    });

    // =========================================================================
    // Sub-Test 6: Confirm the contradiction — addPrescriptionToBill DOES call
    // deductStockInTransaction when productId is present. This confirms that
    // the deduction pathway is real (not hypothetical), making the missing
    // visibility a genuine bug rather than a dormant inconsistency.
    // =========================================================================
    test(
      'addPrescriptionToBill calls deductStockInTransaction (deduction is real)',
      () {
        final billingServiceSrc = File(
          'lib/features/doctor/services/clinic_billing_service.dart',
        ).readAsStringSync();

        // Find addPrescriptionToBill method — uses named parameters so the
        // first '{' after indexOf is the parameter-list brace. Skip to
        // 'async {' to get the actual method body.
        final methodIdx = billingServiceSrc.indexOf('addPrescriptionToBill');
        expect(
          methodIdx,
          isNot(-1),
          reason:
              'addPrescriptionToBill must exist in clinic_billing_service.dart',
        );

        // Find 'async' keyword after the method declaration, then its body '{'
        final asyncIdx = billingServiceSrc.indexOf('async', methodIdx);
        expect(asyncIdx, isNot(-1), reason: 'Method must be async');
        final bodyStart = billingServiceSrc.indexOf('{', asyncIdx);
        expect(bodyStart, isNot(-1));

        int depth = 0;
        int bodyEnd = -1;
        for (int i = bodyStart; i < billingServiceSrc.length; i++) {
          if (billingServiceSrc[i] == '{') depth++;
          if (billingServiceSrc[i] == '}') {
            depth--;
            if (depth == 0) {
              bodyEnd = i + 1;
              break;
            }
          }
        }
        expect(bodyEnd, isNot(-1));

        final methodBody = billingServiceSrc.substring(bodyStart, bodyEnd);

        // Confirm deductStockInTransaction is called
        final callsDeduction = methodBody.contains('deductStockInTransaction');
        expect(
          callsDeduction,
          isTrue,
          reason:
              'addPrescriptionToBill must call deductStockInTransaction — '
              'this confirms stock IS being deducted for clinic prescriptions',
        );

        // Confirm the deduction is gated on productId (not unconditional)
        final gatedOnProductId = methodBody.contains('productId');
        expect(
          gatedOnProductId,
          isTrue,
          reason:
              'Deduction should be conditional on productId existing — '
              'confirms the contradiction is real for medicines with linked products',
        );

        // Now assert the CONTRADICTION: deduction happens but canAccess is false.
        // This is the actual bug assertion — the system is inconsistent.
        final clinicCanAccessInventory = FeatureResolver.canAccess(
          'clinic',
          BusinessCapability.useInventoryList,
        );

        // Assert consistency: IF deduction happens, THEN visibility should exist.
        // On UNFIXED code this FAILS because deduction IS happening (confirmed
        // above) but canAccess returns false (inventory is invisible to clinic).
        expect(
          clinicCanAccessInventory,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.2 — THREE-WAY CONTRADICTION):\n\n'
              '1. business_type_config.dart clinic modules: ["inventory"] ✓\n'
              '2. addPrescriptionToBill calls deductStockInTransaction ✓\n'
              '3. canAccess("clinic", useInventoryList) == FALSE ✗\n\n'
              'Stock IS being deducted (productId-linked prescription → '
              'deductStockInTransaction) but clinic has NO capability to '
              'view, search, or stock-in that inventory.\n\n'
              'Example: Doctor prescribes Paracetamol linked to productId '
              '"prod_123" with dosage "1-0-1" for "5 days". '
              'addPrescriptionToBill computes quantity=10 and calls '
              'deductStockInTransaction, reducing prod_123 stock by 10 '
              'units. But no clinic screen can show this deduction or let '
              'staff stock it back in — the stock is invisible.\n\n'
              'The fix must grant useInventoryList (+ useVisibleStock, '
              'useStockEntry) to clinic AND add a sidebar item resolving '
              'to InventoryDashboardScreen.',
        );
      },
    );
  });
}
