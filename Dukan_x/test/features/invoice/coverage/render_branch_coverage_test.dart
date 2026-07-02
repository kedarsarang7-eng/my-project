import 'dart:convert';
import 'dart:typed_data';

import 'package:dukanx/features/invoice/universal/config/invoice_field_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section_config.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/print/config_invoice_pdf_builder.dart';
import 'package:dukanx/features/invoice/universal/print/invoice_pdf_fonts.dart';
import 'package:dukanx/features/invoice/universal/print/invoice_print_adapter.dart';
import 'package:dukanx/features/invoice/universal/print/print_page_formats.dart';
import 'package:dukanx/features/invoice/universal/settings/invoice_sections_settings_panel.dart';
import 'package:dukanx/features/invoice/universal/widgets/universal_invoice_template.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1x1 transparent PNG for image branches.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// A config with ALL 16 sections enabled + visible (incl. watermark) to force
/// every section renderer + the watermark overlay path to execute.
InvoiceLayoutConfig _allSectionsConfig() {
  final all = InvoiceSection.values;
  return InvoiceLayoutConfig(
    businessType: BusinessType.other,
    sections: [
      for (var i = 0; i < all.length; i++)
        InvoiceSectionConfig(
          section: all[i],
          order: i,
          fields: all[i] == InvoiceSection.productTable
              ? const [
                  InvoiceFieldConfig(key: 'sno', label: '#'),
                  InvoiceFieldConfig(key: 'name', label: 'Item'),
                  InvoiceFieldConfig(key: 'serialNo', label: 'Serial'),
                  InvoiceFieldConfig(key: 'warranty', label: 'Warranty'),
                  InvoiceFieldConfig(key: 'hsn', label: 'HSN'),
                  InvoiceFieldConfig(key: 'qty', label: 'Qty'),
                  InvoiceFieldConfig(key: 'rate', label: 'Rate'),
                  InvoiceFieldConfig(key: 'amount', label: 'Amount'),
                ]
              : const [],
        ),
    ],
  );
}

UniversalInvoiceData _fullData() => UniversalInvoiceData(
  shopName: 'Full Shop',
  ownerName: 'Owner',
  address: 'Addr',
  mobile: '9999999999',
  gstin: '27ABCDE1234F1Z5',
  tagline: 'Best shop',
  upiId: 'full@upi',
  drugLicenseNumber: 'DL-1',
  bankName: 'Bank',
  bankAccountNumber: '111',
  bankIfsc: 'IFSC1',
  logoImage: _png,
  signatureImage: _png,
  customerName: 'Cust',
  customerMobile: '8888888888',
  customerAddress: 'Cust Addr',
  customerGstin: '27ZZZZZ1234Z1Z9',
  shippingAddress: 'Ship Addr',
  transportDetails: 'By road',
  invoiceNumber: 'INV-F',
  date: DateTime(2026, 1, 1),
  items: const [
    UniversalInvoiceItem(
      name: 'Phone',
      quantity: 1,
      unitPrice: 200,
      taxPercent: 18,
      igst: 36,
      hsn: '8517',
      serialNo: 'SN',
      warrantyMonths: 12,
    ),
  ],
  subtotal: 200,
  totalDiscount: 20,
  totalIgst: 36,
  grandTotal: 216,
  isInterState: true,
  paymentMode: 'UPI',
  paidAmount: 216,
  notes: 'Handle with care',
  terms: 'Custom terms',
  warrantyTerms: 'Custom warranty',
  watermarkText: 'PAID',
);

UniversalInvoiceData _emptyData() => UniversalInvoiceData(
  shopName: 'Bare',
  ownerName: 'O',
  address: 'A',
  mobile: 'M',
  customerName: '',
  invoiceNumber: 'INV-E',
  date: DateTime(2026, 1, 1),
  items: const [UniversalInvoiceItem(name: 'X', quantity: 1, unitPrice: 10)],
  grandTotal: 10,
  isInterState: false,
  totalDiscount: 0,
);

Future<void> _pump(WidgetTester tester, UniversalInvoiceData data) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UniversalInvoiceTemplate(
          config: _allSectionsConfig(),
          data: data,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('widget: all sections + images + watermark (full data)', (
    tester,
  ) async {
    await _pump(tester, _fullData());
    expect(find.byType(UniversalInvoiceTemplate), findsOneWidget);
    // Watermark overlay present.
    expect(find.text('PAID'), findsOneWidget);
    // Interstate => IGST label shown.
    expect(find.textContaining('IGST'), findsWidgets);
  });

  testWidgets('widget: all sections, empty optionals (else branches)', (
    tester,
  ) async {
    await _pump(tester, _emptyData());
    expect(find.byType(UniversalInvoiceTemplate), findsOneWidget);
    // No images => default watermark text + intra-state CGST/SGST.
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.textContaining('CGST'), findsWidgets);
  });

  group('PDF branches (full + empty) x (A4 + thermal)', () {
    for (final data in [true, false]) {
      for (final mode in InvoicePrintMode.values) {
        test('build ${data ? "full" : "empty"} in $mode', () async {
          final theme = await InvoicePdfFonts.theme();
          final doc = ConfigInvoicePdfBuilder.build(
            config: _allSectionsConfig(),
            data: data ? _fullData() : _emptyData(),
            mode: mode,
            theme: theme,
          );
          final bytes = await doc.save();
          expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        });
      }
    }
  });

  test('preview() executes the platform print path', () async {
    final bytes = await InvoicePrintAdapter.universalBytes(
      config: UniversalInvoicePresets.forType(BusinessType.grocery),
      data: _emptyData(),
      mode: InvoicePrintMode.a4,
    );
    // In a headless test the platform channel is unavailable; we only need the
    // preview() body to execute (it constructs/awaits the platform call).
    try {
      await InvoicePrintAdapter.preview(bytes: bytes, filename: 'x.pdf');
    } catch (_) {
      // expected: no printing plugin in test environment
    }
  });

  group('Settings panel — reorder + business-specific subtitle', () {
    testWidgets('onReorder handler runs; locked vs editable toggles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      InvoiceLayoutConfig? emitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoiceSectionsSettingsPanel(
              // mobileShop has business-specific serialImei/warranty rows.
              initialConfig: UniversalInvoicePresets.forType(
                BusinessType.mobileShop,
              ),
              previewData: _emptyData(),
              onChanged: (c) => emitted = c,
            ),
          ),
        ),
      );

      // Business-specific subtitle rendered.
      expect(find.text('Business-specific'), findsWidgets);
      // Locked subtitle rendered for required businessInfo.
      expect(find.text('Locked (required)'), findsWidgets);

      // Invoke the reorder callback directly (covers _reorder).
      final rlv = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      rlv.onReorder!(0, 3);
      await tester.pumpAndSettle();
      expect(emitted, isNotNull);
    });
  });
}
