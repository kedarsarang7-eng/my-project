import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/bill.dart';
import '../../../features/hardware/utils/hardware_business_rules.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

/// SharedPreferences key controlling whether the cut-to-size rounding
/// convention is enabled at the shop level.
///
/// When `true` (default), fractional units are rounded up and the
/// rounding disclosure note is shown on the invoice line item.
/// When `false`, no rounding is applied (exact measurement billing).
const String kCutToSizeRoundingEnabledKey = 'hardware_cutToSizeRoundingEnabled';

class HardwareStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.hardware;

  /// Whether the shop-level cut-to-size rounding setting is enabled.
  /// Defaults to `true` (rounding convention active).
  /// Loaded asynchronously; starts as `true` until prefs are read.
  static bool cutToSizeRoundingEnabled = true;

  /// Loads the cut-to-size rounding preference from SharedPreferences.
  /// Call this once at app startup or when the setting changes.
  static Future<void> loadCutToSizeRoundingSetting() async {
    final prefs = await SharedPreferences.getInstance();
    cutToSizeRoundingEnabled =
        prefs.getBool(kCutToSizeRoundingEnabledKey) ?? true;
  }

  /// Persists the cut-to-size rounding preference.
  static Future<void> setCutToSizeRoundingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kCutToSizeRoundingEnabledKey, value);
    cutToSizeRoundingEnabled = value;
  }

  @override
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    final config = BusinessTypeRegistry.getConfig(type);

    // Determine if this item's quantity was rounded up via cut-to-size
    // and build the rounding disclosure note if applicable.
    final bool wasRoundedUp =
        cutToSizeRoundingEnabled &&
        HardwareBusinessRules.cutToSizeWasRoundedUp(item.qty);
    final String? roundingNote = wasRoundedUp
        ? HardwareBusinessRules.cutToSizeRoundingNote(
            item.qty,
            unitLabel: item.unit,
          )
        : null;

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
        // Cut-to-size rounding disclosure — shown only when rounding occurs
        if (roundingNote != null) ...[
          const SizedBox(height: 8),
          _buildRoundingDisclosure(roundingNote, isDark),
        ],
      ],
    );
  }

  /// Renders the cut-to-size rounding disclosure note below the item fields.
  Widget _buildRoundingDisclosure(String note, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withOpacity(0.1) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.amber.withOpacity(0.3) : Colors.amber.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
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
