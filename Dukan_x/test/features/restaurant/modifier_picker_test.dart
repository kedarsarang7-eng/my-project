// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: Modifier/add-on picker is absent from bill-item edit action
// for restaurant business type.
//
// **Validates: Requirements 2.10**
//
// Context:
//   - `food_item_variation_model.dart` declares a `FoodItemVariation` model
//     (Half/Full/Quarter pricing + arbitrary variations per menu item)
//   - `bill_creation_screen_v2.dart` renders bill line items via `AdaptiveItemCard`
//     with `onUpdate` and `onRemove` callbacks — but NO modifier/add-on picker
//     is ever shown from the edit action for restaurant bills
//   - No reference to `Modifier`, `AddOn`, `extras`, `variation`, or
//     `FoodItemVariation` exists in the billing feature (`lib/features/billing/`)
//   - The `BillItem` model has no `modifierIds` or `modifierPriceDelta` fields
//
// This test asserts the CORRECT behavior (a modifier picker SHOULD exist and
// be reachable from the bill-item edit action when businessType == restaurant).
// On UNFIXED code this FAILS because:
//   1. No modifier picker widget exists in the billing feature
//   2. No reference to FoodItemVariation/modifiers in the bill flow
//   3. BillItem has no modifier-related fields
//
// COUNTEREXAMPLE (documented after first run):
//   bill_creation_screen_v2.dart contains zero references to 'modifier',
//   'variation', 'addon', 'add-on', or 'FoodItemVariation'. The bill-item
//   edit action (AdaptiveItemCard.onUpdate) only supports price/quantity/
//   discount edits — no modifier/add-on selection is possible for restaurant
//   bills, despite the variation model existing in the codebase.
//
// Run: flutter test test/features/restaurant/modifier_picker_test.dart
library;

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Terms that MUST be present in the bill flow if a modifier picker is wired.
const List<String> kModifierTerms = <String>[
  'modifier',
  'Modifier',
  'addon',
  'addOn',
  'add-on',
  'AddOn',
  'variation',
  'Variation',
  'FoodItemVariation',
  'extras',
  'Extras',
  '_ModifierPickerSheet',
  'ModifierPicker',
  'modifierIds',
  'modifierPriceDelta',
];

/// Files that MUST reference modifier/variation logic if the picker is wired.
const List<String> kBillFlowFiles = <String>[
  'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
  'lib/features/billing/presentation/widgets/adaptive_item_card.dart',
];

/// The variation model file that should be imported by the bill flow.
const String kVariationModelPath =
    'lib/features/restaurant/data/models/food_item_variation_model.dart';

/// The BillItem entity that should carry modifier fields.
const String kBillItemPath =
    'lib/features/billing/domain/entities/bill_item.dart';

/// The legacy BillItem model (models/bill.dart) used by the screen.
const String kLegacyBillItemPath = 'lib/models/bill.dart';

