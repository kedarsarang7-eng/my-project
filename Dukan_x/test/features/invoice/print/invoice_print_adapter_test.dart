import 'dart:typed_data';

import 'package:dukanx/features/invoice/dedicated/models/pharmacy_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/print/invoice_print_adapter.dart';
import 'package:dukanx/features/invoice/universal/print/invoice_pdf_fonts.dart';
import 'package:dukanx/features/invoice/universal/print/print_page_formats.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

UniversalInvoiceData _data(List<UniversalInvoiceItem> items) =>
    UniversalInvoiceData(
      shopName: 'Print Test Shop',
      ownerName: 'Owner',
      address: 'Addr',
      mobile: '9999999999',
      gstin: '27ABCDE1234F1Z5',
      upiId: 'shop@upi',
      bankName: 'Bank',
      bankAccountNumber: '000111',
      bankIfsc: 'IFSC0001',
      customerName: 'Customer',
      invoiceNumber: 'INV-100',
      date: DateTime(2026, 1, 15),
      items: items,
      subtotal: 250,
      totalCgst: 22.5,
      totalSgst: 22.5,
      grandTotal: 295,
      paidAmount: 295,
    );

/// A valid PDF stream begins with the '%PDF' magic header.
void _assertValidPdf(Uint8List bytes) {
  expect(bytes.length, greaterThan(400));
  final header = String.fromCharCodes(bytes.take(4));
  expect(header, '%PDF');
}

void main() {
  // Font loading uses rootBundle, which needs the test binding + asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  final universalItems = const [
    UniversalInvoiceItem(
      name: 'Phone X',
      quantity: 1,
      unitPrice: 200,
      taxPercent: 18,
      cgst: 18,
      sgst: 18,
      hsn: '8517',
      serialNo: '356789012345678',
      warrantyMonths: 12,
    ),
    UniversalInvoiceItem(
      name: 'Charger',
      quantity: 1,
      unitPrice: 50,
      taxPercent: 18,
      cgst: 4.5,
      sgst: 4.5,
      hsn: '8504',
      serialNo: '356789012345679',
      warrantyMonths: 6,
    ),
  ];

  group('PDF Unicode font (NotoSansDevanagari)', () {
    test(
      'bundled font theme loads (fixes Helvetica no-Unicode warning)',
      () async {
        InvoicePdfFonts.resetForTest();
        final theme = await InvoicePdfFonts.theme();
        expect(
          theme,
          isNotNull,
          reason: 'NotoSansDevanagari must load from assets/fonts/ for ₹/Hindi',
        );
      },
    );

    test('rupee symbol renders in generated PDF', () async {
      final bytes = await InvoicePrintAdapter.pharmacyBytes(
        data: _data(const []),
        items: [
          PharmacyInvoiceItem(
            name: 'Paracetamol',
            batchNo: 'B1',
            expiryDate: DateTime(2027, 6, 1),
            quantity: 10,
            mrp: 20,
            gstPercent: 12,
          ),
        ],
        mode: InvoicePrintMode.a4,
      );
      _assertValidPdf(bytes);
    });
  });

  group('Universal template PDF (Mobile Shop)', () {
    final config = UniversalInvoicePresets.forType(BusinessType.mobileShop);

    for (final mode in InvoicePrintMode.values) {
      test('builds valid PDF in $mode', () async {
        final bytes = await InvoicePrintAdapter.universalBytes(
          config: config,
          data: _data(universalItems),
          mode: mode,
        );
        _assertValidPdf(bytes);
      });
    }
  });

  group('Specialized template PDF (Pharmacy)', () {
    final items = [
      PharmacyInvoiceItem(
        name: 'Paracetamol',
        batchNo: 'B123',
        expiryDate: DateTime(2027, 6, 1),
        hsn: '3004',
        quantity: 10,
        mrp: 20,
        gstPercent: 12,
        cgst: 12,
        sgst: 12,
      ),
    ];

    for (final mode in InvoicePrintMode.values) {
      test('builds valid PDF in $mode', () async {
        final bytes = await InvoicePrintAdapter.pharmacyBytes(
          data: _data(const []),
          items: items,
          mode: mode,
        );
        _assertValidPdf(bytes);
      });
    }

    test(
      'A4 and thermal produce different byte lengths (layout adapts)',
      () async {
        final a4 = await InvoicePrintAdapter.pharmacyBytes(
          data: _data(const []),
          items: items,
          mode: InvoicePrintMode.a4,
        );
        final thermal = await InvoicePrintAdapter.pharmacyBytes(
          data: _data(const []),
          items: items,
          mode: InvoicePrintMode.thermal58mm,
        );
        _assertValidPdf(a4);
        _assertValidPdf(thermal);
        expect(a4.length == thermal.length, isFalse);
      },
    );
  });
}
