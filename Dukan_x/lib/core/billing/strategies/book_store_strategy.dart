import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

/// Billing strategy for Book Store business type.
///
/// Builds ISBN, Author, Publisher fields in the bill item row.
/// Validates that book title (item name) is set and qty > 0.
/// Books are GST-exempt in India (0% by default).
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
