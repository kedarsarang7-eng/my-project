import 'package:flutter/material.dart';

import '../config/invoice_layout_config.dart';
import '../config/invoice_section.dart';
import '../config/invoice_section_config.dart';
import '../model/universal_invoice_data.dart';
import 'invoice_shared_sections.dart';

/// Config-driven universal invoice widget.
///
/// The widget tree contains ZERO business-type conditionals. It iterates the
/// [InvoiceLayoutConfig.renderableSections] and dispatches each section to a
/// renderer via a registry keyed by [InvoiceSection]. Shared sections delegate
/// to [InvoiceSharedSections] (the same components the dedicated templates
/// reuse). Only the config-driven product table is defined locally.
class UniversalInvoiceTemplate extends StatelessWidget {
  final InvoiceLayoutConfig config;
  final UniversalInvoiceData data;

  const UniversalInvoiceTemplate({
    super.key,
    required this.config,
    required this.data,
  });

  /// Test/preview helper: the ValueKey used for a rendered section block.
  static Key sectionKey(InvoiceSection s) => ValueKey('section_${s.name}');

  /// Test/preview helper: the ValueKey used for a product-table column header.
  static Key columnKey(String fieldKey) => ValueKey('col_$fieldKey');

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (final section in config.renderableSections) {
      final builder = _renderers[section.section];
      if (builder == null) continue; // unknown section: skip safely
      blocks.add(
        KeyedSubtree(
          key: sectionKey(section.section),
          child: builder(context, data, section),
        ),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _withSpacing(blocks),
      ),
    );

    final watermark = config.sectionFor(InvoiceSection.watermark);
    if (watermark != null && watermark.shouldRender) {
      return Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: InvoiceSharedSections.watermark(context, data),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  static List<Widget> _withSpacing(List<Widget> blocks) {
    if (blocks.isEmpty) return blocks;
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      out.add(blocks[i]);
      if (i != blocks.length - 1) out.add(const SizedBox(height: 12));
    }
    return out;
  }

  // ── Renderer registry: section -> builder. No BusinessType anywhere. ──
  // Shared sections delegate to InvoiceSharedSections; only productTable is
  // config-column-driven and therefore local to the universal engine.
  static final Map<
    InvoiceSection,
    Widget Function(BuildContext, UniversalInvoiceData, InvoiceSectionConfig)
  >
  _renderers = {
    InvoiceSection.logo: (c, d, s) => InvoiceSharedSections.logo(c, d),
    InvoiceSection.businessInfo: (c, d, s) =>
        InvoiceSharedSections.businessInfo(c, d),
    InvoiceSection.customerInfo: (c, d, s) =>
        InvoiceSharedSections.customerInfo(c, d),
    InvoiceSection.shipping: (c, d, s) => InvoiceSharedSections.shipping(c, d),
    InvoiceSection.productTable: _productTable,
    InvoiceSection.tax: (c, d, s) => InvoiceSharedSections.tax(c, d),
    InvoiceSection.discount: (c, d, s) => InvoiceSharedSections.discount(c, d),
    InvoiceSection.payment: (c, d, s) => InvoiceSharedSections.payment(c, d),
    InvoiceSection.bankDetails: (c, d, s) =>
        InvoiceSharedSections.bankDetails(c, d),
    InvoiceSection.warranty: (c, d, s) => InvoiceSharedSections.warranty(c, d),
    InvoiceSection.serialImei: (c, d, s) =>
        InvoiceSharedSections.serialImei(c, d),
    InvoiceSection.notes: (c, d, s) => InvoiceSharedSections.notes(c, d),
    InvoiceSection.terms: (c, d, s) => InvoiceSharedSections.terms(c, d),
    InvoiceSection.qr: (c, d, s) => InvoiceSharedSections.qr(c, d),
    InvoiceSection.signature: (c, d, s) =>
        InvoiceSharedSections.signature(c, d),
  };

  /// Config-driven product table: columns come entirely from the section's
  /// visible fields. This is the ONE piece unique to the universal engine.
  static Widget _productTable(
    BuildContext c,
    UniversalInvoiceData d,
    InvoiceSectionConfig s,
  ) {
    final cols = s.visibleFields;
    final headerCells = cols
        .map(
          (f) => Expanded(
            flex: _flexFor(f.key),
            child: Container(
              key: columnKey(f.key),
              padding: const EdgeInsets.all(4),
              child: Text(
                f.label,
                style: InvoiceSharedSections.bold(c),
                textAlign: _alignFor(f.key),
              ),
            ),
          ),
        )
        .toList();

    final rows = <Widget>[];
    for (var i = 0; i < d.items.length; i++) {
      final item = d.items[i];
      rows.add(
        Row(
          children: cols.map((f) {
            final value = f.key == 'sno' ? '${i + 1}' : item.cell(f.key);
            return Expanded(
              flex: _flexFor(f.key),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(value, textAlign: _alignForData(f.key)),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          child: Row(children: headerCells),
        ),
        const Divider(height: 1),
        ...rows,
        const Divider(),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Subtotal: ${InvoiceSharedSections.money(d.subtotal)}'),
        ),
      ],
    );
  }

  static int _flexFor(String key) {
    switch (key) {
      case 'sno':
        return 1;
      case 'name':
        return 4;
      case 'serialNo':
      case 'imei':
        return 3;
      case 'amount':
      case 'total':
        return 2;
      default:
        return 2;
    }
  }

  static TextAlign _alignFor(String key) =>
      key == 'name' || key == 'sno' ? TextAlign.left : TextAlign.right;

  static TextAlign _alignForData(String key) =>
      key == 'name' ? TextAlign.left : TextAlign.center;
}
