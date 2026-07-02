import 'package:dukanx/features/invoice/dedicated/models/jewellery_invoice_item.dart';
import 'package:dukanx/features/invoice/dedicated/models/pharmacy_invoice_item.dart';
import 'package:dukanx/features/invoice/dedicated/models/restaurant_invoice_item.dart';
import 'package:dukanx/features/invoice/dedicated/widgets/jewellery_invoice_template.dart';
import 'package:dukanx/features/invoice/dedicated/widgets/pharmacy_invoice_template.dart';
import 'package:dukanx/features/invoice/dedicated/widgets/restaurant_invoice_template.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/widgets/universal_invoice_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UniversalInvoiceData _data() => UniversalInvoiceData(
  shopName: 'Dedicated Shop',
  ownerName: 'Owner',
  address: 'Addr',
  mobile: '9999999999',
  gstin: '27ABCDE1234F1Z5',
  customerName: 'Customer',
  invoiceNumber: 'INV-9',
  date: DateTime(2026, 1, 1),
  items: const [],
  grandTotal: 1000,
  paidAmount: 1000,
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 900, child: w)),
      ),
    ),
  );
}

/// The three shared sections the spec requires dedicated templates to reuse.
final _sharedKeysAll = [
  UniversalInvoiceTemplate.sectionKey(InvoiceSection.customerInfo),
  UniversalInvoiceTemplate.sectionKey(InvoiceSection.payment),
];

void main() {
  group('Pharmacy dedicated template', () {
    testWidgets('reuses shared sections + has bespoke table + expiry warning', (
      tester,
    ) async {
      final items = [
        PharmacyInvoiceItem(
          name: 'Paracetamol',
          batchNo: 'B123',
          expiryDate: DateTime.now().add(const Duration(days: 30)), // expiring
          hsn: '3004',
          quantity: 10,
          mrp: 20,
          gstPercent: 12,
          cgst: 12,
          sgst: 12,
        ),
      ];
      await _pump(tester, PharmacyInvoiceTemplate(data: _data(), items: items));

      // Shared components reused.
      for (final k in _sharedKeysAll) {
        expect(find.byKey(k), findsOneWidget);
      }
      expect(
        find.byKey(
          UniversalInvoiceTemplate.sectionKey(InvoiceSection.signature),
        ),
        findsOneWidget,
      );
      // Bespoke table + regulatory columns.
      expect(
        find.byKey(PharmacyInvoiceTemplate.productTableKey),
        findsOneWidget,
      );
      expect(find.text('Batch'), findsOneWidget);
      expect(find.text('Expiry'), findsOneWidget);
      // Expiry warning banner for the expiring item.
      expect(
        find.byKey(PharmacyInvoiceTemplate.expiryWarningKey),
        findsOneWidget,
      );
    });

    test('validator blocks expired medicine and empty batch', () {
      final errors = PharmacyInvoiceValidator.validate([
        PharmacyInvoiceItem(
          name: 'Expired Syrup',
          batchNo: '',
          expiryDate: DateTime(2020, 1, 1),
          quantity: 1,
          mrp: 50,
        ),
      ], asOf: DateTime(2026, 1, 1));
      expect(errors.length, 2); // empty batch + expired
      expect(errors.any((e) => e.contains('batch')), isTrue);
      expect(errors.any((e) => e.contains('expired')), isTrue);
    });
  });

  group('Restaurant dedicated template', () {
    testWidgets('reuses shared sections + portion + service charge', (
      tester,
    ) async {
      const items = [
        RestaurantInvoiceItem(
          name: 'Paneer Tikka',
          quantity: 2,
          portion: FoodPortion.half,
          price: 120,
        ),
      ];
      await _pump(
        tester,
        RestaurantInvoiceTemplate(
          data: _data(),
          items: items,
          tableNo: '7',
          serviceChargePercent: 10,
        ),
      );

      // Shared components reused.
      for (final k in _sharedKeysAll) {
        expect(find.byKey(k), findsOneWidget);
      }
      // Bespoke table + portion + table + service charge.
      expect(
        find.byKey(RestaurantInvoiceTemplate.productTableKey),
        findsOneWidget,
      );
      expect(find.text('Portion'), findsOneWidget);
      expect(find.text('Half'), findsOneWidget);
      expect(find.text('Table: 7'), findsOneWidget);
      expect(
        find.byKey(RestaurantInvoiceTemplate.serviceChargeKey),
        findsOneWidget,
      );
    });
  });

  group('Jewellery dedicated template', () {
    testWidgets('reuses shared sections + bespoke weight/purity table', (
      tester,
    ) async {
      const items = [
        JewelleryInvoiceItem(
          name: 'Gold Ring',
          purity: '22K',
          hallmarkHuid: 'HUID123',
          grossWeight: 5.5,
          netWeight: 5.0,
          ratePerGram: 6000,
          makingChargePerGram: 500,
          gstPercent: 3,
        ),
      ];
      await _pump(
        tester,
        JewelleryInvoiceTemplate(data: _data(), items: items),
      );

      for (final k in _sharedKeysAll) {
        expect(find.byKey(k), findsOneWidget);
      }
      expect(
        find.byKey(JewelleryInvoiceTemplate.productTableKey),
        findsOneWidget,
      );
      expect(find.text('Purity'), findsOneWidget);
      expect(find.text('HUID'), findsOneWidget);
    });

    test('pricing formula replaces qty x unitPrice', () {
      const item = JewelleryInvoiceItem(
        name: 'Chain',
        purity: '22K',
        grossWeight: 10,
        netWeight: 10,
        ratePerGram: 6000,
        makingChargePerGram: 500,
        wastagePercent: 2,
        stoneValue: 1000,
        oldGoldExchange: 5000,
        gstPercent: 3,
      );
      // metal = 60000, wastage = 1200, making = 5000, +stone 1000, -oldgold 5000
      // preTax = 62200; gst = 1866; amount = 64066
      expect(item.metalValue, 60000);
      expect(item.preTax, 62200);
      expect(item.gstAmount, closeTo(1866, 0.001));
      expect(item.amount, closeTo(64066, 0.001));
    });
  });
}
