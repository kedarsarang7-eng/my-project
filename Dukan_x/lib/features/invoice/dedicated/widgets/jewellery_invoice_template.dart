import 'package:flutter/material.dart';

import '../../universal/config/invoice_section.dart';
import '../../universal/model/universal_invoice_data.dart';
import '../../universal/widgets/invoice_shared_sections.dart';
import '../../universal/widgets/universal_invoice_template.dart';
import '../models/jewellery_invoice_item.dart';

/// Dedicated Jewellery invoice template.
///
/// REUSES the shared section components (logo, business info, customer info,
/// payment/summary, terms, signature) from [InvoiceSharedSections]. Only the
/// product table (purity/hallmark, weight x rate + making + wastage + stone -
/// old-gold) is bespoke, because the pricing formula replaces qty x unitPrice.
class JewelleryInvoiceTemplate extends StatelessWidget {
  final UniversalInvoiceData data;
  final List<JewelleryInvoiceItem> items;

  const JewelleryInvoiceTemplate({
    super.key,
    required this.data,
    required this.items,
  });

  static const Key productTableKey = ValueKey('jewellery_product_table');

  Widget _keyed(InvoiceSection s, Widget child) =>
      KeyedSubtree(key: UniversalInvoiceTemplate.sectionKey(s), child: child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _keyed(
            InvoiceSection.logo,
            InvoiceSharedSections.logo(context, data),
          ),
          const SizedBox(height: 12),
          _keyed(
            InvoiceSection.businessInfo,
            InvoiceSharedSections.businessInfo(context, data),
          ),
          const SizedBox(height: 12),
          _keyed(
            InvoiceSection.customerInfo,
            InvoiceSharedSections.customerInfo(context, data),
          ),
          const SizedBox(height: 12),

          // ── bespoke product table ──
          _productTable(context),
          const SizedBox(height: 12),

          _keyed(
            InvoiceSection.payment,
            InvoiceSharedSections.payment(context, data),
          ),
          const SizedBox(height: 12),
          _keyed(
            InvoiceSection.terms,
            InvoiceSharedSections.terms(context, data),
          ),
          const SizedBox(height: 12),
          _keyed(
            InvoiceSection.signature,
            InvoiceSharedSections.signature(context, data),
          ),
        ],
      ),
    );
  }

  Widget _productTable(BuildContext c) {
    const headers = [
      '#',
      'Item',
      'Purity',
      'HUID',
      'Gross(g)',
      'Net(g)',
      'Rate/g',
      'Making',
      'Amount',
    ];
    return Column(
      key: productTableKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          child: Row(
            children: headers
                .map(
                  (h) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(h, style: InvoiceSharedSections.bold(c)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        for (var i = 0; i < items.length; i++)
          Row(
            children: [
              Expanded(child: Text('${i + 1}')),
              Expanded(child: Text(items[i].name)),
              Expanded(child: Text(items[i].purity)),
              Expanded(child: Text(items[i].hallmarkHuid ?? '-')),
              Expanded(child: Text(items[i].grossWeight.toStringAsFixed(3))),
              Expanded(child: Text(items[i].netWeight.toStringAsFixed(3))),
              Expanded(
                child: Text(InvoiceSharedSections.money(items[i].ratePerGram)),
              ),
              Expanded(
                child: Text(
                  InvoiceSharedSections.money(items[i].makingCharges),
                ),
              ),
              Expanded(
                child: Text(InvoiceSharedSections.money(items[i].amount)),
              ),
            ],
          ),
      ],
    );
  }
}
