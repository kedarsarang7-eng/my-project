import 'package:dukanx/features/invoice/universal/config/invoice_layout_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/settings/invoice_sections_settings_panel.dart';
import 'package:dukanx/features/invoice/universal/widgets/universal_invoice_template.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UniversalInvoiceData data() => UniversalInvoiceData(
    shopName: 'Panel Shop',
    ownerName: 'Owner',
    address: 'Addr',
    mobile: '9999999999',
    customerName: 'Customer',
    invoiceNumber: 'INV-1',
    date: DateTime(2026, 1, 1),
    items: const [
      UniversalInvoiceItem(name: 'Rice', quantity: 2, unitPrice: 50),
    ],
    subtotal: 100,
    grandTotal: 100,
  );

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<InvoiceLayoutConfig>? onChanged,
  }) async {
    // Tall surface so the lazily-built ReorderableListView builds all rows.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceSectionsSettingsPanel(
            initialConfig: UniversalInvoicePresets.forType(
              BusinessType.grocery,
            ),
            previewData: data(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('toggling a section updates the live preview in real time', (
    tester,
  ) async {
    await pump(tester);

    // Terms is initially visible in the live preview.
    expect(
      find.byKey(UniversalInvoiceTemplate.sectionKey(InvoiceSection.terms)),
      findsOneWidget,
    );

    // Toggle Terms OFF via its row switch.
    await tester.tap(
      find.byKey(InvoiceSectionsSettingsPanel.rowKey(InvoiceSection.terms)),
    );
    await tester.pumpAndSettle();

    // Live preview no longer renders Terms — updated in real time.
    expect(
      find.byKey(UniversalInvoiceTemplate.sectionKey(InvoiceSection.terms)),
      findsNothing,
    );
  });

  testWidgets('locked (required) sections cannot be toggled off', (
    tester,
  ) async {
    await pump(tester);

    // Business Info is required/locked (editable:false) => stays in preview.
    expect(
      find.byKey(
        UniversalInvoiceTemplate.sectionKey(InvoiceSection.businessInfo),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        InvoiceSectionsSettingsPanel.rowKey(InvoiceSection.businessInfo),
      ),
    );
    await tester.pumpAndSettle();
    // Still present — locked switch ignored the tap.
    expect(
      find.byKey(
        UniversalInvoiceTemplate.sectionKey(InvoiceSection.businessInfo),
      ),
      findsOneWidget,
    );
  });

  testWidgets('onChanged fires with updated config when toggling', (
    tester,
  ) async {
    InvoiceLayoutConfig? emitted;
    await pump(tester, onChanged: (c) => emitted = c);

    await tester.tap(
      find.byKey(InvoiceSectionsSettingsPanel.rowKey(InvoiceSection.qr)),
    );
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    final qr = emitted!.sectionFor(InvoiceSection.qr);
    expect(qr!.visible, isFalse);
  });
}
