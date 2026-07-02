import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../models/business_type.dart';
import '../../dedicated/models/pharmacy_invoice_item.dart';
import '../config/invoice_layout_config.dart';
import '../config/invoice_section.dart';
import '../config/invoice_section_config.dart';
import '../model/universal_invoice_data.dart';
import 'config_invoice_pdf_builder.dart';
import 'invoice_pdf_fonts.dart';
import 'invoice_pdf_sections.dart';
import 'print_page_formats.dart';

/// Print adapter for the config-driven invoice engine.
///
/// Produces PDF bytes for A4 / thermal-80mm / thermal-58mm and drives the OS
/// print/preview dialog via the existing `printing` package. The existing
/// legacy PDF services are left untouched so a feature-flag rollback reverts to
/// them instantly.
class InvoicePrintAdapter {
  /// Universal-template PDF bytes (any of the 9 universal business types).
  static Future<Uint8List> universalBytes({
    required InvoiceLayoutConfig config,
    required UniversalInvoiceData data,
    required InvoicePrintMode mode,
  }) async {
    final theme = await InvoicePdfFonts.theme();
    return ConfigInvoicePdfBuilder.build(
      config: config,
      data: data,
      mode: mode,
      theme: theme,
    ).save();
  }

  /// Dedicated Pharmacy PDF bytes. Reuses every shared PDF section and only
  /// supplies the bespoke Batch/Expiry product table.
  static Future<Uint8List> pharmacyBytes({
    required UniversalInvoiceData data,
    required List<PharmacyInvoiceItem> items,
    required InvoicePrintMode mode,
  }) async {
    final theme = await InvoicePdfFonts.theme();
    final doc = ConfigInvoicePdfBuilder.build(
      config: _pharmacyLayout(),
      data: data,
      mode: mode,
      theme: theme,
      productTableBuilder: (compact) => _pharmacyTable(items, compact),
    );
    return doc.save();
  }

  /// Open the OS print/preview dialog for [bytes] (runtime only).
  static Future<void> preview({
    required Uint8List bytes,
    required String filename,
  }) {
    return Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
  }

  // ── dedicated pharmacy layout (section order) reusing shared sections ──
  static InvoiceLayoutConfig _pharmacyLayout() {
    return const InvoiceLayoutConfig(
      businessType: BusinessType.pharmacy,
      sections: [
        InvoiceSectionConfig(
          section: InvoiceSection.businessInfo,
          order: 0,
          required: true,
          editable: false,
        ),
        InvoiceSectionConfig(section: InvoiceSection.customerInfo, order: 1),
        InvoiceSectionConfig(
          section: InvoiceSection.productTable,
          order: 2,
          required: true,
          editable: false,
        ),
        InvoiceSectionConfig(
          section: InvoiceSection.tax,
          order: 3,
          required: true,
          editable: false,
        ),
        InvoiceSectionConfig(section: InvoiceSection.payment, order: 4),
        InvoiceSectionConfig(section: InvoiceSection.terms, order: 5),
        InvoiceSectionConfig(section: InvoiceSection.signature, order: 6),
      ],
    );
  }

  static pw.Widget _pharmacyTable(
    List<PharmacyInvoiceItem> items,
    bool compact,
  ) {
    const headers = [
      '#',
      'Medicine',
      'Batch',
      'Expiry',
      'HSN',
      'Qty',
      'MRP',
      'GST%',
      'Amount',
    ];
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      rows.add([
        '${i + 1}',
        it.name,
        it.batchNo,
        InvoicePdfSections.date(it.expiryDate),
        it.hsn ?? '-',
        it.quantity.toStringAsFixed(0),
        InvoicePdfSections.money(it.mrp),
        '${it.gstPercent.toStringAsFixed(0)}%',
        InvoicePdfSections.money(it.amount),
      ]);
    }
    return compact
        ? InvoicePdfSections.compactTable(headers: headers, rows: rows)
        : InvoicePdfSections.table(headers: headers, rows: rows);
  }
}
