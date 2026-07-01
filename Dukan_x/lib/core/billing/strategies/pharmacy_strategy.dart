import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class PharmacyStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.pharmacy;

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
            Expanded(child: _buildBatchField(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildExpiryField(context, item, onUpdate, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Batch',
      value: item.batchNo ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(batchNo: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  Widget _buildExpiryField(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    final expiry = item.expiryDate;
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: expiry ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (date != null) {
          onUpdate(item.copyWith(expiryDate: date));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              expiry != null ? DateFormat('MMM yy').format(expiry) : 'Expiry',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: expiry != null
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty && item.qty > 0 && item.price >= 0;
  }
}
