import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class GeneralStoreStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.grocery;

  @override
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final config = BusinessTypeRegistry.getConfig(type);

    return Row(
      children: [
        buildQuantitySelector(item, onUpdate, isDark, accentColor),
        const SizedBox(width: 8),
        buildUnitDropdown(item, onUpdate, isDark, config.unitOptions),
        const SizedBox(width: 8),
        buildPriceField(item, onUpdate, isDark, config.priceLabel),
      ],
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }
}
