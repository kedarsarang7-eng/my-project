import 'package:pdf/widgets.dart' as pw;

import '../config/invoice_layout_config.dart';
import '../config/invoice_section.dart';
import '../model/universal_invoice_data.dart';
import 'invoice_pdf_sections.dart';
import 'print_page_formats.dart';

/// Builds a printable [pw.Document] from an [InvoiceLayoutConfig] +
/// [UniversalInvoiceData]. Sections are dispatched via a registry keyed by
/// [InvoiceSection] — ZERO business-type conditionals, exactly like the
/// on-screen engine. Dedicated templates supply a [productTableBuilder] to
/// inject their bespoke table while reusing every other shared PDF section.
class ConfigInvoicePdfBuilder {
  static pw.Document build({
    required InvoiceLayoutConfig config,
    required UniversalInvoiceData data,
    required InvoicePrintMode mode,
    pw.Widget Function(bool compact)? productTableBuilder,
    pw.ThemeData? theme,
  }) {
    final compact = InvoicePageFormats.isCompact(mode);
    final pageFormat = InvoicePageFormats.forMode(mode);

    final blocks = <pw.Widget>[];
    for (final section in config.renderableSections) {
      final widget = _renderSection(
        section.section,
        data,
        config,
        compact,
        productTableBuilder,
      );
      if (widget == null) continue;
      blocks.add(widget);
      blocks.add(pw.SizedBox(height: compact ? 4 : 8));
    }

    final doc = pw.Document(theme: theme);
    if (mode == InvoicePrintMode.a4) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          theme: theme,
          build: (_) => blocks,
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: blocks,
          ),
        ),
      );
    }
    return doc;
  }

  static pw.Widget? _renderSection(
    InvoiceSection section,
    UniversalInvoiceData d,
    InvoiceLayoutConfig config,
    bool compact,
    pw.Widget Function(bool compact)? productTableBuilder,
  ) {
    switch (section) {
      case InvoiceSection.logo:
        return null; // shop name rendered in businessInfo; no asset in PDF path
      case InvoiceSection.watermark:
        return null; // overlay handled separately if needed
      case InvoiceSection.businessInfo:
        return InvoicePdfSections.businessInfo(d);
      case InvoiceSection.customerInfo:
        return InvoicePdfSections.customerInfo(d);
      case InvoiceSection.shipping:
        return InvoicePdfSections.shipping(d);
      case InvoiceSection.productTable:
        return productTableBuilder != null
            ? productTableBuilder(compact)
            : _universalTable(config, d, compact);
      case InvoiceSection.tax:
        return InvoicePdfSections.tax(d);
      case InvoiceSection.discount:
        return InvoicePdfSections.discount(d);
      case InvoiceSection.payment:
        return InvoicePdfSections.payment(d);
      case InvoiceSection.bankDetails:
        return InvoicePdfSections.bankDetails(d);
      case InvoiceSection.warranty:
        return InvoicePdfSections.warranty(d);
      case InvoiceSection.serialImei:
        return InvoicePdfSections.serialImei(d);
      case InvoiceSection.notes:
        return InvoicePdfSections.notes(d);
      case InvoiceSection.terms:
        return InvoicePdfSections.terms(d);
      case InvoiceSection.qr:
        return InvoicePdfSections.qr(d);
      case InvoiceSection.signature:
        return InvoicePdfSections.signature(d);
    }
  }

  /// Config-driven universal product table: columns are the section's visible
  /// fields; values come from [UniversalInvoiceItem.cell].
  static pw.Widget _universalTable(
    InvoiceLayoutConfig config,
    UniversalInvoiceData d,
    bool compact,
  ) {
    final cfg = config.sectionFor(InvoiceSection.productTable);
    final fields = cfg?.visibleFields ?? const [];
    final headers = fields.map((f) => f.label).toList();
    final rows = <List<String>>[];
    for (var i = 0; i < d.items.length; i++) {
      rows.add(
        fields
            .map(
              (f) => f.key == 'sno'
                  ? '${i + 1}'
                  : d.items[i].cell(f.key, currency: '\u20B9'),
            )
            .toList(),
      );
    }
    return compact
        ? InvoicePdfSections.compactTable(headers: headers, rows: rows)
        : InvoicePdfSections.table(headers: headers, rows: rows);
  }
}
