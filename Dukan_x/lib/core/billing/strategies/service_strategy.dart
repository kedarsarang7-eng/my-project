import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';
import 'base_business_strategy.dart';

class ServiceStrategy extends BaseBusinessStrategy {
  @override
  BusinessType get type => BusinessType.service;

  @override
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
    Color accentColor,
  ) {
    // Service strategy doesn't need Quantity/Unit the same way
    // So we override and don't reuse all base methods if they don't fit

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLaborField(item, onUpdate, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildPartsField(item, onUpdate, isDark)),
          ],
        ),
        const SizedBox(height: 8),
        _buildNotesField(item, onUpdate, isDark),
      ],
    );
  }

  Widget _buildLaborField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Labor Charge',
      value: (item.laborCharge ?? 0).toStringAsFixed(0),
      prefix: sl<CurrencyService>().symbol,
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final labor = double.tryParse(val) ?? 0;
        onUpdate(item.copyWith(laborCharge: labor));
      },
      isDark: isDark,
    );
  }

  Widget _buildPartsField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Parts Charge',
      value: (item.partsCharge ?? 0).toStringAsFixed(0),
      prefix: sl<CurrencyService>().symbol,
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final parts = double.tryParse(val) ?? 0;
        onUpdate(item.copyWith(partsCharge: parts));
      },
      isDark: isDark,
    );
  }

  Widget _buildNotesField(
    BillItem item,
    Function(BillItem) onUpdate,
    bool isDark,
  ) {
    return compactTextField(
      label: 'Notes',
      value: item.notes ?? '',
      onChanged: (val) {
        onUpdate(item.copyWith(notes: val.isEmpty ? null : val));
      },
      isDark: isDark,
    );
  }

  @override
  bool validateItem(BillItem item) {
    return item.itemName.isNotEmpty;
  }
}
