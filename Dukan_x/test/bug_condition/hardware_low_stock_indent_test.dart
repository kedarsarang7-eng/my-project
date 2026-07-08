/// Bug Condition Exploration Test — Low-Stock Check on Indent Creation (HARDWARE-014)
///
/// **Validates: Requirements 1.14, 2.14**
///
/// Property 14: Before submitting an indent, the system checks each requested
/// product's current local inventory stock level and surfaces a low-stock
/// warning when the stock is below the reorder point. Optionally suggests a
/// purchase order.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'indent.create'`
///
/// BEFORE fix: `createIndent()` simply validates HSN codes and persists to
/// local DB + sync queue — NO stock check, NO low-stock warning.
///
/// AFTER fix: `checkLowStockForIndent()` queries local inventory table,
/// compares stock against reorder level, and returns low-stock items.
/// `createIndentWithStockCheck()` integrates this into the indent creation
/// flow as a non-blocking advisory warning.
///
/// Preservation: indents for items with sufficient stock proceed without
/// any warning or extra step.
///
/// Strategy:
///   1. Source-code probe: assert that `HardwareOpsRepository` has a
///      `checkLowStockForIndent` method and that the low-stock checker
///      utility exists.
///   2. Unit test: assert `LowStockChecker.check()` correctly identifies
///      items below reorder point.
///   3. Preservation: items above reorder level produce no warning.
///
/// Run: flutter test test/bug_condition/hardware_low_stock_indent_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/utils/low_stock_checker.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-014 — low-stock check on indent creation', () {
    // =========================================================================
    // Source-code probe: repository references low-stock check
    // =========================================================================
    group('Source-code integration probe', () {
      final repoSrc = _readSource(
        'lib/features/hardware/data/hardware_ops_repository.dart',
      );

      test('HardwareOpsRepository has checkLowStockForIndent method', () {
        final hasMethod = repoSrc.contains('checkLowStockForIndent');

        expect(
          hasMethod,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-014): HardwareOpsRepository has NO '
              'checkLowStockForIndent method. Indent creation proceeds without '
              'any stock level check. Fix: add checkLowStockForIndent() that '
              'queries local inventory and flags items below reorder point.',
        );
      });

      test('HardwareOpsRepository has createIndentWithStockCheck method', () {
        final hasMethod = repoSrc.contains('createIndentWithStockCheck');

        expect(
          hasMethod,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-014): HardwareOpsRepository has NO '
              'createIndentWithStockCheck method. The UI has no integrated '
              'entry point to create an indent with stock advisory.',
        );
      });

      test('repository imports low_stock_checker.dart', () {
        final importsChecker =
            repoSrc.contains('low_stock_checker') ||
            repoSrc.contains('LowStockChecker');

        expect(
          importsChecker,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-014): HardwareOpsRepository does not '
              'import the low-stock checker. No stock check can be performed.',
        );
      });

      test('low_stock_checker.dart utility exists', () {
        final checkerFile = File(
          'lib/features/hardware/utils/low_stock_checker.dart',
        );

        expect(
          checkerFile.existsSync(),
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-014): low_stock_checker.dart does not '
              'exist. There is no utility to check stock levels at indent '
              'creation time.',
        );
      });
    });

    // =========================================================================
    // Unit tests: LowStockChecker logic
    // =========================================================================
    group('LowStockChecker.check() logic', () {
      test('item below reorder point is flagged as low stock', () {
        // Product has 5 units in stock, reorder level is 10
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 3.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 5.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isTrue);
        expect(result.lowStockItems.length, equals(1));
        expect(result.lowStockItems.first.productId, equals('prod-001'));
        expect(result.lowStockItems.first.currentStock, equals(5.0));
        expect(result.lowStockItems.first.reorderLevel, equals(10.0));
        expect(result.warningMessage, isNotEmpty);
      });

      test('item at exactly reorder point is NOT flagged (boundary)', () {
        // Product has exactly 10 units, reorder level is 10 → NOT below
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 2.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 10.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isFalse);
        expect(result.lowStockItems, isEmpty);
      });

      test('item above reorder point is NOT flagged (preservation)', () {
        // Product has 20 units, reorder level is 10 → sufficient stock
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 5.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 20.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isFalse);
        expect(result.lowStockItems, isEmpty);
        expect(result.warningMessage, isEmpty);
      });

      test('item with zero reorder level is NEVER flagged', () {
        // Product has 0 stock but reorder level is 0 (not configured)
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 10.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Custom Item',
              quantity: 0.0,
              reorderLevel: 0.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isFalse);
        expect(result.lowStockItems, isEmpty);
      });

      test('multiple items: mixed stock levels flag only low-stock ones', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 5.0},
            {'productId': 'prod-002', 'quantity': 3.0},
            {'productId': 'prod-003', 'quantity': 2.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 3.0, // Below reorder (10)
              reorderLevel: 10.0,
            ),
            'prod-002': const InventoryStockInfo(
              productId: 'prod-002',
              productName: 'Cement Bag 50kg',
              quantity: 50.0, // Above reorder (20)
              reorderLevel: 20.0,
            ),
            'prod-003': const InventoryStockInfo(
              productId: 'prod-003',
              productName: 'Wire Coil 1kg',
              quantity: 2.0, // Below reorder (15)
              reorderLevel: 15.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isTrue);
        expect(result.lowStockItems.length, equals(2));

        final ids = result.lowStockItems.map((i) => i.productId).toList();
        expect(ids, contains('prod-001'));
        expect(ids, contains('prod-003'));
        expect(ids, isNot(contains('prod-002')));
      });

      test('unknown product (not in inventory) is NOT flagged', () {
        // Product not found in local inventory → skip, no warning
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'unknown-product', 'quantity': 5.0},
          ],
          inventoryData: const {}, // Empty inventory
        );

        expect(result.hasLowStockItems, isFalse);
        expect(result.lowStockItems, isEmpty);
      });

      test('empty indent items list returns clear result', () {
        final result = LowStockChecker.check(
          indentItems: const [],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 1.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isFalse);
      });

      test('suggestPurchaseOrder is true when low stock detected', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 5.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 2.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.suggestPurchaseOrder, isTrue);
      });

      test('suggestedPurchaseQuantity accounts for deficit + requested', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 5.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 3.0,
              reorderLevel: 10.0,
            ),
          },
        );

        // suggestedPurchaseQuantity = (reorderLevel - currentStock + requestedQty)
        // = (10 - 3 + 5) = 12
        expect(
          result.lowStockItems.first.suggestedPurchaseQuantity,
          equals(12.0),
        );
      });

      test('deficit correctly computed', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 1.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 4.0,
              reorderLevel: 10.0,
            ),
          },
        );

        // deficit = reorderLevel - currentStock = 10 - 4 = 6
        expect(result.lowStockItems.first.deficit, equals(6.0));
      });

      test('handles product_id key (underscore variant)', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'product_id': 'prod-001', 'qty': 5.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 2.0,
              reorderLevel: 10.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isTrue);
        expect(result.lowStockItems.first.productId, equals('prod-001'));
      });
    });

    // =========================================================================
    // Preservation: sufficient-stock indents are unaffected
    // =========================================================================
    group('Preservation — sufficient stock indents unaffected', () {
      test('all items above reorder level → no warning, no extra step', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 5.0},
            {'productId': 'prod-002', 'quantity': 10.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Steel Rod 12mm',
              quantity: 100.0,
              reorderLevel: 10.0,
            ),
            'prod-002': const InventoryStockInfo(
              productId: 'prod-002',
              productName: 'Cement Bag 50kg',
              quantity: 50.0,
              reorderLevel: 20.0,
            ),
          },
        );

        expect(result.hasLowStockItems, isFalse);
        expect(result.lowStockItems, isEmpty);
        expect(result.warningMessage, isEmpty);
        expect(result.suggestPurchaseOrder, isFalse);
      });

      test('warningMessage is empty for sufficient-stock indents', () {
        final result = LowStockChecker.check(
          indentItems: [
            {'productId': 'prod-001', 'quantity': 2.0},
          ],
          inventoryData: {
            'prod-001': const InventoryStockInfo(
              productId: 'prod-001',
              productName: 'Wire Coil',
              quantity: 50.0,
              reorderLevel: 5.0,
            ),
          },
        );

        expect(result.warningMessage, isEmpty);
      });
    });
  });
}
