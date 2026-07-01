import 'package:flutter/material.dart';
import '../../../models/bill.dart';
import '../../billing/business_type_config.dart';

/// Strategy interface for handling business-specific item logic
abstract class BusinessStrategy {
  BusinessType get type;

  /// Builds the content fields for the Adaptive Item Card
  Widget buildItemFields(
    BuildContext context,
    BillItem item,
    Function(BillItem updatedItem) onUpdate,
    bool isDark,
    Color accentColor,
  );

  /// Validates if the item has all required fields for this business type
  bool validateItem(BillItem item);

  /// Calculates custom tax logic if any (mostly handled by Bill logic, but here for extensibility)
  double calculateTax(BillItem item) => item.cgst + item.sgst + item.igst;

  /// Builds the header fields for the Bill (e.g. Table Number, Doctor Name, Vehicle Number)
  /// Returns a Widget to be inserted below Customer Search.
  /// Return SizedBox.shrink() if not needed.
  Widget buildBillHeaderFields(
    BuildContext context,
    Bill bill,
    Function(Bill updatedBill) onUpdate,
    bool isDark,
  );
}
