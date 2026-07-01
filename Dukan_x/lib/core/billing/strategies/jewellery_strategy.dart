import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import '../../../features/jewellery/utils/jewellery_business_rules.dart';
import 'base_business_strategy.dart';

class JewelleryStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.jewellery;

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
            Expanded(child: _buildPurityDropdown(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            Expanded(
              child: compactTextField(
                label: 'Metal Weight (gm)',
                value: item.metalWeight?.toString() ?? '',
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  onUpdate(item.copyWith(metalWeight: double.tryParse(val)));
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
                label: 'Making Charges',
                value: item.makingCharges?.toString() ?? '',
                prefix: sl<CurrencyService>().symbol,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  onUpdate(item.copyWith(makingCharges: double.tryParse(val)));
                },
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: compactTextField(
                label: 'Hallmark No',
                value: item.hallmark ?? '',
                onChanged: (val) {
                  onUpdate(item.copyWith(hallmark: val));
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
    // Jewellery billing path: purity must be a valid GoldPurity value if set
    // (Requirement 15.6). Allow null (not yet selected), but reject invalid
    // free-text values that don't map to a known GoldPurity.
    if (item.purity != null && !GoldPurity.isValid(item.purity)) {
      return false;
    }
    return item.itemName.isNotEmpty && item.price >= 0;
  }

  /// Builds a purity dropdown constrained to [GoldPurity] enum values.
  ///
  /// Requirement 15.6: replaces the free-text purity String with Purity_Enum
  /// end-to-end on the jewellery billing path. The stored BillItem.purity
  /// remains a String (shared model), but is constrained to valid GoldPurity
  /// display labels ('24K', '22K', '18K', '14K').
  Widget _buildPurityDropdown(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    final currentPurity = GoldPurity.tryFromString(item.purity);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Purity',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GoldPurity>(
          value: currentPurity,
          isDense: true,
          isExpanded: true,
          hint: Text(
            'Select',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          items: GoldPurity.values
              .map(
                (p) => DropdownMenuItem<GoldPurity>(
                  value: p,
                  child: Text(p.displayLabel),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              onUpdate(item.copyWith(purity: val.displayLabel));
            }
          },
        ),
      ),
    );
  }
}
