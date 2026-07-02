import 'dart:typed_data';

import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/migration/invoice_layout_migration.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/print/invoice_print_adapter.dart';
import 'package:dukanx/features/invoice/universal/print/print_page_formats.dart';
import 'package:dukanx/features/invoice/universal/widgets/universal_invoice_template.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end: create invoice -> render on screen -> generate PDF -> save the
/// tenant layout config. Exercises Phases 2, 5 and 7 together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UniversalInvoiceData buildInvoice() => UniversalInvoiceData(
    shopName: 'Flow Shop',
    ownerName: 'Owner',
    address: 'Addr',
    mobile: '9999999999',
    gstin: '27ABCDE1234F1Z5',
    upiId: 'flow@upi',
    customerName: 'Customer',
    invoiceNumber: 'INV-FLOW-1',
    date: DateTime(2026, 1, 15),
    items: const [
      UniversalInvoiceItem(
        name: 'Phone',
        quantity: 1,
        unitPrice: 200,
        taxPercent: 18,
        cgst: 18,
        sgst: 18,
        hsn: '8517',
        serialNo: '356789012345678',
        warrantyMonths: 12,
      ),
    ],
    subtotal: 200,
    totalCgst: 18,
    totalSgst: 18,
    grandTotal: 236,
    paidAmount: 236,
  );

  testWidgets('create -> render -> print -> save', (tester) async {
    // 1. CREATE
    final config = UniversalInvoicePresets.forType(BusinessType.mobileShop);
    final data = buildInvoice();

    // 2. RENDER on screen
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 800,
              child: UniversalInvoiceTemplate(config: config, data: data),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(UniversalInvoiceTemplate), findsOneWidget);
    expect(
      find.byKey(
        UniversalInvoiceTemplate.sectionKey(InvoiceSection.productTable),
      ),
      findsOneWidget,
    );

    // 3. PRINT (PDF bytes for A4 + thermal)
    final Uint8List a4 = await InvoicePrintAdapter.universalBytes(
      config: config,
      data: data,
      mode: InvoicePrintMode.a4,
    );
    final Uint8List thermal = await InvoicePrintAdapter.universalBytes(
      config: config,
      data: data,
      mode: InvoicePrintMode.thermal80mm,
    );
    expect(String.fromCharCodes(a4.take(4)), '%PDF');
    expect(String.fromCharCodes(thermal.take(4)), '%PDF');

    // 4. SAVE tenant layout config (additive persistence)
    final store = InMemoryLayoutConfigStore();
    const migration = InvoiceLayoutMigration();
    final report = migration.migrate([
      MigrationRecord(
        invoiceId: data.invoiceNumber,
        businessType: BusinessType.mobileShop,
        sourceItemCount: data.items.length,
        sourceGrandTotal: data.grandTotal,
        data: data,
      ),
    ], store);

    expect(report.isLossless, isTrue);
    expect(store.has(BusinessType.mobileShop), isTrue);
  });
}
