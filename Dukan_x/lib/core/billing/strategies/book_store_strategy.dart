import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

/// Billing strategy for Book Store business type.
///
/// Builds ISBN, Author, Publisher fields in the bill item row.
/// Validates that book title (item name) is set and qty > 0.
///
/// GST policy (confirmed):
///   • Printed books (HSN 4901): 0% GST (exempt).
///   • Notebooks / exercise books (HSN 4820): 5% GST (CGST 2.5% + SGST 2.5%).
///   • Other stationery: 5%–18% by HSN code.
///
/// The per-item GST rate is resolved from the product's HSN code (or stored
/// taxRate) via [BookGstResolver]. The `defaultGstRate` in
/// `business_type_config.dart` is set to 0.0 (the most common item — printed
/// books — is exempt) and serves only as a fallback when no HSN/tax-class is
/// set on a product. `gstEditable` remains true so operators can override per
/// item.
class BookStoreStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.bookStore;

  @override
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final config = BusinessTypeRegistry.getConfig(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Qty + Unit + Price (MRP)
        Row(
          children: [
            buildQuantitySelector(item, onUpdate, isDark, accentColor),
            const SizedBox(width: 8),
            buildUnitDropdown(item, onUpdate, isDark, config.unitOptions),
            const SizedBox(width: 8),
            buildPriceField(item, onUpdate, isDark, config.priceLabel),
          ],
        ),
      ],
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }

  @override
  Widget buildBillHeaderFields(
    BuildContext context,
    Bill bill,
    Function(Bill updatedBill) onUpdate,
    bool isDark,
  ) {
    // Book stores don't need special bill header fields
    // (no table number, vehicle number, doctor name, etc.)
    return const SizedBox.shrink();
  }
}
