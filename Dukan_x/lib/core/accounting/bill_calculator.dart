import 'package:decimal/decimal.dart';
import '../../models/bill.dart';

/// 🧠 BillCalculator: Tally-Grade Arithmetic Engine
///
/// RESPONSIBILITIES:
/// 1. Enforce strict decimal precision (no floating point errors).
/// 2. Apply GST rounding rules per item and total.
/// 3. Provide Single Source of Trust for Bill Totals.
///
/// RULES:
/// - All internal math uses `Decimal`.
/// - Outputs are double (safe for storage/UI) but calculated carefully.
class BillCalculator {
  /// Recalculate a Bill ensuring all totals are mathematically consistent.
  ///
  /// This rebuilds totals from: Item Qty * Rate -> Discount -> Tax -> Total.
  /// It respects strict rounding and tax overrides.
  static Bill recalculate(Bill bill) {
    if (bill.items.isEmpty) return bill;

    final safeItems = bill.items.map((item) => calculateItem(item)).toList();

    // Sum totals from calculated items (Source of Truth)
    final totalTax = safeItems.fold(
      Decimal.zero,
      (sum, i) => sum + Decimal.parse(i.taxAmount.toString()),
    );
    final grandTotal = safeItems.fold(
      Decimal.zero,
      (sum, i) => sum + Decimal.parse(i.total.toString()),
    );

    // Apply Bill Level Discount
    final billDiscount = Decimal.parse(bill.discountApplied.toString());
    final finalGrandTotal = grandTotal - billDiscount;

    return bill
        .copyWith(
          items: safeItems,
          subtotal: (grandTotal - totalTax).toDouble(), // Derived Taxable
          totalTax: totalTax.toDouble(),
          grandTotal: finalGrandTotal.toDouble(),
        )
        .sanitized();
  }

  /// Calculate granular details for a single line item.
  ///
  /// Logic:
  /// 1. Base = Qty * Price
  /// 2. Taxable = Base - Discount
  /// 3. Tax = Taxable * GST%
  /// 4. Total = Taxable + Tax (Rounded to 2 decimals)
  static BillItem calculateItem(BillItem item) {
    final qty = Decimal.parse(item.qty.toString());
    final price = Decimal.parse(item.price.toString());
    final gstPercent = Decimal.parse(item.gstRate.toString());
    final discount = Decimal.parse(item.discount.toString());

    // 1. Base Amount
    final baseAmount = qty * price;

    // 2. Taxable Value
    final taxableValue = baseAmount - discount;
    final safeTaxable = taxableValue < Decimal.zero
        ? Decimal.zero
        : taxableValue;

    // 3. Tax Calculation
    final taxAmount = (safeTaxable * gstPercent / Decimal.fromInt(100))
        .toDecimal();

    // Round Tax Amount to 2 decimals for final addition
    final newTotalTax = _roundTo2(taxAmount);

    // 4. Total = Taxable + Tax
    final total = safeTaxable + newTotalTax;

    // Split Tax (IGST vs CGST+SGST)
    double newCgst = 0;
    double newSgst = 0;
    double newIgst = 0;

    if (item.isInterState || item.igst > 0) {
      newIgst = newTotalTax.toDouble();
    } else {
      // Split 50-50 for Intra-state
      final half = _roundTo2((newTotalTax / Decimal.fromInt(2)).toDecimal());
      newCgst = half.toDouble();
      newSgst = (newTotalTax - half).toDouble(); // Ensure sum matches total tax
    }

    return item.copyWith(
      total: _roundTo2(total).toDouble(),
      cgst: newCgst,
      sgst: newSgst,
      igst: newIgst,
    );
  }

  /// Round a Decimal to 2 decimal places using half-up rounding.
  /// Stays entirely within Decimal/BigInt arithmetic — no double escape.
  static Decimal _roundTo2(Decimal val) {
    // Shift left by 2 decimals, round via BigInt, shift back.
    final shifted = val * Decimal.fromInt(100);
    // Use BigInt truncation + manual half-up to avoid double.
    final bi = shifted.toBigInt();
    final remainder = shifted - Decimal.parse(bi.toString());
    final rounded = remainder >= Decimal.parse('0.5')
        ? bi + BigInt.one
        : (remainder <= Decimal.parse('-0.5') ? bi - BigInt.one : bi);
    return (Decimal.parse(rounded.toString()) / Decimal.fromInt(100))
        .toDecimal();
  }
}
