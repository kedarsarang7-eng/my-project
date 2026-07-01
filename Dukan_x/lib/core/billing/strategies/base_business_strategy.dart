import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'business_strategy.dart';

abstract class BaseBusinessStrategy implements BusinessStrategy {
  @override
  double calculateTax(BillItem item) => item.cgst + item.sgst + item.igst;

  /// Helper to build common quantity selector
  Widget buildQuantitySelector(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor, {
    int flex = 2,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleButton(
              Icons.remove,
              () {
                if (item.qty > 1) {
                  onUpdate(item.copyWith(qty: item.qty - 1));
                }
              },
              isDark,
              accentColor,
            ),
            Text(
              item.qty.toStringAsFixed(
                item.qty == item.qty.roundToDouble() ? 0 : 1,
              ),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            _circleButton(
              Icons.add,
              () {
                onUpdate(item.copyWith(qty: item.qty + 1));
              },
              isDark,
              accentColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to build common price field
  Widget buildPriceField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    String label, {
    int flex = 2,
  }) {
    return Expanded(
      flex: flex,
      child: compactTextField(
        label: label,
        value: item.price.toString(),
        prefix: sl<CurrencyService>().symbol,
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final price = double.tryParse(val) ?? 0;
          onUpdate(item.copyWith(price: price));
        },
        isDark: isDark,
      ),
    );
  }

  /// Helper to build common unit dropdown
  Widget buildUnitDropdown(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    List<UnitType> options, {
    int flex = 2,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: item.unit,
            isExpanded: true,
            isDense: true,
            items: options
                .map(
                  (u) => DropdownMenuItem(
                    value: u.label.toLowerCase(),
                    child: Text(
                      u.label,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                onUpdate(item.copyWith(unit: val));
              }
            },
          ),
        ),
      ),
    );
  }

  /// Helper for compact text fields
  Widget compactTextField({
    required String label,
    required String value,
    String? prefix,
    TextInputType? keyboardType,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.grey,
        ),
        prefixText: prefix,
        prefixStyle: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget buildBillHeaderFields(
    BuildContext context,
    Bill bill,
    Function(Bill updatedBill) onUpdate,
    bool isDark,
  ) {
    // Default implementation: No header fields
    return const SizedBox.shrink();
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark,
    Color accentColor,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: accentColor),
      ),
    );
  }
}
