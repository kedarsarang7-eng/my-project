import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class ClothingStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.clothing;

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
            Expanded(
              flex: 2,
              child: _buildSizeSelector(item, onUpdate, isDark),
            ),
            const SizedBox(width: 8),
            buildPriceField(item, onUpdate, isDark, config.priceLabel),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildColorField(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            _buildDiscountField(item, onUpdate, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildSizeSelector(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    final sizes = ['S', 'M', 'L', 'XL', 'XXL'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: item.size ?? 'M',
          isExpanded: true,
          isDense: true,
          items: sizes
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (val) {
            onUpdate(item.copyWith(size: val));
          },
        ),
      ),
    );
  }

  Widget _buildColorField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Color',
      value: item.color ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(color: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  Widget _buildDiscountField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return Expanded(
      child: compactTextField(
        label: 'Discount',
        value: item.discount.toStringAsFixed(0),
        prefix: sl<CurrencyService>().symbol,
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final disc = double.tryParse(val) ?? 0;
          onUpdate(item.copyWith(discount: disc));
        },
        isDark: isDark,
      ),
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }
}
