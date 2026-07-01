import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class RestaurantStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.restaurant;

  @override
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final config = BusinessTypeRegistry.getConfig(type);
    final showHalf = config.optionalFields.contains(ItemField.isHalf);
    final showParcel = config.optionalFields.contains(ItemField.isParcel);

    return Column(
      children: [
        Row(
          children: [
            buildQuantitySelector(item, onUpdate, isDark, accentColor),
            if (showHalf) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildHalfFullToggle(
                  item,
                  onUpdate,
                  isDark,
                  accentColor,
                ),
              ),
            ],
            const SizedBox(width: 8),
            buildPriceField(item, onUpdate, isDark, config.priceLabel),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTableNoField(item, onUpdate, isDark)),
            if (showParcel) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildParcelToggle(item, onUpdate, isDark, accentColor),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHalfFullToggle(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final isHalf = item.isHalf ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggleChip(
          '½ Half',
          isHalf,
          () {
            if (!isHalf) {
              // Switching to half: halve the price
              onUpdate(item.copyWith(isHalf: true, price: item.price / 2.0));
            }
          },
          isDark,
          accentColor,
        ),
        const SizedBox(width: 4),
        _toggleChip(
          'Full',
          !isHalf,
          () {
            if (isHalf) {
              // Switching to full: restore (double) the price
              onUpdate(item.copyWith(isHalf: false, price: item.price * 2.0));
            }
          },
          isDark,
          accentColor,
        ),
      ],
    );
  }

  Widget _buildParcelToggle(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final isParcel = item.isParcel ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggleChip(
          'Dine-In',
          !isParcel,
          () {
            onUpdate(item.copyWith(isParcel: false));
          },
          isDark,
          accentColor,
        ),
        const SizedBox(width: 4),
        _toggleChip(
          'Parcel',
          isParcel,
          () {
            onUpdate(item.copyWith(isParcel: true));
          },
          isDark,
          accentColor,
        ),
      ],
    );
  }

  Widget _buildTableNoField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Table',
      value: item.tableNo ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(tableNo: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  Widget _toggleChip(
    String label,
    bool selected,
    VoidCallback onTap,
    bool isDark,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accentColor
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildBillHeaderFields(
    BuildContext context,
    Bill bill,
    Function(Bill updatedBill) onUpdate,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: compactTextField(
              label: 'Table No',
              value: bill.tableNumber ?? '',
              prefix: 'T-',
              keyboardType: TextInputType.text,
              onChanged: (val) {
                onUpdate(
                  bill.copyWith(tableNumber: val.trim().isEmpty ? null : val),
                );
              },
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: compactTextField(
              label: 'Waiter Name / ID',
              value: bill.waiterId ?? '',
              keyboardType: TextInputType.text,
              onChanged: (val) {
                onUpdate(
                  bill.copyWith(waiterId: val.trim().isEmpty ? null : val),
                );
              },
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0;
  }
}