void main() {
  late String billScreenSource;
  late String adaptiveCardSource;
  late String billItemSource;
  late String legacyBillItemSource;

  setUpAll(() {
    final billScreenFile = File(kBillFlowFiles[0]);
    expect(
      billScreenFile.existsSync(),
      isTrue,
      reason: 'bill_creation_screen_v2.dart must exist',
    );
    billScreenSource = billScreenFile.readAsStringSync();

    final adaptiveCardFile = File(kBillFlowFiles[1]);
    expect(
      adaptiveCardFile.existsSync(),
      isTrue,
      reason: 'adaptive_item_card.dart must exist',
    );
    adaptiveCardSource = adaptiveCardFile.readAsStringSync();

    final billItemFile = File(kBillItemPath);
    expect(
      billItemFile.existsSync(),
      isTrue,
      reason: 'BillItem entity must exist',
    );
    billItemSource = billItemFile.readAsStringSync();

    final legacyBillFile = File(kLegacyBillItemPath);
    expect(
      legacyBillFile.existsSync(),
      isTrue,
      reason: 'Legacy BillItem model must exist',
    );
    legacyBillItemSource = legacyBillFile.readAsStringSync();
  });

  // ===========================================================================
  // GROUP 1: Structural assertion — modifier terms MUST be present in the
  //          bill flow files if the picker is correctly wired.
  //
  // On UNFIXED code: FAILS — no modifier terms found anywhere in the bill flow.
  // ===========================================================================
  group('Modifier picker reachable from bill-item edit (Req 2.10)', () {
    test(
      'bill_creation_screen_v2.dart references modifier/variation/addon terms',
      () {
        final hasAnyModifierTerm = kModifierTerms.any(
          (term) => billScreenSource.contains(term),
        );

        expect(
          hasAnyModifierTerm,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Req 2.10): bill_creation_screen_v2.dart contains '
              'ZERO references to modifier/variation/addon terms.\n\n'
              'Current behavior: the bill-item edit action (AdaptiveItemCard.onUpdate) '
              'only supports price/quantity/discount edits. No modifier/add-on '
              'picker is shown for restaurant bills, despite '
              'food_item_variation_model.dart existing in the codebase.\n\n'
              'Expected behavior: a _ModifierPickerSheet (or equivalent) is '
              'invoked from the item row edit action when '
              'businessType == BusinessType.restaurant, backed by '
              'FoodItemVariationRepository.getVariationsForItem(itemId).',
        );
      },
    );

    test(
      'adaptive_item_card.dart has a modifier/variation edit affordance',
      () {
        final hasModifierAffordance = kModifierTerms.any(
          (term) => adaptiveCardSource.contains(term),
        );

        expect(
          hasModifierAffordance,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Req 2.10): adaptive_item_card.dart has no '
              'modifier/variation/addon UI affordance.\n\n'
              'Current behavior: the card renders price, quantity, discount '
              'controls and a remove button — no modifier picker trigger.\n\n'
              'Expected behavior: for restaurant bills, an "Add Modifier" or '
              '"Variations" action is available from the item card.',
        );
      },
    );

    test('bill_creation_screen_v2.dart imports FoodItemVariation model', () {
      final importsVariation =
          billScreenSource.contains('food_item_variation_model') ||
          billScreenSource.contains('FoodItemVariation');

      expect(
        importsVariation,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.10): bill_creation_screen_v2.dart does not '
            'import food_item_variation_model.dart or reference '
            'FoodItemVariation.\n\n'
            'The variation model exists at:\n'
            '  lib/features/restaurant/data/models/food_item_variation_model.dart\n'
            'but is never imported or used in the bill flow.\n\n'
            'Expected: the bill screen imports the variation model to back '
            'the modifier picker.',
      );
    });
  });

  // ===========================================================================
  // GROUP 2: BillItem model MUST carry modifier-related fields.
  //
  // On UNFIXED code: FAILS — BillItem has no modifierIds/modifierPriceDelta.
  // ===========================================================================
  group('BillItem model carries modifier fields (Req 2.10)', () {
    test('BillItem entity has modifierIds field', () {
      final hasModifierIds =
          billItemSource.contains('modifierIds') ||
          legacyBillItemSource.contains('modifierIds');

      expect(
        hasModifierIds,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.10): Neither BillItem entity '
            '(lib/features/billing/domain/entities/bill_item.dart) nor the '
            'legacy BillItem model (lib/models/bill.dart) declares a '
            '"modifierIds" field.\n\n'
            'Expected: BillItem carries List<String>? modifierIds to persist '
            'selected variation/modifier choices per line item.',
      );
    });

    test('BillItem entity has modifierPriceDelta field', () {
      final hasModifierDelta =
          billItemSource.contains('modifierPriceDelta') ||
          legacyBillItemSource.contains('modifierPriceDelta');

      expect(
        hasModifierDelta,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.10): Neither BillItem entity nor the '
            'legacy BillItem model declares a "modifierPriceDelta" field.\n\n'
            'Expected: BillItem carries double? modifierPriceDelta so the '
            'modifier price adjustment is additive to the base line-item price.',
      );
    });
  });

  // ===========================================================================
  // GROUP 3: PBT — for randomized menu item IDs and restaurant business type,
  //          the bill flow source MUST contain modifier-picker logic.
  //
  // On UNFIXED code: FAILS — structural invariant not satisfied.
  // ===========================================================================
  group('PBT: Modifier picker structurally wired for restaurant', () {
    test('PBT: for any restaurant menu item, modifier picker is reachable', () {
      // This PBT generates random item ids and asserts that the bill screen
      // source structurally supports a modifier picker for restaurant items.
      // The property holds iff the screen references modifier/variation terms
      // AND gates them on BusinessType.restaurant.
      final held = forAll(
        (int itemIdx) {
          // For ANY restaurant menu item (represented by random index),
          // the bill creation flow must have a modifier picker reachable.
          // Structural check: the source must contain both:
          //   (a) a modifier-related term, AND
          //   (b) a restaurant business type gate for the picker
          final hasModifierTerm = kModifierTerms.any(
            (term) => billScreenSource.contains(term),
          );
          final hasRestaurantGate =
              billScreenSource.contains('BusinessType.restaurant') &&
              hasModifierTerm;

          return hasRestaurantGate;
        },
        [Gen.interval(0, 99)],
        numRuns: 50,
      );

      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (PBT, Req 2.10): bill_creation_screen_v2.dart '
            'does not contain modifier/variation terms gated on '
            'BusinessType.restaurant.\n\n'
            'For ANY restaurant menu item added to a bill, there is no '
            'modifier picker reachable from the edit action.\n\n'
            'Expected: the bill screen contains a modifier picker widget '
            '(e.g., _ModifierPickerSheet) invoked when '
            'businessType == BusinessType.restaurant.',
      );
    });

    test('PBT: FoodItemVariation model exists but is unused in bill flow', () {
      final variationFile = File(kVariationModelPath);

      final held = forAll(
        (int seed) {
          // The variation model file MUST exist (it does)
          if (!variationFile.existsSync()) return false;

          // AND the bill screen MUST import/reference it (it doesn't today)
          final referencesVariation =
              billScreenSource.contains('food_item_variation') ||
              billScreenSource.contains('FoodItemVariation') ||
              billScreenSource.contains('getVariationsForItem');

          return referencesVariation;
        },
        [Gen.interval(0, 49)],
        numRuns: 30,
      );

      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (PBT, Req 2.10): food_item_variation_model.dart '
            'EXISTS in the codebase at:\n'
            '  $kVariationModelPath\n'
            'but is NEVER referenced from the bill flow.\n\n'
            'The variation model declares Half/Full/Quarter pricing per '
            'menu item, but no bill-creation code imports or queries it.\n\n'
            'Expected: bill_creation_screen_v2.dart imports the variation '
            'model and queries variations for the selected menu item when '
            'businessType == restaurant.',
      );
    });
  });
}
