import 'package:flutter/material.dart';

import '../../universal/config/invoice_section.dart';
import '../../universal/model/universal_invoice_data.dart';
import '../../universal/widgets/invoice_shared_sections.dart';
import '../../universal/widgets/universal_invoice_template.dart';
import '../models/pharmacy_invoice_item.dart';

/// Dedicated Pharmacy invoice template.
///
/// REUSES the shared section components (logo, business info, customer info,
/// tax, payment/summary, terms, signature) from [InvoiceSharedSections].
/// Only the product table (Batch + Expiry mandatory, expiry warnings) is
/// bespoke.
class PharmacyInvoiceTemplate extends StatelessWidget {
  final UniversalInvoiceData data;
  final List<PharmacyInvoiceItem> items;

  /// Items expiring within this window are flagged with a warning banner.
  final Duration expiryWarningWindow;

  const PharmacyInvoiceTemplate({
    super.key,
    required this.data,
    required this.items,
    this.expiryWarningWindow = const Duration(days: 90),
  });

  static const Key productTableKey = ValueKey('pharmacy_product_table');
  static const Key expiryWarningKey = ValueKey('pharmacy_expiry_warning');

  Widget _keyed(InvoiceSection s, Widget child) =>
      KeyedSubtree(key: UniversalInvoiceTemplate.sectionKey(s), child: child);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final flagged = items
        .where(
          (i) => i.isExpired(now) || i.expiresWithin(now, expiryWarningWindow),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── shared components (reused, not copied) ──
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

          if (flagged.isNotEmpty) ...[
            _expiryWarning(context, flagged, now),
            const SizedBox(height: 12),
          ],

          // ── bespoke product table ──
          _productTable(context),
          const SizedBox(height: 12),

          _keyed(InvoiceSection.tax, InvoiceSharedSections.tax(context, data)),
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

  Widget _expiryWarning(
    BuildContext c,
    List<PharmacyInvoiceItem> flagged,
    DateTime now,
  ) {
    return Container(
      key: expiryWarningKey,
      padding: const EdgeInsets.all(8),
      color: Colors.amber.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚠ Expiry Alert', style: InvoiceSharedSections.bold(c)),
          ...flagged.map(
            (i) => Text(
              '${i.name} (Batch ${i.batchNo}) — '
              '${i.isExpired(now) ? 'EXPIRED' : 'expires'} '
              '${InvoiceSharedSections.date(i.expiryDate)}',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTable(BuildContext c) {
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
              Expanded(child: Text(items[i].batchNo)),
              Expanded(
                child: Text(InvoiceSharedSections.date(items[i].expiryDate)),
              ),
              Expanded(child: Text(items[i].hsn ?? '-')),
              Expanded(child: Text(items[i].quantity.toStringAsFixed(0))),
              Expanded(child: Text(InvoiceSharedSections.money(items[i].mrp))),
              Expanded(
                child: Text('${items[i].gstPercent.toStringAsFixed(0)}%'),
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
