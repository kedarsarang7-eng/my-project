// Unit tests for the Clothing vertical — Phase 10, Requirement 16.3.
//
// Covers:
//   1. GST slab rule (including ₹1000 / 100,000 Paise boundary)
//   2. VariantItem model unification (fromJson, toJson, legacy migration)
//   3. Variant cell-key collision-free encoding (including "Off_White")

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/clothing/utils/gst_slab_rule.dart';
import 'package:dukanx/features/clothing/data/variant_repository.dart';
import 'package:dukanx/features/clothing/widgets/variant_grid/variant_cell_key.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. GST Slab Rule
  // ─────────────────────────────────────────────────────────────────────────
  group('GST Slab Rule', () {
    test('99,999 Paise selects 5%', () {
      expect(gstRatePercentForTaxableValue(99999), equals(5));
    });

    test('100,000 Paise selects 12% (₹1000 boundary)', () {
      expect(gstRatePercentForTaxableValue(100000), equals(12));
    });

    test('1 Paise selects 5%', () {
      expect(gstRatePercentForTaxableValue(1), equals(5));
    });

    test('0 Paise returns null (rejected)', () {
      expect(gstRatePercentForTaxableValue(0), isNull);
    });

    test('-1 Paise returns null (rejected)', () {
      expect(gstRatePercentForTaxableValue(-1), isNull);
    });

    test('gstAmountPaise computes correctly with half-up rounding', () {
      // 50,000 Paise at 5% = 2,500 Paise (exact, no rounding needed)
      final result1 = gstAmountPaise(50000, gstEditable: false);
      expect(result1.isSuccess, isTrue);
      expect(result1.result!.amountPaise, equals(2500));
      expect(result1.result!.ratePercent, equals(5));

      // 100,001 Paise at 12% = (100,001 * 12 + 50) ~/ 100 = 1,200,062 ~/ 100 = 12,000
      // Actually: 100,001 * 12 = 1,200,012; + 50 = 1,200,062; ~/ 100 = 12,000
      final result2 = gstAmountPaise(100001, gstEditable: false);
      expect(result2.isSuccess, isTrue);
      expect(result2.result!.amountPaise, equals(12000));
      expect(result2.result!.ratePercent, equals(12));

      // Edge: 1 Paise at 5% = (1 * 5 + 50) ~/ 100 = 55 ~/ 100 = 0 Paise
      final result3 = gstAmountPaise(1, gstEditable: false);
      expect(result3.isSuccess, isTrue);
      expect(result3.result!.amountPaise, equals(0));
      expect(result3.result!.ratePercent, equals(5));

      // Half-up test: 3 Paise at 5% = (3*5+50)~/100 = 65~/100 = 0
      // 10 Paise at 5% = (10*5+50)~/100 = 100~/100 = 1
      final result4 = gstAmountPaise(10, gstEditable: false);
      expect(result4.isSuccess, isTrue);
      expect(result4.result!.amountPaise, equals(1));
    });

    test('override honored when gstEditable=true', () {
      // taxableValue = 50,000 Paise (normally 5%), but override with 18%
      final result = gstAmountPaise(
        50000,
        overrideRatePercent: 18,
        gstEditable: true,
      );
      expect(result.isSuccess, isTrue);
      expect(result.result!.ratePercent, equals(18));
      // (50,000 * 18 + 50) ~/ 100 = 900,050 ~/ 100 = 9,000
      expect(result.result!.amountPaise, equals(9000));
    });

    test('override rejected when gstEditable=false', () {
      // taxableValue = 50,000 Paise (slab = 5%), override with 18% should fail
      final result = gstAmountPaise(
        50000,
        overrideRatePercent: 18,
        gstEditable: false,
      );
      expect(result.isError, isTrue);
      expect(result.error!.message, contains('disabled'));
      expect(result.retainedSlabRatePercent, equals(5));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. VariantItem model
  // ─────────────────────────────────────────────────────────────────────────
  group('VariantItem model', () {
    test('fromJson with new shape (stock, priceCents)', () {
      final json = {
        'id': 'v-001',
        'productId': 'p-001',
        'color': 'Red',
        'size': 'M',
        'sku': 'SKU-RED-M',
        'barcode': 'BAR-RED-M',
        'priceCents': 150000,
        'stock': 42,
      };
      final item = VariantItem.fromJson(json);
      expect(item.id, equals('v-001'));
      expect(item.productId, equals('p-001'));
      expect(item.color, equals('Red'));
      expect(item.size, equals('M'));
      expect(item.sku, equals('SKU-RED-M'));
      expect(item.barcode, equals('BAR-RED-M'));
      expect(item.priceCents, equals(150000));
      expect(item.stock, equals(42));
    });

    test(
      'fromJson with legacy shape (quantity, priceAdjustment) migrates correctly',
      () {
        final json = {
          'id': 'v-002',
          'productId': 'p-002',
          'color': 'Blue',
          'size': 'L',
          'quantity': 10,
          'priceAdjustment': 499.50, // rupees → 49,950 Paise
        };
        final item = VariantItem.fromJson(json);
        expect(item.stock, equals(10));
        expect(item.priceCents, equals(49950)); // 499.50 * 100 = 49,950
      },
    );

    test('fromJson with null optional fields uses defaults', () {
      final json = {
        'id': 'v-003',
        'productId': 'p-003',
        'color': null, // optional — defaults to ''
        'size': null, // optional — defaults to ''
        'sku': null, // optional — defaults to ''
        'barcode': null, // optional — defaults to ''
        'priceCents': null, // optional — defaults to 0
        'stock': null, // optional — defaults to 0
      };
      final item = VariantItem.fromJson(json);
      expect(item.color, equals(''));
      expect(item.size, equals(''));
      expect(item.sku, equals(''));
      expect(item.barcode, equals(''));
      expect(item.priceCents, equals(0));
      expect(item.stock, equals(0));
    });

    test('fromJson with null required field throws FormatException', () {
      // null id
      expect(
        () => VariantItem.fromJson({
          'id': null,
          'productId': 'p-004',
          'color': 'Green',
          'size': 'S',
        }),
        throwsA(isA<FormatException>()),
      );

      // null productId
      expect(
        () => VariantItem.fromJson({
          'id': 'v-004',
          'productId': null,
          'color': 'Green',
          'size': 'S',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson round-trips', () {
      final original = VariantItem(
        id: 'v-005',
        productId: 'p-005',
        color: 'White',
        size: 'XL',
        sku: 'SKU-WHT-XL',
        barcode: 'BAR-WHT-XL',
        priceCents: 299900,
        stock: 100,
      );
      final json = original.toJson();
      final restored = VariantItem.fromJson(json);
      expect(restored.id, equals(original.id));
      expect(restored.productId, equals(original.productId));
      expect(restored.color, equals(original.color));
      expect(restored.size, equals(original.size));
      expect(restored.sku, equals(original.sku));
      expect(restored.barcode, equals(original.barcode));
      expect(restored.priceCents, equals(original.priceCents));
      expect(restored.stock, equals(original.stock));
    });

    test('sku clamped at 64 chars', () {
      final longSku = 'A' * 100; // 100 chars → should be clamped to 64
      final json = {
        'id': 'v-006',
        'productId': 'p-006',
        'color': 'Black',
        'size': 'S',
        'sku': longSku,
      };
      final item = VariantItem.fromJson(json);
      expect(item.sku.length, equals(64));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Variant cell key
  // ─────────────────────────────────────────────────────────────────────────
  group('Variant cell key', () {
    test(
      'variantCellKey produces distinct keys for Off_White/S vs Off/White_S',
      () {
        final key1 = variantCellKey('Off_White', 'S');
        final key2 = variantCellKey('Off', 'White_S');
        expect(key1, isNot(equals(key2)));
        // Verify the encoding: "Off_White" has length 9, "Off" has length 3
        expect(key1, equals('9:Off_White:S'));
        expect(key2, equals('3:Off:White_S'));
      },
    );

    test('parseVariantCellKey round-trips', () {
      // Normal case
      final key = variantCellKey('Red', 'XL');
      final parsed = parseVariantCellKey(key);
      expect(parsed.color, equals('Red'));
      expect(parsed.size, equals('XL'));

      // With underscores
      final key2 = variantCellKey('Off_White', 'XXL');
      final parsed2 = parseVariantCellKey(key2);
      expect(parsed2.color, equals('Off_White'));
      expect(parsed2.size, equals('XXL'));

      // Empty color (edge case — length 0)
      final key3 = variantCellKey('', 'M');
      final parsed3 = parseVariantCellKey(key3);
      expect(parsed3.color, equals(''));
      expect(parsed3.size, equals('M'));
    });

    test('parseVariantCellKey throws on malformed key', () {
      // No colon at all
      expect(
        () => parseVariantCellKey('noColonHere'),
        throwsA(isA<FormatException>()),
      );

      // Non-numeric length prefix
      expect(
        () => parseVariantCellKey('abc:Red:M'),
        throwsA(isA<FormatException>()),
      );

      // Key too short for declared color length
      expect(
        () => parseVariantCellKey('99:R:M'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
