import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class ElectronicsStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.electronics;

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
            buildPriceField(item, onUpdate, isDark, config.priceLabel, flex: 4),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSerialField(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildWarrantyField(item, onUpdate, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildSerialField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'IMEI/Serial',
      value: item.serialNo ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(serialNo: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  Widget _buildWarrantyField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Warranty (Months)',
      value: item.warrantyMonths?.toString() ?? '',
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final months = int.tryParse(val);
        onUpdate(item.copyWith(warrantyMonths: months));
      },
      isDark: isDark,
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0;
  }
}
