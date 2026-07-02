import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/widgets/universal_invoice_template.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample invoice data used across the 3 pilot business types.
UniversalInvoiceData _sampleData() => UniversalInvoiceData(
  shopName: 'Test Shop',
  ownerName: 'Owner',
  address: '123 Main Rd',
  mobile: '9999999999',
  gstin: '27ABCDE1234F1Z5',
  upiId: 'test@upi',
  bankName: 'Test Bank',
  bankAccountNumber: '000111222333',
  bankIfsc: 'TEST0001234',
  customerName: 'Customer A',
  customerMobile: '8888888888',
  customerAddress: 'Cust Addr',
  shippingAddress: 'Ship Addr',
  invoiceNumber: 'INV-001',
  date: DateTime(2026, 1, 15),
  items: const [
    UniversalInvoiceItem(
      name: 'Item One',
      quantity: 2,
      unit: 'pcs',
      unitPrice: 100,
      taxPercent: 18,
      cgst: 18,
      sgst: 18,
      hsn: '8517',
      serialNo: '356789012345678',
      warrantyMonths: 12,
    ),
    UniversalInvoiceItem(
      name: 'Item Two',
      quantity: 1,
      unit: 'pcs',
      unitPrice: 50,
      taxPercent: 18,
      cgst: 4.5,
      sgst: 4.5,
      hsn: '8517',
      serialNo: '356789012345679',
      warrantyMonths: 24,
    ),
  ],
  subtotal: 250,
  totalDiscount: 0,
  totalCgst: 22.5,
  totalSgst: 22.5,
  grandTotal: 295,
  paymentMode: 'UPI',
  paidAmount: 295,
  dueAmount: 0,
);

Future<void> _pump(WidgetTester tester, InvoiceLayoutConfig config) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 800,
            child: UniversalInvoiceTemplate(
              config: config,
              data: _sampleData(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Universal engine — one template, config-driven', () {
    testWidgets(
      'Grocery: simple retail, NO IMEI/serial column, NO bank/serial sections',
      (tester) async {
        await _pump(
          tester,
          UniversalInvoicePresets.forType(BusinessType.grocery),
        );

        // Core sections present.
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.productTable),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.payment),
          ),
          findsOneWidget,
        );

        // No IMEI/serial column for grocery.
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
          findsNothing,
        );
        // HSN column disabled-by-visibility for grocery (togglable Phase 6).
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('hsn')),
          findsNothing,
        );

        // Bank details + serialImei sections not rendered (disabled).
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.bankDetails),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.serialImei),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Mobile Shop: IMEI column + serialImei + warranty + tax sections',
      (tester) async {
        await _pump(
          tester,
          UniversalInvoicePresets.forType(BusinessType.mobileShop),
        );

        // IMEI column present (key = serialNo, label 'IMEI').
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
          findsOneWidget,
        );
        expect(find.text('IMEI'), findsOneWidget);
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('warranty')),
          findsOneWidget,
        );

        // Business-specific sections rendered.
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.serialImei),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.warranty),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(UniversalInvoiceTemplate.sectionKey(InvoiceSection.tax)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Wholesale: shipping + bank details + HSN column, NO serial/warranty',
      (tester) async {
        await _pump(
          tester,
          UniversalInvoicePresets.forType(BusinessType.wholesale),
        );

        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.shipping),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.bankDetails),
          ),
          findsOneWidget,
        );
        // HSN column visible (required for B2B wholesale).
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('hsn')),
          findsOneWidget,
        );

        // No serial/IMEI column or warranty section for wholesale.
        expect(
          find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
          findsNothing,
        );
        expect(
          find.byKey(
            UniversalInvoiceTemplate.sectionKey(InvoiceSection.warranty),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'SAME widget type renders ALL 9 universal types (one template file)',
      (tester) async {
        for (final type in UniversalInvoicePresets.wiredTypes) {
          await _pump(tester, UniversalInvoicePresets.forType(type));
          expect(
            find.byType(UniversalInvoiceTemplate),
            findsOneWidget,
            reason: '${type.name} should render via the one universal template',
          );
          // Every universal invoice must at least render the product table.
          expect(
            find.byKey(
              UniversalInvoiceTemplate.sectionKey(InvoiceSection.productTable),
            ),
            findsOneWidget,
            reason: '${type.name} must render a product table',
          );
        }
      },
    );

    testWidgets('Phase 3 per-type column differences are config-driven', (
      tester,
    ) async {
      // Clothing => Size/Color columns, no serial.
      await _pump(
        tester,
        UniversalInvoicePresets.forType(BusinessType.clothing),
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('size')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('color')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
        findsNothing,
      );

      // Book Store => ISBN column, tax hidden.
      await _pump(
        tester,
        UniversalInvoicePresets.forType(BusinessType.bookStore),
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('isbn')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.sectionKey(InvoiceSection.tax)),
        findsNothing,
      );

      // Auto Parts => Part No + warranty column, no serial/IMEI column.
      await _pump(
        tester,
        UniversalInvoicePresets.forType(BusinessType.autoParts),
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('partNumber')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('warranty')),
        findsOneWidget,
      );

      // Computer Store => Serial + warranty(required) columns.
      await _pump(
        tester,
        UniversalInvoicePresets.forType(BusinessType.computerShop),
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
        findsOneWidget,
      );
      expect(find.text('Serial No'), findsOneWidget);

      // Hardware => HSN + Unit columns, no serial/warranty.
      await _pump(
        tester,
        UniversalInvoicePresets.forType(BusinessType.hardware),
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('hsn')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('unit')),
        findsOneWidget,
      );
      expect(
        find.byKey(UniversalInvoiceTemplate.columnKey('serialNo')),
        findsNothing,
      );
    });
  });

  group('Phase 3 scope guards', () {
    test('All 9 universal types are wired', () {
      expect(UniversalInvoicePresets.wiredTypes.length, 9);
      expect(UniversalInvoicePresets.wiredTypes, {
        BusinessType.grocery,
        BusinessType.mobileShop,
        BusinessType.wholesale,
        BusinessType.computerShop,
        BusinessType.electronics,
        BusinessType.bookStore,
        BusinessType.clothing,
        BusinessType.autoParts,
        BusinessType.hardware,
      });
    });

    test('Dedicated-template types remain UNwired in the universal engine', () {
      for (final type in [
        BusinessType.pharmacy,
        BusinessType.restaurant,
        BusinessType.jewellery,
      ]) {
        expect(
          () => UniversalInvoicePresets.forType(type),
          throwsUnimplementedError,
          reason: '${type.name} is a Phase 4 dedicated template',
        );
      }
    });

    test(
      'renderableSections excludes disabled/invisible sections and is ordered',
      () {
        final cfg = UniversalInvoicePresets.forType(BusinessType.grocery);
        final rendered = cfg.renderableSections;
        // bankDetails is disabled for grocery -> excluded.
        expect(
          rendered.any((s) => s.section == InvoiceSection.bankDetails),
          isFalse,
        );
        // Ordered ascending by `order`.
        for (var i = 1; i < rendered.length; i++) {
          expect(rendered[i].order >= rendered[i - 1].order, isTrue);
        }
      },
    );
  });
}
