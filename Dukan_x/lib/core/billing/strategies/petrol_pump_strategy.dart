import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class PetrolPumpStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.petrolPump;

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
        // Quantity (Litres or Kg)
        buildQuantitySelector(item, onUpdate, isDark, accentColor, flex: 3),
        const SizedBox(width: 8),

        // Unit (Ltr by default)
        buildUnitDropdown(item, onUpdate, isDark, config.unitOptions, flex: 2),
        const SizedBox(width: 8),

        // Rate field
        buildPriceField(item, onUpdate, isDark, config.priceLabel, flex: 3),
      ],
    );
  }

  @override
  bool validateItem(BillItem item) {
    // Petrol pump items must have quantity (litres) and price
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }
}
