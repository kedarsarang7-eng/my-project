import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class AutoPartsStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.autoParts;

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
            Expanded(
              child: compactTextField(
                label: 'Vehicle Model',
                value: item.vehicleModel ?? '',
                onChanged: (val) {
                  onUpdate(item.copyWith(vehicleModel: val));
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: compactTextField(
                label: 'Brand',
                value: item.brand ?? '',
                onChanged: (val) {
                  onUpdate(item.copyWith(brand: val));
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: compactTextField(
                label: 'Labor Charge',
                value: item.laborCharge?.toString() ?? '',
                prefix: sl<CurrencyService>().symbol,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  onUpdate(item.copyWith(laborCharge: double.tryParse(val)));
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: compactTextField(
                label: 'Parts Cost',
                value: item.partsCharge?.toString() ?? '',
                prefix: sl<CurrencyService>().symbol,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  onUpdate(item.copyWith(partsCharge: double.tryParse(val)));
                },
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }
}
