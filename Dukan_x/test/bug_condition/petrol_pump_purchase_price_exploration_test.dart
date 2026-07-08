/// Bug Condition Exploration Test — stock.purchasePriceDiscarded
///
/// **Validates: Requirements 1.7**
///
/// Property 7: Bug Condition — Purchase Price Persisted
///
/// This test confirms that `TankService.addPurchase` does NOT accept a
/// `pricePerLitre` (or equivalent price) parameter in its signature, and
/// that `add_stock_dialog.dart._submit` captures a price value via
/// `_priceController.text` but never passes it to `addPurchase`.
///
/// On UNFIXED code this test FAILS — `addPurchase` has no price parameter
/// and the dialog silently discards the user-entered price.
/// After the fix this same test PASSES — `addPurchase` accepts
/// `pricePerLitre` and the dialog passes the captured price through.
///
/// Run: flutter test test/bug_condition/petrol_pump_purchase_price_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // stock.purchasePriceDiscarded / 1.7 / 2.7 — Purchase price is captured in
  // the UI (AddStockDialog._priceController) but never passed to
  // TankService.addPurchase because the method signature only accepts
  // (String tankId, double quantity, {String? employeeId, String? invoiceNumber}).
  //
  // Expected (post-fix): TankService.addPurchase accepts a `pricePerLitre`
  // parameter and the dialog passes it. The logged stock-movement metadata
  // contains `pricePerLitre` and `totalCost`.
  //
  // Bug condition: addPurchase has no price parameter; the dialog reads
  // _priceController.text but discards it — the price is never persisted.
  // ===========================================================================
  group('Bug Condition 1.7 — stock.purchasePriceDiscarded', () {
    late String tankServiceSrc;
    late String addStockDialogSrc;

    setUpAll(() {
      tankServiceSrc = _readSource(
        'lib/features/petrol_pump/services/tank_service.dart',
      );
      assert(tankServiceSrc.isNotEmpty, 'tank_service.dart must exist');

      addStockDialogSrc = _readSource(
        'lib/features/petrol_pump/presentation/dialogs/add_stock_dialog.dart',
      );
      assert(addStockDialogSrc.isNotEmpty, 'add_stock_dialog.dart must exist');
    });

    test('TankService.addPurchase signature includes a price parameter', () {
      // On FIXED code: addPurchase should have a `pricePerLitre` or
      // `price` named parameter in its signature.
      //
      // On UNFIXED code: the signature is only
      // (String tankId, double quantity, {String? employeeId, String? invoiceNumber})

      // Find the addPurchase method definition
      final methodIdx = tankServiceSrc.indexOf('Future<void> addPurchase');
      expect(
        methodIdx,
        isNot(-1),
        reason: 'addPurchase method must exist in TankService',
      );

      // Extract the method signature (up to the opening brace of the body)
      final openBraceIdx = tankServiceSrc.indexOf(') async {', methodIdx);
      expect(
        openBraceIdx,
        isNot(-1),
        reason: 'addPurchase must have an async body',
      );

      final signature = tankServiceSrc.substring(methodIdx, openBraceIdx + 1);

      // Check that the signature includes a price parameter
      final hasPriceParam =
          signature.contains('pricePerLitre') ||
          signature.contains('price') ||
          signature.contains('costPerLitre') ||
          signature.contains('unitPrice');

      expect(
        hasPriceParam,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.7): TankService.addPurchase signature is:\n'
            '  $signature\n'
            'It does NOT include a pricePerLitre, price, costPerLitre, or '
            'unitPrice parameter. The purchase price entered by the user '
            'in AddStockDialog cannot be passed to this method — it is '
            'silently discarded. The method must accept a price parameter '
            'so the cost data can be persisted in stock-movement metadata.',
      );
    });

    test(
      'addPurchase logs pricePerLitre and totalCost in stock-movement metadata',
      () {
        // On FIXED code: the _logStockEvent call in addPurchase should
        // include 'pricePerLitre' and 'totalCost' in its metadata map.
        //
        // On UNFIXED code: the metadata only contains quantityAdded,
        // stockBefore, stockAfter, invoiceNumber — no price/cost fields.

        // Find addPurchase body
        final methodIdx = tankServiceSrc.indexOf('Future<void> addPurchase');
        expect(methodIdx, isNot(-1));

        // Extract a generous slice of the method body
        final bodySlice = tankServiceSrc.substring(
          methodIdx,
          (methodIdx + 2000).clamp(0, tankServiceSrc.length),
        );

        final hasPriceInMetadata =
            bodySlice.contains("'pricePerLitre'") ||
            bodySlice.contains('"pricePerLitre"');

        final hasTotalCostInMetadata =
            bodySlice.contains("'totalCost'") ||
            bodySlice.contains('"totalCost"');

        expect(
          hasPriceInMetadata && hasTotalCostInMetadata,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.7): TankService.addPurchase _logStockEvent '
              'metadata does NOT contain pricePerLitre and/or totalCost. '
              'Current metadata only logs: quantityAdded, stockBefore, '
              'stockAfter, invoiceNumber. The purchase price is never '
              'persisted in the audit/stock-movement record, making it '
              'impossible for the Fuel Profit report (Surface 6) to '
              'compute real cost figures.',
        );
      },
    );

    test('AddStockDialog._submit passes the captured price to addPurchase', () {
      // On FIXED code: _submit should pass _priceController.text
      // (parsed to double) to addPurchase's pricePerLitre parameter.
      //
      // On UNFIXED code: _submit only passes tankId and quantity:
      //   await sl<TankService>().addPurchase(widget.tank.tankId, quantity);

      // Find the _submit method
      final submitIdx = addStockDialogSrc.indexOf('Future<void> _submit');
      expect(
        submitIdx,
        isNot(-1),
        reason: '_submit method must exist in AddStockDialog',
      );

      // Extract the _submit method body
      final submitBody = addStockDialogSrc.substring(
        submitIdx,
        (submitIdx + 1500).clamp(0, addStockDialogSrc.length),
      );

      // Check that the addPurchase call includes a price argument
      final addPurchaseCallIdx = submitBody.indexOf('addPurchase');
      expect(
        addPurchaseCallIdx,
        isNot(-1),
        reason: '_submit must call addPurchase',
      );

      // Extract the addPurchase call
      final callSlice = submitBody.substring(
        addPurchaseCallIdx,
        (addPurchaseCallIdx + 400).clamp(0, submitBody.length),
      );

      final passesPriceArg =
          callSlice.contains('pricePerLitre') ||
          callSlice.contains('price:') ||
          callSlice.contains('_priceController');

      expect(
        passesPriceArg,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.7): AddStockDialog._submit calls '
            'addPurchase WITHOUT passing the price. The call is:\n'
            '  ${callSlice.split('\n').first.trim()}\n'
            'The _priceController.text value is captured in the UI form '
            'but is never included in the addPurchase() call. The '
            'user-entered purchase price is silently discarded — it never '
            'reaches TankService and is never logged in the stock-movement '
            'metadata.',
      );
    });
  });
}
