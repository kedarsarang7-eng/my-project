import 'package:flutter/material.dart';

import '../../universal/config/invoice_section.dart';
import '../../universal/model/universal_invoice_data.dart';
import '../../universal/widgets/invoice_shared_sections.dart';
import '../../universal/widgets/universal_invoice_template.dart';
import '../models/restaurant_invoice_item.dart';

/// Dedicated Restaurant invoice template.
///
/// REUSES the shared section components (logo, business info, customer info,
/// payment/summary, terms) from [InvoiceSharedSections]. Only the product
/// table (portion type, table binding) and the service-charge line are bespoke.
class RestaurantInvoiceTemplate extends StatelessWidget {
  final UniversalInvoiceData data;
  final List<RestaurantInvoiceItem> items;
  final String? tableNo;
  final double serviceChargePercent;

  const RestaurantInvoiceTemplate({
    super.key,
    required this.data,
    required this.items,
    this.tableNo,
    this.serviceChargePercent = 0,
  });

  static const Key productTableKey = ValueKey('restaurant_product_table');
  static const Key serviceChargeKey = ValueKey('restaurant_service_charge');

  Widget _keyed(InvoiceSection s, Widget child) =>
      KeyedSubtree(key: UniversalInvoiceTemplate.sectionKey(s), child: child);

  double get _itemsSubtotal => items.fold(0.0, (sum, i) => sum + i.taxable);

  double get _serviceCharge => _itemsSubtotal * (serviceChargePercent / 100);

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
          const SizedBox(height: 8),
          if (tableNo != null && tableNo!.isNotEmpty)
            Text('Table: $tableNo', style: InvoiceSharedSections.bold(context)),
          const SizedBox(height: 12),
          _keyed(
            InvoiceSection.customerInfo,
            InvoiceSharedSections.customerInfo(context, data),
          ),
          const SizedBox(height: 12),

          // ── bespoke product table ──
          _productTable(context),
          const SizedBox(height: 8),

          if (serviceChargePercent > 0)
            Align(
              key: serviceChargeKey,
              alignment: Alignment.centerRight,
              child: Text(
                'Service Charge ($serviceChargePercent%): '
                '${InvoiceSharedSections.money(_serviceCharge)}',
              ),
            ),
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
        ],
      ),
    );
  }

  Widget _productTable(BuildContext c) {
    const headers = ['#', 'Item', 'Qty', 'Portion', 'Rate', 'Amount'];
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
              Expanded(child: Text('${items[i].quantity}')),
              Expanded(child: Text(items[i].portionLabel)),
              Expanded(
                child: Text(InvoiceSharedSections.money(items[i].price)),
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
