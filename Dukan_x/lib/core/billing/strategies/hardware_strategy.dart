import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class HardwareStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.hardware;

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
      children: [
        Row(
          children: [
            buildQuantitySelector(item, onUpdate, isDark, accentColor),
            const SizedBox(width: 8),
            buildUnitDropdown(item, onUpdate, isDark, config.unitOptions),
            const SizedBox(width: 8),
            buildPriceField(item, onUpdate, isDark, config.priceLabel),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildWeightField(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildHsnField(item, onUpdate, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Weight',
      value: item.weight ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(weight: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  Widget _buildHsnField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'HSN Code',
      value: item.hsn,
      onChanged: (val) {
        onUpdate(item.copyWith(hsn: val));
      },
      isDark: isDark,
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0;
  }
}
