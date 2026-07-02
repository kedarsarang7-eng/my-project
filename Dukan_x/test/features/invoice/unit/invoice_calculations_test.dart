import 'package:dukanx/features/invoice/dedicated/models/jewellery_invoice_item.dart';
import 'package:dukanx/features/invoice/dedicated/models/pharmacy_invoice_item.dart';
import 'package:dukanx/features/invoice/dedicated/models/restaurant_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UniversalInvoiceItem — totals/tax/discount', () {
    test('subtotal = qty * unitPrice', () {
      const it = UniversalInvoiceItem(name: 'x', quantity: 3, unitPrice: 40);
      expect(it.subtotal, 120);
    });

    test('taxable = subtotal - discount', () {
      const it = UniversalInvoiceItem(
        name: 'x',
        quantity: 2,
        unitPrice: 100,
        discount: 20,
      );
      expect(it.subtotal, 200);
      expect(it.taxable, 180);
    });

    test('totalTax = cgst + sgst + igst', () {
      const intra = UniversalInvoiceItem(
        name: 'x',
        quantity: 1,
        unitPrice: 100,
        cgst: 9,
        sgst: 9,
      );
      expect(intra.totalTax, 18);
      const inter = UniversalInvoiceItem(
        name: 'x',
        quantity: 1,
        unitPrice: 100,
        igst: 18,
      );
      expect(inter.totalTax, 18);
    });

    test('total = taxable + totalTax', () {
      const it = UniversalInvoiceItem(
        name: 'x',
        quantity: 2,
        unitPrice: 100,
        discount: 20,
        cgst: 9,
        sgst: 9,
      );
      // taxable 180 + tax 18 = 198
      expect(it.total, 198);
    });

    test('cell() formats currency with the requested symbol', () {
      const it = UniversalInvoiceItem(name: 'x', quantity: 1, unitPrice: 100);
      expect(it.cell('rate', currency: 'Rs.'), 'Rs.100.00');
      expect(it.cell('rate'), '\u20B9100.00');
    });

    test('cell() quantity formats integers vs fractionals', () {
      const whole = UniversalInvoiceItem(name: 'x', quantity: 5, unitPrice: 1);
      const frac = UniversalInvoiceItem(name: 'x', quantity: 2.5, unitPrice: 1);
      expect(whole.cell('qty'), '5');
      expect(frac.cell('qty'), '2.50');
    });
  });

  group('Pharmacy calculations', () {
    test('amount = qty*mrp + tax', () {
      final it = PharmacyInvoiceItem(
        name: 'Med',
        batchNo: 'B1',
        expiryDate: DateTime(2030, 1, 1),
        quantity: 10,
        mrp: 20,
        cgst: 12,
        sgst: 12,
      );
      // taxable 200 + tax 24 = 224
      expect(it.taxable, 200);
      expect(it.amount, 224);
    });

    test('expiry helpers', () {
      final expired = PharmacyInvoiceItem(
        name: 'E',
        batchNo: 'B',
        expiryDate: DateTime(2020, 1, 1),
        quantity: 1,
        mrp: 1,
      );
      final soon = PharmacyInvoiceItem(
        name: 'S',
        batchNo: 'B',
        expiryDate: DateTime(2026, 2, 1),
        quantity: 1,
        mrp: 1,
      );
      final asOf = DateTime(2026, 1, 15);
      expect(expired.isExpired(asOf), isTrue);
      expect(soon.isExpired(asOf), isFalse);
      expect(soon.expiresWithin(asOf, const Duration(days: 90)), isTrue);
    });
  });

  group('Restaurant calculations', () {
    test('amount = qty*price + tax; portion label', () {
      const half = RestaurantInvoiceItem(
        name: 'Dish',
        quantity: 2,
        portion: FoodPortion.half,
        price: 120,
        cgst: 6,
        sgst: 6,
      );
      expect(half.taxable, 240);
      expect(half.amount, 252);
      expect(half.portionLabel, 'Half');
    });
  });

  group('Jewellery calculations', () {
    test('weight-based pricing replaces qty*unitPrice', () {
      const it = JewelleryInvoiceItem(
        name: 'Ring',
        purity: '22K',
        grossWeight: 6,
        netWeight: 5,
        ratePerGram: 6000,
        makingChargePerGram: 500,
        wastagePercent: 2,
        stoneValue: 500,
        oldGoldExchange: 1000,
        gstPercent: 3,
      );
      // metal 30000, wastage 600, making 2500, +stone 500, -oldgold 1000 = 32600
      expect(it.metalValue, 30000);
      expect(it.wastageValue, 600);
      expect(it.makingCharges, 2500);
      expect(it.preTax, 32600);
      expect(it.gstAmount, closeTo(978, 0.001));
      expect(it.amount, closeTo(33578, 0.001));
    });
  });
}
